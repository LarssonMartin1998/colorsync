const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
});

pub fn getEnv(env: [*c]const u8) std.process.GetEnvVarOwnedError![]u8 {
    const result_ptr = c.getenv(env);
    if (result_ptr == null) {
        return std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound;
    }

    return std.mem.span(result_ptr);
}

test "Heapless environment variable" {
    const allocator = std.testing.allocator;
    const heap_home_path = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(heap_home_path);

    const stack_home_path = try getEnv("HOME");

    try std.testing.expectEqualStrings(heap_home_path, stack_home_path);
}
