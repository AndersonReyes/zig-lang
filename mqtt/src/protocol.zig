//! https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html#_Toc442180832
//!

const std = @import("std");

pub const ProtocolError = error{InvalidFixedheader};

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

pub const Fixedheader = struct { packet_type: FixedheaderType, flags: ControlFlags };

fn parse_fixed_header(byte: u8) !Fixedheader {
    const type_bits: u8 = byte >> 4;

    const packet_type: FixedheaderType = switch (type_bits) {
        1...14 => @enumFromInt(type_bits),
        else => {
            std.log.err("invalid mqtt control type {b} in {b}\n", .{ type_bits, byte });
            return ProtocolError.InvalidFixedheader;
        },
    };

    const qos: QoS = switch ((byte & 0b0110) >> 1) {
        0...2 => |v| @enumFromInt(v),
        else => |invalid| {
            std.log.err("invalid mqtt quality of service {b} in {b}\n", .{ invalid, byte });
            return ProtocolError.InvalidFixedheader;
        },
    };

    const dup_delivery: bool = (byte & 0b1000) != 0;
    const retain: bool = (byte & 0b0001) != 0;

    const flags = ControlFlags{
        .duplicate_delivery = dup_delivery,
        .quality_of_service = qos,
        .retain = retain,
    };

    return Fixedheader{ .packet_type = packet_type, .flags = flags };
}

test "parse_control_packet(): control type from 4 msb bits" {
    for (1..15) |n| {
        // shift left because control bits are the second octet (high 4 msb)
        const byte: u8 = @intCast(n);
        const packet = try parse_fixed_header(byte << 4);
        const expected: FixedheaderType = @enumFromInt(n);
        try std.testing.expectEqual(expected, packet.packet_type);
    }
}

test "parse_control_packet(): can parse control duplicate_delivery and retain flags" {

    // retain true
    {
        const packet = try parse_fixed_header(0b10000001);
        try std.testing.expectEqual(true, packet.flags.retain);
    }

    // retain false
    {
        const packet = try parse_fixed_header(0b10000000);
        try std.testing.expectEqual(false, packet.flags.retain);
    }

    // duplicate_delivery true
    {
        const packet = try parse_fixed_header(0b10001000);
        try std.testing.expectEqual(true, packet.flags.duplicate_delivery);
    }

    // duplicate_delivery false
    {
        const packet = try parse_fixed_header(0b10000000);
        try std.testing.expectEqual(false, packet.flags.duplicate_delivery);
    }
}

test "parse_control_packet(): can parse control qos flags" {

    // AT_MOST_ONCE
    {
        const packet = try parse_fixed_header(0b10000000);
        try std.testing.expectEqual(QoS.AT_MOST_ONCE, packet.flags.quality_of_service);
    }

    // AT_LEAST_ONCE
    {
        const packet = try parse_fixed_header(0b10000010);
        try std.testing.expectEqual(QoS.AT_LEAST_ONCE, packet.flags.quality_of_service);
    }

    // EXACTLY_ONCE
    {
        const packet = try parse_fixed_header(0b10000100);
        try std.testing.expectEqual(QoS.EXACTLY_ONCE, packet.flags.quality_of_service);
    }
}
