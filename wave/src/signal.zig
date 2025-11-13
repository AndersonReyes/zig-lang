const std = @import("std");

/// represents a generic signal
pub const Signal = struct {
    /// frequency of signal
    frequency: f64,
    /// amplitude of signal
    amplitude: f64,
    /// phase of signal in radians
    phase: f64,

    pub fn init(
        frequency: f64,
        amplitude: f64,
        phase: f64,
    ) Signal {
        return .{ .frequency = frequency, .amplitude = amplitude, .phase = phase };
    }
};

/// evaluating function of singal that takes a timestamp and returnas a value.
/// Uses cosine as the base function for now.
pub const Sinusoid = struct {
    signals: std.ArrayList(Signal),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, signals: []const Signal) !Sinusoid {
        var sigs = try std.ArrayList(Signal).initCapacity(allocator, signals.len);

        try sigs.appendSlice(allocator, signals);

        return .{ .signals = sigs, .allocator = allocator };
    }

    pub fn deinit(self: *Sinusoid) void {
        self.signals.deinit(self.allocator);
    }

    fn evaluate_one(signal: Signal, n: comptime_int, time: [n]f64) [n]f64 {
        var out: [n]f64 = .{0.0} ** n;

        for (0..n) |k| {
            const r: f64 = signal.phase + (signal.frequency * std.math.pi * 2.0 * time[k]);
            out[k] = std.math.cos(r) * signal.amplitude;
        }
        return out;
    }

    /// evaluate signal at vector of timestamps. Uses the vector operations to evaluate multiple timestamps at once.
    pub fn evaluate(self: Sinusoid, n: comptime_int, time: [n]f64) [n]f64 {
        var sum: [n]f64 = .{0.0} ** n;

        for (self.signals.items) |s| {
            const ys = evaluate_one(s, n, time);
            for (0..n) |i| {
                sum[i] += ys[i];
            }
        }

        return sum;
    }
};

test "evaluate works with one signal" {
    var signal = try Sinusoid.init(std.testing.allocator, &[1]Signal{Signal.init(1.0, 1.0, 0.0)});
    defer signal.deinit();

    const actual: @Vector(1, f64) = signal.evaluate(1, @Vector(1, f64){0.0});
    const expected: @Vector(1, f64) = @Vector(1, f64){std.math.pi * 2.0};

    try std.testing.expectApproxEqAbs(expected[0], actual[0], 1e-7);
}

test "sum signals" {
    const a = Signal.init(1.0, 1.0, 0);
    const b = Signal.init(1.0, 1.0, 0);

    var mix = try Sinusoid.init(std.testing.allocator, &[2]Signal{ a, b });
    defer mix.deinit();

    const actual: @Vector(1, f64) = mix.evaluate(1, @Vector(1, f64){0.0});
    const expected: @Vector(1, f64) = @Vector(1, f64){std.math.pi * 4.0};

    try std.testing.expectApproxEqAbs(expected[0], actual[0], 1e-7);
}
