const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
});

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

pub fn getEnv(env: [*c]const u8) std.process.GetEnvVarOwnedError![]u8 {
    const result_ptr = c.getenv(env);
    if (result_ptr == null) {
        return std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound;
    }

    return std.mem.span(result_ptr);
}

pub fn getConfigPath(buf: []u8) ![]const u8 {
    const home_path = try getEnv("HOME");
    return try std.fmt.bufPrint(buf, "{s}/.config/colorsync/colorsyncrc", .{home_path});
}

test "Heapless environment variable" {
    const allocator = std.testing.allocator;
    const heap_home_path = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(heap_home_path);

    const stack_home_path = try getEnv("HOME");

    try std.testing.expectEqualStrings(heap_home_path, stack_home_path);
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
