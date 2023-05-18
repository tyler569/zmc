const std = @import("std");

fn mixin(comptime Self: type) type {
    return struct {
        fn fields() []const std.builtin.Type.StructField {
            return @typeInfo(Self).Struct.fields;
        }

        fn fieldWise1(comptime f: fn (f32) f32) fn (Self) Self {
            return struct {
                fn op(self: Self) Self {
                    var result: Self = undefined;

                    inline for (fields()) |field| {
                        @field(result, field.name) = f(@field(self, field.name));
                    }

                    return result;
                }
            }.op;
        }

        fn fieldWise2(comptime f: fn (f32, f32) f32) fn (Self, Self) Self {
            return struct {
                fn op(self: Self, rhs: Self) Self {
                    var result: Self = undefined;

                    inline for (fields()) |field| {
                        @field(result, field.name) = f(@field(self, field.name), @field(rhs, field.name));
                    }

                    return result;
                }
            }.op;
        }

        fn _invert(s: f32) f32 {
            return -s;
        }

        pub const invert = fieldWise1(_invert);

        fn _add(s: f32, t: f32) f32 {
            return s + t;
        }

        fn _sub(s: f32, t: f32) f32 {
            return s - t;
        }

        fn _mul(s: f32, t: f32) f32 {
            return s * t;
        }

        pub const add = fieldWise2(_add);
        pub const sub = fieldWise2(_sub);

        pub fn dot(self: Self, rhs: Self) f32 {
            var result = @as(f32, 0);

            inline for (@typeInfo(Self).Struct.fields) |field| {
                result += @field(self, field.name) * @field(rhs, field.name);
            }

            return result;
        }

        pub fn length(self: Self) f32 {
            var result = @as(f32, 0);

            inline for (fields()) |field| {
                result += @field(self, field.name) * @field(self, field.name);
            }

            return @sqrt(result);
        }
    };
}

pub const Vec2 = struct {
    x: f32,
    y: f32,

    const Self = @This();
    pub usingnamespace mixin(Self);
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    const Self = @This();
    pub usingnamespace mixin(Self);
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    const Self = @This();
    pub usingnamespace mixin(Self);
};

test "vector4 lengths" {
    const a = Vec4{ .x = 1, .y = 0, .z = 0, .w = 0 };
    try std.testing.expectEqual(@as(0, f32), a.length());
}
