const std = @import("std");

const ParamEvaluatorError = error{
    SyntaxError,
    ParameterOutOfRange,
    InvalidParameter,
    InvalidVariable,
    InvalidValue,
    StackEmpty,
    InvalidBase,
} || std.mem.Allocator.Error;

pub const Value = union(enum) {
    number: i32,
    string: []const u8,
};

const fmt_flag_minus: u8 = 0x01;
const fmt_flag_plus: u8 = 0x02;
const fmt_flag_hash: u8 = 0x04;

fn inRange(val: anytype, min: @TypeOf(val), max: @TypeOf(val)) bool {
    return (min <= val and val <= max);
}

fn writeAligned(writer: anytype, string: []const u8, width: u8, left: bool) !void {
    var cnt: usize = string.len;
    if (!left) while (cnt < width) : (cnt += 1) try writer.writeByte(' ');
    cnt = try writer.write(string);
    if (left) while (cnt < width) : (cnt += 1) try writer.writeByte(' ');
}

// return the number of digits in an int32. The '-' for negative numbers is not counted!
// The largest u32 is 4294967295, so max 10 digits
fn numDigits(num: u32, base: u8) !u8 {
    var bits: u32 = 0;
    var shift: u3 = 0;
    if (base == 10) {
        if (num >= 1000000000) return 10;
        if (num >= 100000000) return 9;
        if (num >= 10000000) return 8;
        if (num >= 1000000) return 7;
        if (num >= 100000) return 6;
        if (num >= 10000) return 5;
        if (num >= 1000) return 4;
        if (num >= 100) return 3;
        if (num >= 10) return 2;
        return 1;
    } else if (base == 16) {
        bits = 0x0F;
        shift = 4;
    } else if (base == 8) {
        bits = 0o7;
        shift = 3;
    } else return error.InvalidBase;

    var mask: u32 = bits << shift;
    var ndigits: u8 = 1;
    while (ndigits & mask != 0) {
        ndigits += 1;
        mask <<= shift;
    }
    return ndigits;
}

fn formatValue(writer: anytype, value: Value, fmt: u8, flags: u8, width: u8, prec: u8) ParamEvaluatorError!void {
    var buf: [16]u8 = undefined;
    var case: std.fmt.Case = .lower;
    var base: u8 = 10;
    switch (fmt) {
        'o' => {
            base = 8;
        },
        'x' => {
            base = 16;
        },
        'X' => {
            base = 16;
            case = .upper;
        },
        else => if (fmt != 'd' and fmt != 's') return error.SyntaxError,
    }

    if (value == .number and fmt != 's') {
        const negative: bool = if (value.number < 0) true else false;
        const num: u32 = if (value.number < 0) ~@as(u32, @bitCast(value.number)) + 1 else @as(u32, @intCast(value.number));
        const options = std.fmt.FormatOptions{};
        var idx: u8 = 0;
        var ndigits: u8 = 0;
        if (flags & fmt_flag_plus != 0 and !negative) {
            buf[idx] = '+';
            idx += 1;
        }
        if (negative) {
            buf[idx] = '-';
            idx += 1;
        }
        if (flags & fmt_flag_hash != 0) {
            switch (fmt) {
                'o' => {
                    buf[idx] = '0';
                    idx += 1;
                    ndigits = 1;
                },
                'x', 'X' => {
                    buf[idx] = '0';
                    buf[idx + 1] = 'x';
                    idx += 2;
                },
                else => {},
            }
        }
        const numlen = try numDigits(num, base);
        if (prec > numlen) {
            while (ndigits < prec - numlen) {
                buf[idx] = '0';
                idx += 1;
                ndigits += 1;
            }
        }
        const len = std.fmt.formatIntBuf(buf[idx..], num, base, .lower, options) + idx;
        try writeAligned(writer, buf[0..len], width, flags & fmt_flag_minus != 0);
    } else if (value == .string and fmt == 's') {
        try writeAligned(writer, value.string, width, flags & fmt_flag_minus != 0);
    } else return error.InvalidValue;
}

