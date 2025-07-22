const std = @import("std");

const clap = @import("clap");

const utils = @import("utils.zig");
const ConfigContext = @import("config.zig").Context;

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

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
        try stdout.print("colorsync 0.1.0\n", .{});
        return;
    }

    const command = res.positionals[0] orelse {
        try help("colorsync ", &main_params);
        return;
    };

    (switch (command) {
        .set => setCmd(allocator, context, &iter),
        .get => getCmd(context, res),
        .show => showCmd(allocator, context),
        .validate => validateCmd(allocator, context),
    }) catch |err| switch (err) {
        error.MissingArgument => try stderr.print("Missing <string> argument for <command> set\n", .{}),
        error.SuppliedArgNotInConfig => try stderr.print("Supplied <string> argument for <command> set doesn't exist in config.\n", .{}),
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

fn setCmd(allocator: std.mem.Allocator, context: *const ConfigContext, iter: *std.process.ArgIterator) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help Display this help and exit.
        \\<string> Existing theme to set as active theme in "~/.local/state/colorsync/current".
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, clap.parsers.default, iter, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.report(stderr, err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try help("colorsync set ", &params);
        return;
    }

    const entries = try getConfigEntriesAlloc(allocator, context);
    const arg = res.positionals[0] orelse return error.MissingArgument;

    for (entries.items) |entry| {
        if (std.mem.eql(u8, arg, entry)) {
            try context.setCurrent(arg);
            return;
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

fn showCmd(allocator: std.mem.Allocator, context: *const ConfigContext) !void {
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

fn validateCmd(allocator: std.mem.Allocator, context: *const ConfigContext) !void {
    var config_path_buf: [64]u8 = undefined;
    const config_path = try utils.getConfigPath(&config_path_buf);

    const entries = try context.readAlloc(allocator, config_path);
    context.validate(&entries) catch |err| switch (err) {
        error.ValidationFoundErrors => {},
        else => return err,
    };
}
