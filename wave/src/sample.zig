const std = @import("std");

// Improve all these multiple looping over data. Maybe abstract out

pub fn normalize(comptime T: type, data: *[]T, bound: f64) void {
    var max: T = undefined;
    var min: T = undefined;

    for (0..data.len) |i| {
        max = @max(max, data.*[i]);
        min = @min(min, data.*[i]);
    }

    const v: T = @intCast(@max(@abs(max), @abs(min)));

    for (0..data.len) |i| {
        data.*[i] *= @divFloor(bound, v);
    }
}

pub fn quantize(comptime T: type, source: []const f64, dest: *[]T, bound: f64) !void {
    try std.testing.expectEqual(dest.len, source.len);

    // for (source, 0..) |s, i| {
    //     dest.*[i] = @intFromFloat(s);
    // }

    // normalize(T, dest, bound);

    for (0..dest.len) |i| {
        dest.*[i] = @intFromFloat(source[i] * bound);
        // std.debug.print("dest[{}] = source( {} ) * bound ( {} ) = {}\n", .{ i, source[i], bound, dest.*[i] });
    }
}
