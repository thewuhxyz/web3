const std = @import("std");
const trace = @import("root.zig");

const Level = trace.level.Level;
const ScopedLogger = trace.log.ScopedLogger;
const AtomicBool = std.atomic.Value(bool);

pub fn NewEntry(comptime scope: ?[]const u8) type {
    return Entry(struct {}, scope);
}

pub fn Entry(comptime Fields: type, comptime scope: ?[]const u8) type {
    return struct {
        logger: ScopedLogger(scope),
        level: Level,
        fields: Fields,

        const Self = @This();

        /// Add a field to the log message.
        pub fn field(
            self: Self,
            comptime name: [:0]const u8,
            value: anytype,
        ) Entry(FieldsPlus(name, @TypeOf(value)), scope) {
            if (self.logger == .noop) return .{
                .logger = .noop,
                .level = undefined,
                .fields = undefined,
            };
            var new_fields: FieldsPlus(name, @TypeOf(value)) = undefined;
            inline for (@typeInfo(Fields).Struct.fields) |existing_field| {
                @field(new_fields, existing_field.name) = @field(self.fields, existing_field.name);
            }
            @field(new_fields, name) = value;
            return .{
                .logger = self.logger,
                .level = self.level,
                .fields = new_fields,
            };
        }

        /// Log the message using the logger, including all fields that are saved in the entry.
        pub fn log(self: Self, comptime message: []const u8) void {
            self.logger.private_log(self.level, self.fields, message, .{});
        }

        /// Log the message using the logger, including all fields that are saved in the entry.
        pub fn logf(self: Self, comptime fmt: []const u8, args: anytype) void {
            self.logger.private_log(self.level, self.fields, fmt, args);
        }

        /// Returns a new struct type based on Fields, just with one more field added.
        fn FieldsPlus(comptime field_name: [:0]const u8, comptime FieldType: type) type {
            const info = @typeInfo(Fields);
            const ActualFieldType = switch (@typeInfo(FieldType)) {
                .ComptimeFloat => f64,
                .ComptimeInt => u64,
                else => FieldType,
            };
            const new_fields = info.Struct.fields ++ &[_]std.builtin.Type.StructField{.{
                .name = field_name,
                .type = ActualFieldType,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(FieldType),
            }};
            const new_struct = std.builtin.Type.Struct{
                .layout = .auto,
                .backing_integer = null,
                .fields = new_fields,
                .decls = &.{},
                .is_tuple = false,
            };
            return @Type(.{ .Struct = new_struct });
        }
    };
}