pub const ParamEvaluator = struct {
    const Self = @This();

    pub const Error = ParamEvaluatorError;

    allocator: std.mem.Allocator,
    stack: std.ArrayList(Value),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .stack = std.ArrayList(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.stack.deinit();
    }

    fn push(self: *Self, val: Value) std.mem.Allocator.Error!void {
        try self.stack.append(val);
    }

    fn pop(self: *Self) ParamEvaluatorError!Value {
        if (self.stack.items.len == 0) return error.StackEmpty;
        return self.stack.pop();
    }

    fn doRun(self: *Self, str: []const u8, param: []Value) ParamEvaluatorError![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        var variable: [52]Value = undefined;
        var pc: u16 = 0;
        var in_if: bool = false;

        while (pc < str.len) {
            if (str[pc] != '%') {
                try result.append(str[pc]);
                pc += 1;
                continue;
            }
            pc += 1;
            switch (str[pc]) {
                // %%   outputs “%”
                '%' => {
                    try result.append('%');
                    pc += 1;
                },

                //  %c   print pop() like %c in printf
                'c' => {
                    const value = try self.pop();
                    if (value == .number) {
                        try result.append(@as(u8, @intCast(value.number & 0xff)));
                    } else {
                        return error.InvalidValue;
                    }
                    pc += 1;
                },

                //  %p[1-9]
                //       push i'th parameter
                'p' => {
                    pc += 1;
                    if (!inRange(str[pc], '1', '9')) return error.ParameterOutOfRange;
                    if (!inRange(str[pc] - '0', 1, @as(u8, @truncate(param.len)))) return error.ParameterOutOfRange;
                    try self.push(param[str[pc] - '1']);
                    pc += 1;
                },

                //  %P[a-z]
                //       set dynamic variable [a-z] to pop()
                //  %P[A-Z]
                //       set static variable [a-z] to pop()
                'P' => {
                    pc += 1;
                    if (inRange(str[pc], 'a', 'z')) {
                        variable[str[pc] - 'a'] = try self.pop();
                    } else if (inRange(str[pc], 'A', 'Z')) {
                        variable[str[pc] - 'A' + 26] = try self.pop();
                    } else {
                        return error.InvalidParameter;
                    }
                    pc += 1;
                },

                //  %g[a-z]/
                //       get dynamic variable [a-z] and push it
                //  %g[A-Z]
                //       get static variable [a-z] and push it
                'g' => {
                    pc += 1;
                    if (inRange(str[pc], 'a', 'z')) {
                        try self.push(variable[str[pc] - 'a']);
                        pc += 1;
                        if (str[pc] != '/') return error.SyntaxError;
                    } else if (inRange(str[pc], 'A', 'Z')) {
                        try self.push(variable[str[pc] - 'A' + 26]);
                    } else {
                        return error.InvalidParameter;
                    }
                    pc += 1;
                },

                //  %'c' char constant c
                '\'' => {
                    pc += 1;
                    try self.push(.{ .number = str[pc] });
                    pc += 1;
                    if (str[pc] != '\'') return error.SyntaxError;
                    pc += 1;
                },

                //  %{nn}
                //       integer constant nn
                '{' => {
                    pc += 1;
                    var num: i32 = 0;
                    while (str[pc] != '}') : (pc += 1) {
                        if (!inRange(str[pc], '0', '9')) return error.SyntaxError;
                        num = (num * 10) + str[pc] - '0';
                    }
                    try self.push(.{ .number = num });
                    pc += 1;
                },

                //  %l   push strlen(pop)
                'l' => {
                    const value = try self.pop();
                    if (value == .string) {
                        try self.push(.{ .number = @as(i32, @intCast(value.string.len)) });
                    } else {
                        return error.InvalidValue;
                    }
                    pc += 1;
                },

                //  %+, %-, %*, %/, %m
                //       arithmetic (%m is mod): push(pop() op pop())
                //  %&, %|, %^
                //       bit operations (AND, OR and exclusive-OR): push(pop() op pop())
                //  %=, %>, %<
                //       logical operations: push(pop() op pop())
                //  %A, %O
                //       logical AND and OR operations (for conditionals)
                // beware: while the pop() op pop() might make you think that the topmost
                // item on the stack is the LHS of the operation, it is actually the other
                // way round. See https://github.com/mirror/ncurses/blob/master/ncurses/tinfo/lib_tparm.c
                '+', '-', '*', '/', 'm', '&', '|', '^', '=', '>', '<', 'A', 'O' => |op| {
                    const val2 = try self.pop();
                    const val1 = try self.pop();
                    if (val1 != .number or val2 != .number) return error.InvalidValue;
                    const t: i32 = 1;
                    const f: i32 = 0;
                    const res: i32 = switch (op) {
                        '+' => val1.number + val2.number,
                        '-' => val1.number - val2.number,
                        '*' => val1.number * val2.number,
                        '/' => @divTrunc(val1.number, val2.number),
                        'm' => @mod(val1.number, val2.number),
                        '&' => val1.number & val2.number,
                        '|' => val1.number | val2.number,
                        '^' => val1.number ^ val2.number,
                        '=' => if (val1.number == val2.number) t else f,
                        '>' => if (val1.number > val2.number) t else f,
                        '<' => if (val1.number < val2.number) t else f,
                        'A' => if (val1.number != 0 and val2.number != 0) t else f,
                        'O' => if (val1.number != 0 or val2.number != 0) t else f,
                        else => unreachable,
                    };
                    try self.push(.{ .number = res });
                    pc += 1;
                },

                //  %!, %~
                //       unary operations (logical and bit complement): push(op pop())
                '!', '~' => |op| {
                    const value = try self.pop();
                    if (value != .number) return error.InvalidValue;
                    var res: i32 = 0;
                    if (op == '!') {
                        res = if (value.number == 0) 1 else 0;
                    } else {
                        res = ~value.number;
                    }
                    try self.push(.{ .number = res });
                    pc += 1;
                },

                //  %i   add 1 to first two parameters (for ANSI terminals)
                'i' => {
                    if (param[0] != .number or param[1] != .number) return error.InvalidParameter;
                    param[0].number += 1;
                    param[1].number += 1;
                    pc += 1;
                },

                //  %? expr %t thenpart %e elsepart %;
                //       It is possible to form else-if's a la Algol 68:
                //       %? c1 %t b1 %e c2 %t b2 %e c3 %t b3 %e c4 %t b4 %e %;
                '?' => {
                    if (in_if) return error.SyntaxError;
                    in_if = true;
                    pc += 1;
                },

                ';' => {
                    if (!in_if) return error.SyntaxError;
                    in_if = false;
                    pc += 1;
                },

                't' => {
                    if (!in_if) return error.SyntaxError;
                    const value = try self.pop();
                    if (value != .number) return error.InvalidValue;
                    pc += 1;
                    if (value.number == 0) {
                        // skip "then" part
                        while (str[pc] != '%' or (str[pc + 1] != 'e' and str[pc + 1] != ';')) pc += 1;
                        if (str[pc + 1] != ';') pc += 2;
                    }
                },

                'e' => {
                    if (!in_if) return error.SyntaxError;
                    // always skip "else" part if we encounter it here
                    pc += 1;
                    while (str[pc] != '%' or str[pc + 1] != ';') pc += 1;
                },

                // %[[:]flags][width[.precision]][doxXs]
                //       as in printf(3), flags are [-+#] and space.  Use a “:” to
                //       allow the next character to be a “-” flag, avoiding
                //       interpreting “%-” as an operator.
                //  %s   print pop() like %s in printf
                else => {
                    var flags: u8 = 0;
                    var width: u8 = 0;
                    var prec: u8 = 0;
                    if (str[pc] == ':') pc += 1;
                    while (str[pc] == '-' or str[pc] == '+' or str[pc] == '#') : (pc += 1) {
                        flags |= switch (str[pc]) {
                            '-' => fmt_flag_minus,
                            '+' => fmt_flag_plus,
                            '#' => fmt_flag_hash,
                            else => unreachable,
                        };
                    }
                    if (inRange(str[pc], '0', '9')) {
                        while (inRange(str[pc], '0', '9')) : (pc += 1) {
                            width = (width * 10) + str[pc] - '0';
                        }
                    }
                    if (str[pc] == '.') {
                        pc += 1;
                        while (inRange(str[pc], '0', '9')) : (pc += 1) {
                            prec = (prec * 10) + str[pc] - '0';
                        }
                    }
                    const format: u8 = str[pc];
                    try formatValue(result.writer(), try self.pop(), format, flags, width, prec);
                    pc += 1;
                },
            }
        }
        return result.toOwnedSlice();
    }

    pub fn run(self: *Self, str: []const u8, plist: anytype) ParamEvaluatorError![]const u8 {
        const PlistType = @TypeOf(plist);
        const plist_type_info = @typeInfo(PlistType);
        if (plist_type_info != .Struct) {
            @compileError("Expected tuple or struct argument, found " ++ @typeName(PlistType));
        }

        const fields_info = plist_type_info.Struct.fields;
        if (fields_info.len > 9) {
            @compileError("9 arguments max are supported per format call");
        }

        var param: [fields_info.len]Value = undefined;

        comptime var cnt: u16 = 0;
        inline while (cnt < plist.len) : (cnt += 1) {
            const T = @TypeOf(plist[cnt]);
            switch (@typeInfo(T)) {
                .ComptimeInt, .Int => {
                    param[cnt] = .{ .number = plist[cnt] };
                },
                .Pointer => |ptr_info| {
                    if (ptr_info.size == .Slice and ptr_info.child == u8) {
                        // Slice
                        param[cnt] = .{ .string = plist[cnt] };
                    } else if (ptr_info.size == .One and @typeInfo(ptr_info.child) == .Array and @typeInfo(ptr_info.child).Array.child == u8) {
                        // immediate String
                        param[cnt] = .{ .string = plist[cnt] };
                    } else return error.InvalidParameter;
                },
                else => return error.InvalidParameter,
            }
        }

        return self.doRun(str, &param);
    }
};

