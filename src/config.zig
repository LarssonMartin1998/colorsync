const std = @import("std");
const utils = @import("utils.zig");

const File = std.fs.File;

const stderr = std.io.getStdErr().writer();

pub const Context = struct {
    readAlloc: fn (allocator: std.mem.Allocator, configDir: []const u8) anyerror!std.ArrayList([]const u8),
    setCurrent: fn (newCurrent: []const u8) anyerror!void,
    getCurrent: fn () anyerror![]u8,
    validate: fn (writer: anytype, entries: *const std.ArrayList([]const u8), only_output_on_err: bool) anyerror!void,
};

pub fn readAlloc(allocator: std.mem.Allocator, configDir: []const u8) !std.ArrayList([]const u8) {
    const configFile = try std.fs.openFileAbsolute(configDir, .{
        .mode = File.OpenMode.read_only,
    });
    defer configFile.close();

    var entries = std.ArrayList([]const u8).init(allocator);
    try entries.ensureTotalCapacity(10);

    var reader = configFile.reader();
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 32)) |line| {
        try entries.append(line);
    }

    return entries;
}

pub fn setCurrent(newCurrent: []const u8) !void {
    if (!utils.isAlphanumericAscii(newCurrent)) {
        return error.NonAlphanumericArg;
    }

    const home_path = try utils.getEnv("HOME");

    const state_dir_from_home = "/.local/state/colorsync";

    var buf: [96]u8 = undefined;
    const state_dir_path = try std.fmt.bufPrint(&buf, "{s}" ++ state_dir_from_home, .{home_path});

    std.fs.makeDirAbsolute(state_dir_path) catch |err| switch (err) {
        std.posix.MakeDirError.PathAlreadyExists => {},
        else => return err,
    };

    const state_file_path = try std.fmt.bufPrint(&buf, "{s}" ++ state_dir_from_home ++ "/current", .{home_path});

    var state_file = try std.fs.createFileAbsolute(state_file_path, .{});
    defer state_file.close();

    const writer = state_file.writer();
    try writer.print("{s}", .{newCurrent});
}

pub fn getCurrent() ![]u8 {
    const home_path = try utils.getEnv("HOME");
    var buf: [96]u8 = undefined;
    const state_file_path = try std.fmt.bufPrint(&buf, "{s}" ++ "/.local/state/colorsync/current", .{home_path});

    const file = try std.fs.openFileAbsolute(state_file_path, .{ .mode = File.OpenMode.read_only });
    defer file.close();

    var reader = file.reader();
    if (try reader.readUntilDelimiterOrEof(&buf, '\n')) |value| {
        return value;
    }

    return error.CurrentNotFound;
}

pub fn validate(writer: anytype, entries: *const std.ArrayList([]const u8), only_output_on_err: bool) !void {
    var buf: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    var set = std.HashMap([]const u8, void, std.hash_map.StringContext, 30).init(allocator);
    defer set.deinit();

    try set.ensureTotalCapacity(10);

    var errcount: u16 = 0;
    for (entries.items) |entry| {
        const result_ptr = try set.getOrPut(entry);
        if (result_ptr.found_existing) {
            errcount += 1;
            try writer.print("Error: Found duplicate entry in config \"{s}\"!\n", .{entry});
        } else {
            result_ptr.value_ptr.* = void{};
        }

        if (!utils.isAlphanumericAscii(entry)) {
            errcount += 1;
            try writer.print("Error: Found character not matching the supported format [a-z], [A-Z], [0-9] in \"{s}\"!\n", .{entry});
        }
    }

    if (errcount == 0 and !only_output_on_err) {
        try writer.print("Your config looks good, no errors found.\n", .{});
    }

    if (errcount > 0) {
        return error.ValidationFoundErrors;
    }
}

test "Read Config" {
    const cwd = std.fs.cwd();
    cwd.makeDir("test") catch |err| switch (err) {
        std.fs.Dir.MakeError.PathAlreadyExists => {},
        else => return err,
    };

    const test_dir = try cwd.openDir("test", .{});
    var test_config = test_dir.createFile("current", .{}) catch |err| switch (err) {
        File.OpenError.PathAlreadyExists => try test_dir.openFile("current", .{}),
        else => return err,
    };
    defer test_config.close();

    const writer = test_config.writer();
    var bw = std.io.bufferedWriter(writer);

    const data = [_][]const u8{
        "row1",
        "row2",
        "row3",
    };

    var buf: [16 * data.len]u8 = undefined;
    for (0..data.len) |i| {
        const start = i * 16;
        const end = start + 16;
        _ = try bw.write(try std.fmt.bufPrint(buf[start..end], "{s}" ++ "\n", .{data[i]}));
    }

    try bw.flush();

    defer cwd.deleteDir("test") catch {};

    const allocator = std.testing.allocator;
    const test_conf_filepath_abs = try test_dir.realpathAlloc(allocator, "current");
    defer allocator.free(test_conf_filepath_abs);

    const entries = (try readAlloc(allocator, test_conf_filepath_abs));
    defer {
        for (entries.items) |entry| {
            allocator.free(entry);
        }
        entries.deinit();
    }

    for (0..entries.items.len) |i| {
        try std.testing.expectEqualStrings(data[i], entries.items[i]);
    }
}

test "Validate config" {
    const allocator = std.testing.allocator;
    var entries = std.ArrayList([]const u8).init(allocator);
    defer entries.deinit();

    try entries.ensureTotalCapacity(10);
    try entries.append("row1");
    try entries.append("row2");
    try entries.append("row3");

    try validate(std.io.null_writer, &entries, true);

    var entries_with_duplicates = std.ArrayList([]const u8).init(allocator);
    defer entries_with_duplicates.deinit();

    try entries_with_duplicates.ensureTotalCapacity(10);
    for (0..2) |_| {
        for (entries.items) |entry| {
            try entries_with_duplicates.append(entry);
        }
    }

    const duplicate_result = validate(std.io.null_writer, &entries_with_duplicates, true);
    try std.testing.expectEqual(duplicate_result, error.ValidationFoundErrors);

    var entries_invalid_names = std.ArrayList([]const u8).init(allocator);
    defer entries_invalid_names.deinit();

    try entries_invalid_names.ensureTotalCapacity(10);
    try entries_invalid_names.append("1234!@#$");
    try entries_invalid_names.append("ASlkjDF,.|");
    try entries_invalid_names.append("<>,.");
    try entries_invalid_names.append("äöå");

    const name_result = validate(std.io.null_writer, &entries_invalid_names, true);
    try std.testing.expectEqual(name_result, error.ValidationFoundErrors);
}
