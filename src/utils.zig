const std = @import("std");

pub fn isAlphanumericAscii(str: []const u8) bool {
    for (str) |char| {
        if (!(('a' <= char and char <= 'z') or
            ('A' <= char and char <= 'Z') or
            ('0' <= char and char <= '9')))
        {
            return false;
        }
    }

    return str.len > 0;
}

pub fn getConfigPath(buf: []u8) ![]const u8 {
    var env_buf: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&env_buf);

    const allocator = fba.allocator();
    const home_path = try std.process.getEnvVarOwned(allocator, "HOME");

    return try std.fmt.bufPrint(buf, "{s}/.config/colorsync/colorsyncrc", .{home_path});
}

test "isAlphanumericAscii" {
    for ([_][]const u8{
        "lpq9oPwerASf",
        "ASDASDQWEQWECNML",
        "QWEUONNNAASD9321",
        "WEhfsdDpCNDawe321",
        "d",
        "P",
        "1",
    }) |str| {
        try std.testing.expect(isAlphanumericAscii(str));
    }

    for ([_][]const u8{
        "",
        ";.,",
        "<>",
        "!@#",
        "%&*",
        "tjenare!",
        "åöä",
    }) |str| {
        try std.testing.expect(!isAlphanumericAscii(str));
    }
}
