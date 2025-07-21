const std = @import("std");
const config = @import("config.zig");
const utils = @import("utils.zig");
const cli = @import("cli.zig");

fn getConfigPath() ![]const u8 {
    const home_path = try utils.getEnv("HOME");

    var buf: [64]u8 = undefined;
    return try std.fmt.bufPrint(&buf, "{s}/.config/colorsync/colorsyncrc", .{home_path});
}

pub fn main() !void {
    var buf: [512]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fixed.allocator();

    try cli.run(allocator);
}
