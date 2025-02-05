const std = @import("std");
const crypto = @import("crypto/root.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;
const Allocator = std.mem.Allocator;

pub const Hash = extern struct {
    data: [size]u8,

    pub const size = 32;

    pub const ZEROES: Hash = .{ .data = .{0} ** size };

    const base58 = crypto.base58.Base58Sized(size);

    pub fn fromSizedSlice(data: *const [size]u8) Hash {
        var hash: Hash = undefined;
        @memcpy(&hash.data, data);
        return hash;
    }

    pub fn generateSha256Hash(bytes: []const u8) Hash {
        var data: [size]u8 = undefined;
        Sha256.hash(bytes, &data, .{});
        return .{ .data = data };
    }

    pub fn extendAndHash(id: Hash, val: []const u8) Hash {
        var hasher = Sha256.init(.{});
        hasher.update(&id.data);
        hasher.update(val);
        return .{ .data = hasher.finalResult() };
    }

    pub fn eql(self: Hash, other: Hash) bool {
        const xx: @Vector(size, u8) = self.data;
        const yy: @Vector(size, u8) = other.data;
        return @reduce(.And, xx == yy);
    }

    pub fn order(a: *const Hash, b: *const Hash) std.math.Order {
        for (a.data, b.data) |a_byte, b_byte| {
            if (a_byte > b_byte) return .gt;
            if (a_byte < b_byte) return .lt;
        }
        return .eq;
    }

    pub fn parseBase58String(str: []const u8) error{InvalidHash}!Hash {
        return .{ .data = base58.decode(str) catch return error.InvalidHash };
    }

    pub const base58_max_encoded_size = base58.max_encoded_size;
    pub const Base58String = std.BoundedArray(u8, base58_max_encoded_size);
    pub fn base58String(self: Hash) Base58String {
        return base58.encode(self.data);
    }

    pub fn format(
        self: Hash,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        return base58.format(self.data, writer);
    }

    pub fn base58EncodeAlloc(self: Hash, allocator: Allocator) Allocator.Error![]const u8 {
        return base58.encodeAlloc(self.data, allocator);
    }

    /// Intended to be used in tests.
    pub fn initRandom(random: std.Random) Hash {
        var data: [size]u8 = undefined;
        random.bytes(&data);
        return .{ .data = data };
    }
};
