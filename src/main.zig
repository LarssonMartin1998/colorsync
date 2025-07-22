const std = @import("std");
const config = @import("config.zig");
const utils = @import("utils.zig");
const cli = @import("cli.zig");

pub fn main() !void {
    var buf: [512]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fixed.allocator();

    try cli.run(allocator);
}
