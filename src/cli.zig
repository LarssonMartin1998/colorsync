const std = @import("std");

const clap = @import("clap");

const utils = @import("utils.zig");
const ConfigContext = @import("config.zig").Context;

const SubCommands = enum {
    set,
    get,
    show,
    validate,
};

const main_parsers = .{
    .subcommand = clap.parsers.enumeration(SubCommands),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help             Display this help and exit.
    \\
    \\<subcommand>              Subcommand to run. One of:
    \\
    \\    set       Set a new active theme
    \\
    \\    get       Get the active theme
    \\
    \\    show      Show the config
    \\
    \\    validate  Validate the config
    \\
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
        const stderr = std.io.getStdErr().writer();
        var bw = std.io.bufferedWriter(stderr);
        const writer = bw.writer();
        diag.report(&writer, err) catch {};
        try bw.flush();
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try helpCmd();
        return;
    }

    const command = res.positionals[0] orelse {
        try helpCmd();
        return;
    };
    try switch (command) {
        .set => setCmd(context),
        .get => getCmd(context),
        .show => showCmd(allocator, context),
        .validate => validateCmd(allocator, context),
    };
}

fn helpCmd() !void {
    const stderr = std.io.getStdErr().writer();
    try clap.help(stderr, clap.Help, &main_params, .{
        .markdown_lite = false,
    });
}

fn setCmd(_: *const ConfigContext) !void {
    std.debug.print("set\n", .{});
}
fn getCmd(_: *const ConfigContext) !void {
    std.debug.print("get\n", .{});
}

fn showCmd(allocator: std.mem.Allocator, context: *const ConfigContext) !void {
    var config_path_buf: [64]u8 = undefined;
    const config_path = try utils.getConfigPath(&config_path_buf);
    const entries = try context.readAlloc(allocator, config_path);

    const stdout = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout);
    const writer = bw.writer();

    try writer.print("{s}:\n", .{config_path});
    try writer.print("----------\n", .{});
    for (entries.items) |entry| {
        try writer.print("{s}\n", .{entry});
    }
    try writer.print("----------\n\n", .{});

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
