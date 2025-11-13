const std = @import("std");
const Wave = @import("wave.zig").Wave;
const DEFAULT_FRAMERATE = @import("wave.zig").DEFAULT_FRAMERATE;
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

    const sin = signal.Signal.initCos(440, 1.0, 0.0);
    const cos = signal.Signal.initSin(880, 0.5, 0.0);

    var wave = try Wave.initFromSignals(allocator, &[_]signal.Signal{ sin, cos }, 0.5, 0.0, 1000);
    defer wave.deinit();

    const ttype = i16;
    const channels = 1;
    const bits_per_sample = @bitSizeOf(ttype);
    const byterate = wave.framerate * channels * bits_per_sample / 8;
    const block_align = channels * bits_per_sample / 8;

    const p = try std.fs.path.join(allocator, &[_][]const u8{ cwd, "main.wav" });
    defer allocator.free(p);

    // TODO: clean up this data copy of the wave values; Should be moved into the writer instead of here.
    //  we only need quantized values for writing.
    var data = try std.ArrayList(ttype).initCapacity(allocator, wave.values.items.len);
    defer data.deinit(allocator);

    try data.appendNTimes(allocator, 0, wave.values.items.len);

    try sample.quantize(allocator, ttype, 1.0, wave.values.items, &data.items, std.math.maxInt(i16));

    var wav_file = wav.Wav.init(1, channels, wave.framerate, byterate, block_align, bits_per_sample);
    try wav_file.write(ttype, p, data.items);
}
