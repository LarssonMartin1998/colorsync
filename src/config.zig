const std = @import("std");
const utils = @import("utils.zig");

const File = std.fs.File;

const GetCurrentError = error{
    Error,
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
    // TODO: Verify input, don't accept any delimiters etc
    //
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

    // TODO: Improve error handling
    return GetCurrentError.Error;
}

pub fn validate() !void {
    // Errors:
    // multiple entries
    // too long
    // too big
}
