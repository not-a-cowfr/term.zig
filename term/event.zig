const Key = @import("key.zig").Key;

/// this struct represents an event that can be polled from the Term struct
pub const Event = union(enum) {
    /// Event == .none signifies that no event occurred
    none: struct {},
    /// Event == .key signifies a key press event. The .key field is one of the values
    /// from the Key enum, .Character if the pressed key returned a printable character.
    /// In that case, the value of this character is stored in .char
    key: struct {
        char: u32 = 0,
        key: Key = .Unknown,
    },
    /// Event == .resize is a terminal resize event. Not all terminals have this, obviously...
    resize: struct {
        w: u16 = 0,
        h: u16 = 0,
    },

    pub fn noEvent() Event {
        return Event{ .none = .{} };
    }

    pub fn keyEvent(key: Key, char: u32) Event {
        return Event{ .key = .{ .char = char, .key = key } };
    }

    pub fn resizeEvent(w: u16, h: u16) Event {
        return Event{ .resize = .{ .w = w, .h = h } };
    }
};

test "basic compilation" {
    @import("std").testing.refAllDecls(@This());
    @import("std").testing.refAllDecls(Event);
}
