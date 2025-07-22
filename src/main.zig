const std = @import("std");
const config = @import("config.zig");
const utils = @import("utils.zig");
const cli = @import("cli.zig");

pub fn main() !void {
    var buf: [2048]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fixed.allocator();

    const configContext = config.Context{
        .readAlloc = config.readAlloc,
        .setCurrent = config.setCurrent,
        .getCurrent = config.getCurrent,
        .validate = config.validate,
    };

    try cli.run(allocator, &configContext);
}