test "basic compilation" {
    @import("std").testing.refAllDecls(@This());
    @import("std").testing.refAllDecls(ParamEvaluator);
}

const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "basic interpolation" {
    const allocator = std.testing.allocator;
    var interpolator = ParamEvaluator.init(allocator);
    defer interpolator.deinit();

    const str1 = try interpolator.run("%p1%d", .{1});
    defer allocator.free(str1);
    try expect(std.mem.eql(u8, str1, "1"));

    const s: []const u8 = "XYZ";
    const str2 = try interpolator.run("%p1%s", .{s});
    defer allocator.free(str2);
    try expect(std.mem.eql(u8, str2, s));

    const str3 = try interpolator.run("%p1%s", .{"XYZ"});
    defer allocator.free(str3);
    try expect(std.mem.eql(u8, str3, "XYZ"));
}

test "formatting" {
    const allocator = std.testing.allocator;
    var interpolator = ParamEvaluator.init(allocator);
    defer interpolator.deinit();

    const str1 = try interpolator.run("%p1%2d", .{1});
    defer allocator.free(str1);
    try expect(std.mem.eql(u8, str1, " 1"));

    const str2 = try interpolator.run("%p1%:-2d", .{1});
    defer allocator.free(str2);
    try expect(std.mem.eql(u8, str2, "1 "));

    const str3 = try interpolator.run("%p1%.2d", .{1});
    defer allocator.free(str3);
    try expect(std.mem.eql(u8, str3, "01"));

    const str4 = try interpolator.run("%p1%.2d", .{-1});
    defer allocator.free(str4);
    try expect(std.mem.eql(u8, str4, "-01"));

    const str5 = try interpolator.run("%p1%.2d", .{111});
    defer allocator.free(str5);
    try expect(std.mem.eql(u8, str5, "111"));

    const str6 = try interpolator.run("%p1%3.2d", .{1});
    defer allocator.free(str6);
    try expect(std.mem.eql(u8, str6, " 01"));

    const str7 = try interpolator.run("%p1%#6.2x", .{-10});
    defer allocator.free(str7);
    try expect(std.mem.eql(u8, str7, " -0x0a"));
}

