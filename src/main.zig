const std = @import("std");
const config = @import("config.zig");
const utils = @import("utils.zig");

fn getConfigPath() ![]const u8 {
    const home_path = try utils.getEnv("HOME");

    var buf: [64]u8 = undefined;
    return try std.fmt.bufPrint(&buf, "{s}/.config/colorsync/colorsyncrc", .{home_path});
}

pub fn main() !void {
    var buf: [512]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fixed.allocator();

    const stdout = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout);
    const writer = bw.writer();

    const entries = try config.readAlloc(allocator, try getConfigPath());
    for (entries.items) |entry| {
        try writer.print("{s}\n", .{entry});
    }

    try config.setCurrent("test value");

    const curr = try config.getCurrent();
    try writer.print("{s}\n", .{curr});

    try bw.flush();
}
