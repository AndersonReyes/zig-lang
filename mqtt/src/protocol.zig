//! https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html#_Toc442180832
//!

const std = @import("std");

pub const ProtocolError = error{ InvalidFixedheader, MalformedRemainingLength };

/// 2.2.1 MQTT Control Packet type
pub const FixedheaderType = enum(u4) {
    // reserved value 0, forbidden
    // RESERVED_0,
    /// client to server: request connection to server
    CONNECT = 1,
    /// server to client: conenction acknowlegement
    CONNACK = 2,
    /// client to server: publish message
    PUBLISH = 3,
    /// publish messagea acknowlegement
    PUBACK = 4,
    /// publish received, assured delivery part 1
    PUBREC = 5,
    /// publish release, assured delivery part 2
    PUBREL = 6,
    /// publish complete, assured delivery part 3
    PUBCOMP = 7,
    /// client to server: client subscribe to topic request
    SUBSCRIBE = 8,
    /// server to client: subscribe ack
    SUBACK = 9,
    /// client to sever: unsubscribe message
    UNSUBSCRIBE = 10,
    /// server to client: unsubscribe ack
    UNSUBACK = 11,
    /// ping request to detect node health
    PINGREQ = 12,
    /// ping response
    PINGRESP = 13,
    /// client to server: disconnect the client
    DISCONNECT = 14,
    // reserved value 15, forbidden
    // RESERVED_15 = 15,

};

/// delivery gurantees
pub const QoS = enum(u2) {
    AT_MOST_ONCE = 0,
    AT_LEAST_ONCE = 1,
    EXACTLY_ONCE = 2,
};

pub const ControlFlags = struct {
    /// delivery of message
    duplicate_delivery: bool,
    /// assurance of delivery
    quality_of_service: QoS,
    /// store the message for delivery on subscribe, else delete the message if there are no subscribers
    retain: bool,
};

pub const Fixedheader = struct { packet_type: FixedheaderType, flags: ControlFlags, remaining_length: usize };

const max_remining_length_multiplier: u32 = 128 * 128 * 128;

/// 2.2.3 Remaining Length
fn parse_remaining_length_field(bytes: *const [4]u8) !usize {
    var multiplier: u32 = 1;
    var curr_byte_idx: u3 = 0;
    var value: usize = 0;

    while (curr_byte_idx < 4) : ({
        multiplier *= 128;
        curr_byte_idx += 1;
    }) {
        const next_byte = bytes[curr_byte_idx];
        value += (next_byte & 127) * multiplier;

        if (multiplier > max_remining_length_multiplier) {
            std.log.err("malforemed remaining length: {any}", .{bytes});
            return ProtocolError.MalformedRemainingLength;
        }

        // no continuation bit, stop loop
        if (next_byte & 128 == 0) {
            break;
        }
    }

    return value;
}

pub const VariableHeader = struct { packet_identifier: u16 };

/// 2.3.1 parse variable header . Packet identifiers, 2 bytes
fn parse_variable_header(bytes: *const [2]u8) VariableHeader {
    // first byte is MSB bits and second byte is LSB bits
    var id: u16 = bytes[0];
    id <<= 8;
    id |= bytes[1];
    return .{ .packet_identifier = id };
}

