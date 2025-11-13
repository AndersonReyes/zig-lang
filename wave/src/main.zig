const std = @import("std");
const wave = @import("wave.zig");
const wav = @import("wav.zig");
const signal = @import("signal.zig");
const sample = @import("sample.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        _ = gpa.deinit();
    }

    const allocator = gpa.allocator();

    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);

    var s = try signal.Sinusoid.init(allocator, &[1]signal.Signal{signal.Signal.init(440, 1.0, 0.0)});
    defer s.deinit();

    var sinwave = try wave.Wave.initFromSinusoid(allocator, s, 0.5, 0.0, 1000);
    defer sinwave.deinit();

    const channels = 1;
    const bits_per_sample = 16;
    const byterate = sinwave.framerate * channels * bits_per_sample / 8;
    const block_align = channels * bits_per_sample / 8;

    const p = try std.fs.path.join(allocator, &[_][]const u8{ cwd, "main.wav" });
    defer allocator.free(p);

    var data = try std.ArrayList(i16).initCapacity(allocator, sinwave.values.items.len);
    defer data.deinit(allocator);

    try data.appendNTimes(allocator, 0, sinwave.values.items.len);

    try sample.quantize(allocator, i16, 1.0, sinwave.values.items, &data.items, std.math.maxInt(i16));

    var wav_file = wav.Wav.init(1, channels, sinwave.framerate, byterate, block_align, bits_per_sample);
    try wav_file.write(i16, p, data.items);
}
