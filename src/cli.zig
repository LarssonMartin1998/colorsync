const std = @import("std");
const clap = @import("clap");

const SubCommands = enum {
    set,
    get,
    show,
    validate,
};

const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommands),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help             Display this help and exit.
    \\<command>
    \\
);

const MainArgs = clap.ResultEx(clap.Help, &main_params, main_parsers);

pub fn run(allocator: std.mem.Allocator) !void {
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
        std.debug.print("help\n", .{});
        return;
    }

    const command = res.positionals[0] orelse {
        std.debug.print("help\n", .{});
        return;
    };
    try switch (command) {
        .set => setCmd(),
        .get => getCmd(),
        .show => showCmd(),
        .validate => validateCmd(),
    };
}

fn setCmd() !void {
    std.debug.print("set\n", .{});
}
fn getCmd() !void {
    std.debug.print("get\n", .{});
}
fn showCmd() !void {
    std.debug.print("show\n", .{});
}
fn validateCmd() !void {
    std.debug.print("validate\n", .{});
}
