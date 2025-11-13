const std = @import("std");
const signal = @import("signal.zig");
const wave = @import("wave.zig");
const sample = @import("sample.zig");

// Size of RIFF header (12) + (8) fmt id/size + (16) fmt chunk + data id/size.
const HEADER_SIZE: u32 = 12 + 8 + 16 + 8;

pub const Wav = struct {
    audio_format: u16,
    channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bit_depth: u16,

    pub fn init(
        audio_format: u16,
        channels: u16,
        sample_rate: u32,
        byte_rate: u32,
        block_align: u16,
        bit_depth: u16,
    ) Wav {
        return .{
            .audio_format = audio_format,
            .channels = channels,
            .sample_rate = sample_rate,
            .byte_rate = byte_rate,
            .block_align = block_align,
            .bit_depth = bit_depth,
        };
    }

    pub fn write(self: Wav, comptime T: type, path: []const u8, data: []const T) !void {
        var file = try std.fs.createFileAbsolute(path, .{ .truncate = true });
        defer file.close();

        const buf: []u8 = undefined;
        var writer = file.writer(buf);

        // total data written, len * 4 bytes per sample (we will write f32 instead of f64)
        const data_bytes_written: u32 = @intCast(data.len * @bitSizeOf(T) / 8);
        const bytes_written: u32 = HEADER_SIZE + data_bytes_written - 8;

        try writer.interface.writeAll("RIFF");

        try writer.interface.writeInt(u32, bytes_written, std.builtin.Endian.little);

        try writer.interface.writeAll("WAVE");
        try writer.interface.writeAll("fmt ");

        // fmt size
        try writer.interface.writeInt(u32, 16, std.builtin.Endian.little);

        // chunk
        try writer.interface.writeInt(u16, self.audio_format, std.builtin.Endian.little);
        try writer.interface.writeInt(u16, self.channels, std.builtin.Endian.little);
        try writer.interface.writeInt(u32, self.sample_rate, std.builtin.Endian.little);
        try writer.interface.writeInt(u32, self.byte_rate, std.builtin.Endian.little);
        try writer.interface.writeInt(u16, self.block_align, std.builtin.Endian.little);
        try writer.interface.writeInt(u16, self.bit_depth, std.builtin.Endian.little);

        // data size is 8 * len because each value is an f64 which is 8 bytes
        try writer.interface.writeAll("data");

        try writer.interface.writeInt(u32, data_bytes_written, std.builtin.Endian.little);

        for (data) |b| {
            try writer.interface.writeAll(std.mem.asBytes(&b));
        }
    }
};

test "write" {
    var s = try signal.Sinusoid.init(std.testing.allocator, &[1]signal.Signal{signal.Signal.init(1.0, 1.0, 0.0)});
    defer s.deinit();

    var sinwave = try wave.Wave.initFromSinusoid(std.testing.allocator, s, 0.5, 0.0, 1);
    defer sinwave.deinit();

    const channels = 1;
    const bits_per_sample = 16;
    const byterate = sinwave.framerate * channels * bits_per_sample / 8;
    const block_align = channels * bits_per_sample / 8;

    var wav_file = Wav.init(1, channels, sinwave.framerate, byterate, block_align, bits_per_sample);
    try wav_file.write("/tmp/sample.wav", sinwave.values.items);
}
