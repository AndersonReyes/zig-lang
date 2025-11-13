const std = @import("std");

// Improve all these multiple looping over data. Maybe abstract out

pub fn normalize(comptime T: type, amplitude: T, data: *[]T) void {
    var max: T = undefined;
    var min: T = undefined;

    for (0..data.len) |i| {
        max = @max(max, data.*[i]);
        min = @min(min, data.*[i]);
    }

    const v: T = @as(T, @max(@abs(max), @abs(min)));

    for (0..data.len) |i| {
        data.*[i] *= amplitude / v;
    }
}

pub fn quantize(allocator: std.mem.Allocator, comptime T: type, amplitude: f64, source: []const f64, dest: *[]T, bound: T) !void {
    try std.testing.expectEqual(dest.len, source.len);

    var temp = try std.ArrayList(f64).initCapacity(allocator, dest.len);
    defer temp.deinit(allocator);
    try temp.appendSlice(allocator, source);

    const bound_f: f64 = @floatFromInt(bound);
    normalize(f64, amplitude, &temp.items);

    for (0..dest.len) |i| {
        // std.debug.print("line 33: {} * {}\n", .{ temp.items[i], bound_f });
        dest.*[i] = @intFromFloat(temp.items[i] * bound_f);
    }
}
