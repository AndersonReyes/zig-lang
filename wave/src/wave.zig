const std = @import("std");
const signal = @import("signal.zig");
///
pub const DEFAULT_FRAMERATE: u32 = 11025;

/// evaluated singal at many timestamps.
pub const Wave = struct {
    allocator: std.mem.Allocator,
    timestamps: std.ArrayList(f64),
    framerate: u32,
    values: std.ArrayList(f64),

    /// creates new Wave. The slice values are copied into the struct.
    pub fn init(
        allocator: std.mem.Allocator,
        timestamps: []const f64,
        framerate: u32,
        values: []const f64,
    ) !Wave {
        var t = try std.ArrayList(f64).initCapacity(allocator, timestamps.len);
        var v = try std.ArrayList(f64).initCapacity(allocator, values.len);

        try t.appendSlice(allocator, timestamps);
        try v.appendSlice(allocator, values);

        return .{ .allocator = allocator, .timestamps = t, .framerate = framerate, .values = v };
    }

    pub fn deinit(self: *Wave) void {
        self.timestamps.deinit(self.allocator);
        self.values.deinit(self.allocator);
    }

    pub fn initFromSignals(allocator: std.mem.Allocator, signals: []const signal.Signal, duration: comptime_float, start: comptime_int, framerate: comptime_int) !Wave {
        const n: comptime_int = @round(duration * @as(comptime_float, framerate));
        var time: [n]f64 = .{0.0} ** n;

        const framerate_f = @as(f64, framerate);
        const start_f = @as(f64, start);
        for (1..n) |i| {
            const f: f64 = @floatFromInt(i);
            time[i] = (f / framerate_f) + start_f;
        }

        const values = signal.Signal.evaluateMany(signals, n, time);

        return try init(allocator, &time, framerate, &values);
    }
};

test "init" {
    const s = try signal.Signal.initCos(1.0, 1.0, 0.0);

    var wave = try Wave.initFromSignals(std.testing.allocator, .{s}, 1.0, 0.0, 2);
    defer wave.deinit();

    try std.testing.expectEqual(2, wave.framerate);
    try std.testing.expectEqual(2, wave.timestamps.items.len);

    try std.testing.expectApproxEqAbs(0.0, wave.timestamps.items[0], 1e-7);
    try std.testing.expectApproxEqAbs(0.5, wave.timestamps.items[1], 1e-7);
}
