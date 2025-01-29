const std = @import("std");
const trace = @import("root.zig");

const logfmt = trace.logfmt;

const Allocator = std.mem.Allocator;
const AtomicBool = std.atomic.Value(bool);

const Level = trace.level.Level;
const NewEntry = trace.entry.NewEntry;

pub const Config = struct {
    max_level: Level = Level.debug,
    allocator: std.mem.Allocator,
    /// Maximum memory that logger can use.
    max_buffer: ?u64 = null,
};

pub fn ScopedLogger(comptime scope: ?[]const u8) type {
    return union(enum) {
        // channel_print: *ChannelPrintLogger,
        direct_print: DirectPrintLogger,
        noop: void,

        const Self = @This();

        /// Can be used in tests to minimize the amount of logging during tests.
        pub const TEST_DEFAULT_LEVEL: Level = .warn;

        pub fn unscoped(self: Self) Logger {
            return switch (self) {
                .channel_print => |logger| .{ .channel_print = logger },
                .direct_print => |logger| .{ .direct_print = logger },
                .noop => .noop,
            };
        }

        pub fn withScope(self: Self, comptime new_scope: []const u8) ScopedLogger(new_scope) {
            return switch (self) {
                // .channel_print => |logger| .{ .channel_print = logger },
                .direct_print => |logger| .{ .direct_print = logger },
                .noop => .noop,
            };
        }

        pub fn deinit(self: *const Self) void {
            switch (self.*) {
                .channel_print => |logger| logger.deinit(),
                .direct_print, .noop => {},
            }
        }

        pub fn err(self: Self) NewEntry(scope) {
            return self.entry(.err);
        }

        pub fn warn(self: Self) NewEntry(scope) {
            return self.entry(.warn);
        }

        pub fn info(self: Self) NewEntry(scope) {
            return self.entry(.info);
        }

        pub fn debug(self: Self) NewEntry(scope) {
            return self.entry(.debug);
        }

        pub fn trace(self: Self) NewEntry(scope) {
            return self.entry(.trace);
        }

        fn entry(self: Self, level: Level) NewEntry(scope) {
            const logger = switch (self) {
                .noop => .noop,
                inline else => |impl| if (@intFromEnum(impl.max_level) >= @intFromEnum(level))
                    self
                else
                    .noop,
            };
            return .{ .logger = logger, .level = level, .fields = .{} };
        }

        pub fn log(self: Self, level: Level, comptime message: []const u8) void {
            self.private_log(level, .{}, message, .{});
        }

        pub fn logf(self: Self, level: Level, comptime fmt: []const u8, args: anytype) void {
            self.private_log(level, .{}, fmt, args);
        }

        /// Only intended for use within trace module.
        ///
        /// Passthrough to the logger implementation
        pub fn private_log(
            self: Self,
            level: Level,
            fields: anytype,
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            switch (self) {
                .noop => {},
                inline else => |impl| impl.log(scope, level, fields, fmt, args),
            }
        }
    };
}

pub const Logger = ScopedLogger(null);

/// Directly prints instead of running in a separate thread. This handles issues during tests
/// where some log messages never get logged because the logger is deinitialized before the
/// logging thread picks up the log message.
pub const DirectPrintLogger = struct {
    max_level: Level,

    const Self = @This();

    pub fn init(_: std.mem.Allocator, max_level: Level) Self {
        return .{ .max_level = max_level };
    }

    pub fn logger(self: Self) Logger {
        return .{ .direct_print = self };
    }

    pub fn scopedLogger(self: Self, comptime new_scope: anytype) ScopedLogger(new_scope) {
        return .{ .direct_print = self };
    }

    pub fn log(
        self: Self,
        comptime scope: ?[]const u8,
        level: Level,
        fields: anytype,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        if (@intFromEnum(self.max_level) < @intFromEnum(level)) return;
        const writer = std.io.getStdErr().writer();
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        logfmt.writeLog(writer, scope, level, fields, fmt, args) catch {};
    }
};

/// change this locally for temporary visibility into tests.
/// normally this should be err since we don't want any output from well-behaved passing tests.
const test_level = Level.err;

