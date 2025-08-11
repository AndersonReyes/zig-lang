//! https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html#_Toc442180832
//!

const std = @import("std");

pub const ProtocolError = error{InvalidControlPacket};

/// 2.2.1 MQTT Control Packet type
pub const ControlPacketType = enum(u4) {
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

pub const ControlPacket = struct { packet_type: ControlPacketType };
pub const FixedHeader = struct {};

fn parse_control_packet_type(byte: u8) !ControlPacketType {
    const type_bits: u8 = byte >> 4;

    switch (type_bits) {
        1...14 => return @enumFromInt(type_bits),
        else => {
            std.log.err("invalid mqtt control type {b} in {b}\n", .{ type_bits, byte });
            return ProtocolError.InvalidControlPacket;
        },
    }
}

fn parse_control_packet(byte: u8) !ControlPacket {
    const packet_type = try parse_control_packet_type(byte);

    return ControlPacket{ .packet_type = packet_type };
}

test "parse_control_packet(): control type from 4 msb bits" {
    // const bits = 0x30;
    // const packet = try parse_control_packet(bits);
    // try std.testing.expectEqual(packet.packet_type, ControlPacketType.PUBLISH);

    for (1..15) |n| {
        const byte: u8 = @intCast(n);
        // shift left because control bits are the second octet (high 4 msb)
        const packet = try parse_control_packet(byte << 4);
        const expected: ControlPacketType = @enumFromInt(n);
        try std.testing.expectEqual(packet.packet_type, expected);
    }
}
