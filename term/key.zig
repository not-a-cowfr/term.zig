const std = @import("std");

/// all of the keys this library knows about. Keep in mind, though, that these may not all
/// be available from your terminal.
pub const Key = enum(u8) {
    CtrlSpace = 0,
    CtrlA,
    CtrlB,
    CtrlC,
    CtrlD,
    CtrlE,
    CtrlF,
    CtrlG,
    CtrlH,
    Tab,
    CtrlJ,
    CtrlK,
    CtrlL,
    Return,
    CtrlN,
    CtrlO,
    CtrlP,
    CtrlQ,
    CtrlR,
    CtrlS,
    CtrlT,
    CtrlU,
    CtrlV,
    CtrlW,
    CtrlX,
    CtrlY,
    CtrlZ,
    Escape, // 0x1b
    Ctrl4, // 0x1c
    Ctrl5, // 0x1d
    Ctrl6, // 0x1e
    Ctrl7, // 0x1f

    Backspace = 0x7f,
    Character, // 0x80, no key, denotes that the key returned a "character"
    Up,
    Down,
    Right,
    Left,
    Center,
    Enter,
    PgUp,
    PgDown,
    Home,
    End,
    Insert,
    Delete,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,

    // shift + key
    sUp,
    sDown,
    sRight,
    sLeft,
    sHome,
    sEnd,
    sPgUp,
    sPgDown,
    sInsert,
    sDelete,
    sF1,
    sF2,
    sF3,
    sF4,
    sF5,
    sF6,
    sF7,
    sF8,
    sF9,
    sF10,
    sF11,
    sF12,

    // control + key
    cUp,
    cDown,
    cRight,
    cLeft,
    cHome,
    cEnd,
    cPgUp,
    cPgDown,
    cInsert,
    cDelete,
    cF1,
    cF2,
    cF3,
    cF4,
    cF5,
    cF6,
    cF7,
    cF8,
    cF9,
    cF10,
    cF11,
    cF12,

    // control + shift + key
    csUp,
    csDown,
    csRight,
    csLeft,
    csHome,
    csEnd,
    csPgUp,
    csPgDown,
    csInsert,
    csDelete,
    csF1,
    csF2,
    csF3,
    csF4,
    csF5,
    csF6,
    csF7,
    csF8,
    csF9,
    csF10,
    csF11,
    csF12,

    Unknown = 0xFF,
};

pub const KeyMap = struct {
    const Entry = struct {
        string: []const u8,
        key: Key,
    };

    is_finalized: bool = false,
    entries: std.ArrayList(Entry),

    pub fn init(allocator: std.mem.Allocator) !KeyMap {
        return KeyMap{
            .entries = std.ArrayList(Entry).init(allocator),
        };
    }

    pub fn deinit(self: *KeyMap) void {
        self.entries.deinit();
    }

    pub fn store(self: *KeyMap, string: []const u8, key: Key) !void {
        self.is_finalized = false;
        try self.entries.append(.{ .string = string, .key = key });
    }

    pub fn finalize(self: *KeyMap) void {
        const lessThan = struct {
            pub fn func(context: void, a: Entry, b: Entry) bool {
                _ = context;
                return std.mem.lessThan(u8, a.string, b.string);
            }
        };
        std.mem.sort(Entry, self.entries.items, {}, lessThan.func);
        self.is_finalized = true;
    }

    pub fn get(self: KeyMap, string: []const u8) ?Key {
        const compare = struct {
            pub fn func(context: void, lhs: Entry, rhs: Entry) std.math.Order {
                _ = context;
                return std.mem.order(u8, lhs.string, rhs.string);
            }
        };
        if (self.is_finalized) {
            const pattern: Entry = .{ .string = string, .key = .Unknown };
            const match = std.sort.binarySearch(Entry, pattern, self.entries.items, {}, compare.func);
            if (match != null) {
                return self.entries.items[match.?].key;
            }
        } else {
            for (self.entries.items) |entry| {
                if (std.mem.eql(u8, entry.string, string)) return entry.key;
            }
        }
        return null;
    }

    pub fn hasKey(self: KeyMap, key: Key) bool {
        for (self.entries.items) |entry| {
            if (entry.key == key) return true;
        }
        return false;
    }
};

test "basic compilation" {
    @import("std").testing.refAllDecls(@This());
    @import("std").testing.refAllDecls(KeyMap);
}

test "KeyMap" {
    const allocator = std.testing.allocator;
    var keymap = try KeyMap.init(allocator);
    defer keymap.deinit();

    try keymap.store("asdf1", .F1);
    try keymap.store("asdf2", .F2);
    try keymap.store("asdf3", .F3);
    try keymap.store("asdf4", .F4);
    try keymap.store("asdel", .Delete);

    try std.testing.expect(keymap.get("asdel").? == .Delete);
    try std.testing.expect(keymap.get("asdf4").? == .F4);
    try std.testing.expect(keymap.get("asdf2").? == .F2);
    try std.testing.expect(keymap.get("asdf3").? == .F3);
    try std.testing.expect(keymap.get("asdf1").? == .F1);

    keymap.finalize();

    try std.testing.expect(keymap.get("asdel").? == .Delete);
    try std.testing.expect(keymap.get("asdf4").? == .F4);
    try std.testing.expect(keymap.get("asdf2").? == .F2);
    try std.testing.expect(keymap.get("asdf3").? == .F3);
    try std.testing.expect(keymap.get("asdf1").? == .F1);

    try std.testing.expect(keymap.hasKey(.F1));
    try std.testing.expect(!keymap.hasKey(.F12));
}