test "variables" {
    const allocator = std.testing.allocator;
    var interpolator = ParamEvaluator.init(allocator);
    defer interpolator.deinit();

    const str1 = try interpolator.run("%p1%Pa%p2%Pz%gz/%s%ga/%s", .{ "X", "Y" });
    defer allocator.free(str1);
    try expect(std.mem.eql(u8, str1, "YX"));

    const str2 = try interpolator.run("%p1%Pa%p2%PA%gA%s%ga/%s", .{ "X", "Y" });
    defer allocator.free(str2);
    try expect(std.mem.eql(u8, str2, "YX"));
}

test "if then else" {
    const allocator = std.testing.allocator;
    var interpolator = ParamEvaluator.init(allocator);
    defer interpolator.deinit();

    const str1 = try interpolator.run("%?%p1%tX%eY%;", .{1});
    defer allocator.free(str1);
    try expect(std.mem.eql(u8, str1, "X"));

    const str2 = try interpolator.run("%?%p1%tX%eY%;", .{0});
    defer allocator.free(str2);
    try expect(std.mem.eql(u8, str2, "Y"));

    const str3 = try interpolator.run("%?%p1%tX%;", .{1});
    defer allocator.free(str3);
    try expect(std.mem.eql(u8, str3, "X"));

    const str4 = try interpolator.run("%?%p1%tX%;", .{0});
    defer allocator.free(str4);
    try expect(std.mem.eql(u8, str4, ""));

    const str5 = try interpolator.run("%?%p1%tX%;Y", .{1});
    defer allocator.free(str5);
    try expect(std.mem.eql(u8, str5, "XY"));

    const str6 = try interpolator.run("%?%p1%tX%;Y", .{0});
    defer allocator.free(str6);
    try expect(std.mem.eql(u8, str6, "Y"));

    const str7 = try interpolator.run("%?%p1%tX%e%p2%tY%eZ%;", .{ 1, 0 });
    defer allocator.free(str7);
    try expect(std.mem.eql(u8, str7, "X"));

    const str8 = try interpolator.run("%?%p1%tX%e%p2%tY%eZ%;", .{ 0, 0 });
    defer allocator.free(str8);
    try expect(std.mem.eql(u8, str8, "Z"));

    const str9 = try interpolator.run("%?%p1%tX%e%p2%tY%eZ%;", .{ 0, 1 });
    defer allocator.free(str9);
    try expect(std.mem.eql(u8, str9, "Y"));

    const strA = try interpolator.run("%?%p1%tX%;%?%p2%tY%eZ%;", .{ 0, 0 });
    defer allocator.free(strA);
    try expect(std.mem.eql(u8, strA, "Z"));
}

test "expressions" {
    const allocator = std.testing.allocator;
    var interpolator = ParamEvaluator.init(allocator);
    defer interpolator.deinit();

    const str1 = try interpolator.run("%p1%{1}%-%d", .{2});
    defer allocator.free(str1);
    try expect(std.mem.eql(u8, str1, "1"));

    const str2 = try interpolator.run("%p1%{1}%>%d", .{2});
    defer allocator.free(str2);
    try expect(std.mem.eql(u8, str2, "1"));

    const str3 = try interpolator.run("%p1%{1}%<%d", .{2});
    defer allocator.free(str3);
    try expect(std.mem.eql(u8, str3, "0"));
}

test "errors" {
    const allocator = std.testing.allocator;
    var interpolator = ParamEvaluator.init(allocator);
    defer interpolator.deinit();

    try expectError(error.InvalidValue, interpolator.run("%p1%d", .{"X"}));
    try expectError(error.InvalidValue, interpolator.run("%p1%s", .{1}));
}
