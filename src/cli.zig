const std = @import("std");

const clap = @import("clap");

const utils = @import("utils.zig");
const ConfigContext = @import("config.zig").Context;

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const read_budget = 4096;

const Commands = enum {
    set,
    get,
    show,
    validate,
};

const main_parsers = .{
    .command = clap.parsers.enumeration(Commands),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help             Display this help and exit.
    \\
    \\-v, --version             Output the version of this tool.
    \\
    \\<command> [<args>]              Command to run. One of:
    \\
    \\    set <string>  -    Set new active theme in "~/.local/state/colorsync/current".
    \\    get   -    Get the active theme specified in "~/.local/state/colorsync/current".
    \\    show  -    Show the config at "~/.config/colorsync/colorsyncrc".
    \\    validate   -   Validate the config. at "~/.config/colorsync/colorsyncrc".
);

const MainArgs = clap.ResultEx(clap.Help, &main_params, main_parsers);

pub fn run(allocator: std.mem.Allocator, context: *const ConfigContext) !void {
    var iter = std.process.ArgIterator.init();

    // skip exe
    _ = iter.next();

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &main_params, main_parsers, &iter, .{
        .allocator = allocator,
        .diagnostic = &diag,
        .terminating_positional = 0,
    }) catch |err| {
        var bw = std.io.bufferedWriter(stderr);
        const writer = bw.writer();
        diag.report(&writer, err) catch {};
        try bw.flush();
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try help("colorsync ", &main_params);
        return;
    }

    if (res.args.version != 0) {
        try stdout.print("colorsync 1.0.1\n", .{});
        return;
    }

    const command = res.positionals[0] orelse {
        try help("colorsync ", &main_params);
        return;
    };

    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();
    _ = try writer.write("Warning: Your config has the following issues:");

    const validation_result = validateConfig(writer, context);
    validation_result catch |err| switch (err) {
        error.ValidationFoundErrors => {
            _ = try writer.write("\n\n");
            try bw.flush();
        },
        else => return err,
    };

    (switch (command) {
        .set => setCmd(allocator, context, &iter),
        .get => getCmd(context, res),
        .show => showCmd(context),
        .validate => {
            if (validation_result != error.ValidationFoundErrors) {
                try validateCmd(context);
            }
        },
    }) catch |err| switch (err) {
        error.MissingArgument => try stderr.print("Missing <string> argument for <command> set\n", .{}),
        error.SuppliedArgNotInConfig => try stderr.print("Supplied <string> argument for <command> set doesn't exist in config.\n", .{}),
        error.NonAlphanumericArg => try stderr.print("Invalid input, only text with [A-Z], [a-z], [0-9] is supported.\n", .{}),
        else => return err,
    };
}

fn help(tool_cmd: []const u8, params: []const clap.Param(clap.Help)) !void {
    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();

    _ = try writer.write(tool_cmd);
    try clap.usage(writer, clap.Help, params);
    _ = try writer.write("\n\n");
    try clap.help(writer, clap.Help, params, .{
        .markdown_lite = false,
    });
    _ = try writer.write("\n");

    try bw.flush();
}

fn getConfigEntriesAlloc(allocator: std.mem.Allocator, context: *const ConfigContext) !std.ArrayList([]const u8) {
    var buf: [64]u8 = undefined;
    const path = try utils.getConfigPath(&buf);
    return try context.readAlloc(allocator, path);
}

fn validateConfig(writer: anytype, context: *const ConfigContext) !void {
    var entriesBuf: [read_budget]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&entriesBuf);
    const allocator = fba.allocator();

    const entries = try getConfigEntriesAlloc(allocator, context);
    return context.validate(writer, &entries, false);
}

fn setCmd(main_allocator: std.mem.Allocator, context: *const ConfigContext, iter: *std.process.ArgIterator) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help Display this help and exit.
        \\<string> Existing theme to set as active theme in "~/.local/state/colorsync/current".
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, clap.parsers.default, iter, .{
        .diagnostic = &diag,
        .allocator = main_allocator,
    }) catch |err| {
        try diag.report(stderr, err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try help("colorsync set ", &params);
        return;
    }

    var entriesBuf: [read_budget]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&entriesBuf);
    const entries_allocator = fba.allocator();

    const entries = try getConfigEntriesAlloc(entries_allocator, context);
    const arg = res.positionals[0] orelse return error.MissingArgument;

    for (entries.items) |entry| {
        if (std.mem.eql(u8, arg, entry)) {
            return context.setCurrent(arg);
        }
    }

    return error.SuppliedArgNotInConfig;
}

fn getCmd(context: *const ConfigContext, _: MainArgs) !void {
    const curr = context.getCurrent() catch |err| {
        return err;
    };

    try stdout.print("{s}\n", .{curr});
}

fn showCmd(context: *const ConfigContext) !void {
    var buf: [read_budget]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    const entries = try getConfigEntriesAlloc(allocator, context);

    var bw = std.io.bufferedWriter(stdout);
    const writer = bw.writer();

    _ = try writer.write("----------\n");
    for (entries.items) |entry| {
        try writer.print("{s}\n", .{entry});
    }
    _ = try writer.write("----------\n\n");

    try bw.flush();
}

fn validateCmd(context: *const ConfigContext) !void {
    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();

    validateConfig(writer, context) catch |err| switch (err) {
        error.ValidationFoundErrors => {},
        else => return err,
    };

    try bw.flush();
}
