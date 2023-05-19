const std = @import("std");

fn vectorMixin(comptime Self: type) type {
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
    pub usingnamespace vectorMixin(Self);
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    const Self = @This();
    pub usingnamespace vectorMixin(Self);
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    const Self = @This();
    pub usingnamespace vectorMixin(Self);

    pub fn get(self: Self, row: usize, col: usize) f32 {
        if (col != 0) unreachable;

        switch (row) {
            0 => return self.x,
            1 => return self.y,
            2 => return self.z,
            3 => return self.w,
            else => unreachable,
        }
    }

    pub fn ptr(self: *Self, row: usize, col: usize) *f32 {
        if (col != 0) unreachable;

        switch (row) {
            0 => return &self.x,
            1 => return &self.y,
            2 => return &self.z,
            3 => return &self.w,
            else => unreachable,
        }
    }

    pub fn matMul(self: Self, rhs: Mat4) Self {
        var result: Self = undefined;

        for (0..4) |r| {
            var product: f32 = 0;
            for (0..4) |dp|
                product += rhs.get(r, dp) * self.get(dp, 0);
            result.ptr(r, 0).* = product;
        }

        return result;
    }

    pub fn format(
        self: Vec4,
        comptime fmt: []const u8,
        x: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = fmt;
        _ = x;
        _ = try writer.print(
            "<{d} {d} {d} {d}>",
            .{ self.x, self.y, self.z, self.w },
        );
    }
};

test "vector4 lengths" {
    const a = Vec4{ .x = 1, .y = 0, .z = 0, .w = 0 };
    std.testing.expectEqual(@as(0, f32), a.length());
}

pub const Mat4 = extern struct {
    // _m1: [4]f32,
    // _m2: [4]f32,
    // _m3: [4]f32,
    // _m4: [4]f32,
    m: [16]f32 = [_]f32{0} ** 16,

    pub inline fn get(self: Mat4, row: usize, col: usize) f32 {
        return self.m[col * 4 + row];
    }

    pub inline fn ptr(self: *Mat4, row: usize, col: usize) *f32 {
        return &self.m[col * 4 + row];
    }

    // pub fn mul(self: Mat4, rhs: Mat4) Mat4 {
    //     var result = Mat4{};

    //     for (0..16) |i| {
    //         const c = i & 3;
    //         const r = i >> 2;

    //         const x = self.get(c, c) * rhs.get(c, r) + self.get(c, r) * rhs.get(r, r);
    //         result.m[i] = x;
    //     }

    //     return result;
    // }

    pub fn mul(self: Mat4, rhs: Mat4) Mat4 {
        var result = Mat4{};

        for (0..4) |c| {
            for (0..4) |r| {
                var product: f32 = 0;
                for (0..4) |dp| {
                    product += self.get(r, dp) * rhs.get(dp, c);
                }
                result.ptr(r, c).* = product;
            }
        }

        return result;
    }

    pub const identity = Mat4{ .m = [16]f32{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    } };

    pub fn format(
        self: Mat4,
        comptime fmt: []const u8,
        x: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = x;
        _ = fmt;
        _ = try writer.print(
            \\[
            \\  {d} {d} {d} {d}
            \\  {d} {d} {d} {d}
            \\  {d} {d} {d} {d}
            \\  {d} {d} {d} {d}
            \\]
        ,
            .{
                self.get(0, 0), self.get(0, 1), self.get(0, 2), self.get(0, 3),
                self.get(1, 0), self.get(1, 1), self.get(1, 2), self.get(1, 3),
                self.get(2, 0), self.get(2, 1), self.get(2, 2), self.get(2, 3),
                self.get(3, 0), self.get(3, 1), self.get(3, 2), self.get(3, 3),
            },
        );
    }
};

pub fn linearTest() void {
    const m1 = Mat4.identity;
    const m2 = Mat4.identity;
    const m3 = m1.mul(m2);

    std.debug.print("m1: {}\nm3: {}\n", .{ m1, m3 });

    const v1 = Vec4{ .x = 1, .y = 1, .z = 1, .w = 1 };
    const v2 = v1.matMul(m3);

    std.debug.print("v1: {}\nv2: {}\n", .{ v1, v2 });
}