/// fixed header contains at most 5 bytes.1 for the control packet and 4 for remaining length field.
fn parse_fixed_header(bytes: *const [5]u8) !Fixedheader {
    const first_byte = bytes[0];
    const type_bits: u8 = first_byte >> 4;

    // type is the 4 MSB bits.
    const packet_type: FixedheaderType = switch (type_bits) {
        1...14 => @enumFromInt(type_bits),
        else => {
            std.log.err("invalid mqtt control type {b} in {b}\n", .{ type_bits, first_byte });
            return ProtocolError.InvalidFixedheader;
        },
    };

    // QOS is the second and third byte in the 4 LSB.
    const qos: QoS = switch ((first_byte & 0b0110) >> 1) {
        0...2 => |v| @enumFromInt(v),
        else => |invalid| {
            std.log.err("invalid mqtt quality of service {b} in {b}\n", .{ invalid, first_byte });
            return ProtocolError.InvalidFixedheader;
        },
    };

    // bit 3
    const dup_delivery: bool = (first_byte & 0b1000) != 0;
    // bit 0
    const retain: bool = (first_byte & 0b0001) != 0;
    // next 4 bytes
    const remaining_length = try parse_remaining_length_field(bytes[1..5]);

    const flags = ControlFlags{
        .duplicate_delivery = dup_delivery,
        .quality_of_service = qos,
        .retain = retain,
    };

    return .{ .packet_type = packet_type, .flags = flags, .remaining_length = remaining_length };
}

test "parse_control_packet(): control type from 4 msb bits" {
    for (1..15) |n| {
        // shift left because control bits are the second octet (high 4 msb)
        const byte: u8 = @intCast(n);
        const packet = try parse_fixed_header(&[5]u8{ byte << 4, 0, 0, 0, 0 });
        const expected: FixedheaderType = @enumFromInt(n);
        try std.testing.expectEqual(expected, packet.packet_type);
    }
}

test "parse_control_packet(): can parse control duplicate_delivery and retain flags" {

    // retain true
    {
        const packet = try parse_fixed_header(&[5]u8{ 0b10000001, 0, 0, 0, 0 });
        try std.testing.expectEqual(true, packet.flags.retain);
    }

    // retain false
    {
        const packet = try parse_fixed_header(&[5]u8{ 0b10000000, 0, 0, 0, 0 });
        try std.testing.expectEqual(false, packet.flags.retain);
    }

    // duplicate_delivery true
    {
        const packet = try parse_fixed_header(&[5]u8{ 0b10001000, 0, 0, 0, 0 });
        try std.testing.expectEqual(true, packet.flags.duplicate_delivery);
    }

    // duplicate_delivery false
    {
        const packet = try parse_fixed_header(&[5]u8{ 0b10000000, 0, 0, 0, 0 });
        try std.testing.expectEqual(false, packet.flags.duplicate_delivery);
    }
}

test "parse_control_packet(): can parse control qos flags" {

    // AT_MOST_ONCE
    {
        const packet = try parse_fixed_header(&[5]u8{ 0b10000000, 0, 0, 0, 0 });
        try std.testing.expectEqual(QoS.AT_MOST_ONCE, packet.flags.quality_of_service);
    }

    // AT_LEAST_ONCE
    {
        const packet = try parse_fixed_header(&[5]u8{ 0b10000010, 0, 0, 0, 0 });
        try std.testing.expectEqual(QoS.AT_LEAST_ONCE, packet.flags.quality_of_service);
    }

    // EXACTLY_ONCE
    {
        const packet = try parse_fixed_header(&[5]u8{ 0b10000100, 0, 0, 0, 0 });
        try std.testing.expectEqual(QoS.EXACTLY_ONCE, packet.flags.quality_of_service);
    }
}

test "parse_remaining_length_field one byte" {
    for (0..128) |n| {
        const byte: u8 = @intCast(n);
        const actual: usize = try parse_remaining_length_field(&[4]u8{ byte, 0, 0, 0 });
        try std.testing.expectEqual(byte, actual);
    }
}

test "parse_remaining_length_field multiple bytes" {
    // this example comes from 2.2.3 Remaining Length. 65 | 128 sets the continuation bit
    // (8th bit) to 1.
    const actual: usize = try parse_remaining_length_field(&[4]u8{ 65 | 128, 2, 0, 0 });
    try std.testing.expectEqual(321, actual);
}

test "can parse variable header" {
    const actual = parse_variable_header(&[2]u8{ 0x12, 0x34 });
    try std.testing.expectEqual(0x1234, actual.packet_identifier);
}
