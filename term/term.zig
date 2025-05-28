//! This library is an interface to the systems terminal. On Unixen, this provides
//! termios functionality in term.ios, and terminfo functionality in term.info.
//! On all supported systems, the Term struct provides a simple grid-based interface
//! to the terminal.

const std = @import("std");

pub const info = @import("info.zig");
pub const ios = @import("ios.zig");

pub const Event = @import("event.zig").Event;
const key = @import("key.zig");
pub const Key = key.Key;

const buffer = @import("buffer.zig");
const TermBuffer = buffer.TermBuffer;
const Terminfo = info.Terminfo;

// the list of recognized keys and how they map to terminfo capabilities
const keymappings = [_]struct {
    ikey: info.Strings, // termInfo cap
    tkey: key.Key, // Term key
}{
    .{ .ikey = .key_backspace, .tkey = .Backspace },
    .{ .ikey = .key_up, .tkey = .Up },
    .{ .ikey = .key_down, .tkey = .Down },
    .{ .ikey = .key_right, .tkey = .Right },
    .{ .ikey = .key_left, .tkey = .Left },
    .{ .ikey = .key_b2, .tkey = .Center },
    .{ .ikey = .key_enter, .tkey = .Enter },
    .{ .ikey = .key_ppage, .tkey = .PgUp },
    .{ .ikey = .key_npage, .tkey = .PgDown },
    .{ .ikey = .key_home, .tkey = .Home },
    .{ .ikey = .key_end, .tkey = .End },
    .{ .ikey = .key_ic, .tkey = .Insert },
    .{ .ikey = .key_dc, .tkey = .Delete },
    .{ .ikey = .key_f1, .tkey = .F1 },
    .{ .ikey = .key_f2, .tkey = .F2 },
    .{ .ikey = .key_f3, .tkey = .F3 },
    .{ .ikey = .key_f4, .tkey = .F4 },
    .{ .ikey = .key_f5, .tkey = .F5 },
    .{ .ikey = .key_f6, .tkey = .F6 },
    .{ .ikey = .key_f7, .tkey = .F7 },
    .{ .ikey = .key_f8, .tkey = .F8 },
    .{ .ikey = .key_f9, .tkey = .F9 },
    .{ .ikey = .key_f10, .tkey = .F10 },
    .{ .ikey = .key_f11, .tkey = .F11 },
    .{ .ikey = .key_f12, .tkey = .F12 },

    .{ .ikey = .kUP, .tkey = .sUp },
    .{ .ikey = .kDN, .tkey = .sDown },
    .{ .ikey = .key_sright, .tkey = .sRight },
    .{ .ikey = .key_sleft, .tkey = .sLeft },
    .{ .ikey = .key_sprevious, .tkey = .sPgUp },
    .{ .ikey = .key_snext, .tkey = .sPgDown },
    .{ .ikey = .key_shome, .tkey = .sHome },
    .{ .ikey = .key_send, .tkey = .sEnd },
    .{ .ikey = .key_sic, .tkey = .sInsert },
    .{ .ikey = .key_sdc, .tkey = .sDelete },
    .{ .ikey = .key_f13, .tkey = .sF1 },
    .{ .ikey = .key_f14, .tkey = .sF2 },
    .{ .ikey = .key_f15, .tkey = .sF3 },
    .{ .ikey = .key_f16, .tkey = .sF4 },
    .{ .ikey = .key_f17, .tkey = .sF5 },
    .{ .ikey = .key_f18, .tkey = .sF6 },
    .{ .ikey = .key_f19, .tkey = .sF7 },
    .{ .ikey = .key_f20, .tkey = .sF8 },
    .{ .ikey = .key_f21, .tkey = .sF9 },
    .{ .ikey = .key_f22, .tkey = .sF10 },
    .{ .ikey = .key_f23, .tkey = .sF11 },
    .{ .ikey = .key_f24, .tkey = .sF12 },

    .{ .ikey = .kUP5, .tkey = .cUp },
    .{ .ikey = .kDN5, .tkey = .cDown },
    .{ .ikey = .kRIT5, .tkey = .cRight },
    .{ .ikey = .kLFT5, .tkey = .cLeft },
    .{ .ikey = .kPRV5, .tkey = .cPgUp },
    .{ .ikey = .kNXT5, .tkey = .cPgDown },
    .{ .ikey = .kHOM5, .tkey = .cHome },
    .{ .ikey = .kEND5, .tkey = .cEnd },
    .{ .ikey = .kIC5, .tkey = .cInsert },
    .{ .ikey = .kDC5, .tkey = .cDelete },
    .{ .ikey = .key_f25, .tkey = .cF1 },
    .{ .ikey = .key_f26, .tkey = .cF2 },
    .{ .ikey = .key_f27, .tkey = .cF3 },
    .{ .ikey = .key_f28, .tkey = .cF4 },
    .{ .ikey = .key_f29, .tkey = .cF5 },
    .{ .ikey = .key_f30, .tkey = .cF6 },
    .{ .ikey = .key_f31, .tkey = .cF7 },
    .{ .ikey = .key_f32, .tkey = .cF8 },
    .{ .ikey = .key_f33, .tkey = .cF9 },
    .{ .ikey = .key_f34, .tkey = .cF10 },
    .{ .ikey = .key_f35, .tkey = .cF11 },
    .{ .ikey = .key_f36, .tkey = .cF12 },

    .{ .ikey = .kUP6, .tkey = .csUp },
    .{ .ikey = .kDN6, .tkey = .csDown },
    .{ .ikey = .kRIT6, .tkey = .csRight },
    .{ .ikey = .kLFT6, .tkey = .csLeft },
    .{ .ikey = .kPRV6, .tkey = .csPgUp },
    .{ .ikey = .kNXT6, .tkey = .csPgDown },
    .{ .ikey = .kHOM6, .tkey = .csHome },
    .{ .ikey = .kEND6, .tkey = .csEnd },
    .{ .ikey = .kIC6, .tkey = .csInsert },
    .{ .ikey = .kDC6, .tkey = .csDelete },
    .{ .ikey = .key_f37, .tkey = .csF1 },
    .{ .ikey = .key_f38, .tkey = .csF2 },
    .{ .ikey = .key_f39, .tkey = .csF3 },
    .{ .ikey = .key_f40, .tkey = .csF4 },
    .{ .ikey = .key_f41, .tkey = .csF5 },
    .{ .ikey = .key_f42, .tkey = .csF6 },
    .{ .ikey = .key_f43, .tkey = .csF7 },
    .{ .ikey = .key_f44, .tkey = .csF8 },
    .{ .ikey = .key_f45, .tkey = .csF9 },
    .{ .ikey = .key_f46, .tkey = .csF10 },
    .{ .ikey = .key_f47, .tkey = .csF11 },
    .{ .ikey = .key_f48, .tkey = .csF12 },
};

fn populateKeymap(ti: Terminfo, keymap: *key.KeyMap) !void {
    for (keymappings) |mapping| {
        if (ti.getString(mapping.ikey)) |str| try keymap.store(str, mapping.tkey);
    }
    keymap.finalize();
}

/// A simple grid-based interface to the terminal. Keypresses and resizes are Events
/// that can be polled using the pollEvent() method. This is rather low-level, it does
/// not provide any ui elements.
pub const Term = struct {
    pub const Error = error{
        CapNotSupported,
    };

    /// Scroll directions
    pub const Direction = TermBuffer.Direction;

    /// text attributes. Not all of these may be suported by your terminal
    pub const Attribute = enum(u3) {
        Standout = 0,
        Underline,
        Reverse,
        Blink,
        Dim,
        Bold,
        // note that the attributes before this line must be the first and in order.
        Italic,
        // only one more atribute...

        pub fn toU8(self: Attribute) u8 {
            return @as(u8, 1) << @intFromEnum(self);
        }
    };

    /// how overflow is handled. Both horizonal and vertical overflow may be clipped,
    /// horizontal overflow may wrap into the next line, and vertical overflow may
    /// trigger a scroll
    pub const HOverflow = enum {
        clip,
        wrap,
    };

    pub const VOverflow = enum {
        clip,
        scroll,
    };

    ttyfile: std.fs.File,
    sigfile: std.fs.File,
    t_ios: std.posix.termios,
    t_info: info.Terminfo,
    keymap: key.KeyMap,
    buffer: buffer.TermBuffer,
    supported_attrs: u8,
    attrs: u8 = 0,
    fgcolor: u8 = 0,
    bgcolor: u8 = 0,
    hflow: HOverflow = .clip,
    vflow: VOverflow = .clip,
    cursor: struct { x: u16, y: u16 } = .{ .x = 0, .y = 0 },

    /// the width of the terminal. This is updated when the terminal is resized
    width: u16,
    /// the height of the terminal. This is updated when the terminal is resized
    height: u16,
    /// the maximum number of colors the terminal can handle. Defaults to 1, if the terminal
    /// does not support color at all.
    colors: i32,

    fn writeStringCap(self: Term, cap: info.Strings) !void {
        const cap_str = self.t_info.getString(cap);
        if (cap_str != null) {
            _ = try self.ttyfile.write(cap_str.?);
        } else {
            return error.CapNotSupported;
        }
    }

    fn writeStringCapParam(self: Term, cap: info.Strings, param: anytype) !void {
        const cap_str = try self.t_info.getInterpolatedString(cap, param);
        defer self.t_info.freeInterpolatedString(cap_str);
        if (cap_str != null) {
            _ = try self.ttyfile.write(cap_str.?);
        } else {
            return error.CapNotSupported;
        }
    }

    fn getSupportedAttrs(ti: Terminfo) u8 {
        var attrs: u8 = 0;
        if (ti.getString(.enter_standout_mode) != null) attrs |= Attribute.toU8(.Standout);
        if (ti.getString(.enter_underline_mode) != null) attrs |= Attribute.toU8(.Underline);
        if (ti.getString(.enter_reverse_mode) != null) attrs |= Attribute.toU8(.Reverse);
        if (ti.getString(.enter_blink_mode) != null) attrs |= Attribute.toU8(.Blink);
        if (ti.getString(.enter_dim_mode) != null) attrs |= Attribute.toU8(.Dim);
        if (ti.getString(.enter_bold_mode) != null) attrs |= Attribute.toU8(.Bold);
        if (ti.getString(.enter_italics_mode) != null) attrs |= Attribute.toU8(.Italic);
        return attrs;
    }

    fn enterScreen(self: *Term) !void {
        var raw_termios = self.t_ios;
        ios.cfmakeraw(&raw_termios);
        try ios.tcsetattr(self.ttyfile.handle, std.os.linux.TCSA.FLUSH, raw_termios);
        self.writeStringCap(.enter_ca_mode) catch {}; // uncritical setting
        self.writeStringCap(.keypad_xmit) catch {}; // uncritical setting
        self.clearScreen();
        self.clearAllAttributes();
    }

    fn exitScreen(self: Term) !void {
        try self.writeStringCap(.exit_attribute_mode);
        self.writeStringCap(.keypad_local) catch {}; // uncritical setting
        self.writeStringCap(.exit_ca_mode) catch {}; // uncritical setting
        try ios.tcsetattr(self.ttyfile.handle, std.os.linux.TCSA.FLUSH, self.t_ios);
    }

    /// create and initialize a Term struct. This prepares the terminal for interaction
    /// with the Term struct, and also determines the available capabilities.
    pub fn init(allocator: std.mem.Allocator) !Term {
        var ttyfile = try std.fs.openFileAbsolute("/dev/tty", .{ .mode = .read_write });
        errdefer ttyfile.close();
        const t_ios = try ios.tcgetattr(ttyfile.handle);
        const term_name = std.posix.getenv("TERM");
        var t_info = try info.Terminfo.init(allocator, term_name.?);
        errdefer t_info.deinit();
        // setup a signal fd for the WINCH signals
        var sigset: std.posix.sigset_t = std.posix.empty_sigset;
        std.os.linux.sigaddset(&sigset, std.os.linux.SIG.WINCH);
        _ = std.os.linux.sigprocmask(std.os.linux.SIG.BLOCK, &sigset, null);
        var sigfile: std.fs.File = .{ .handle = try std.posix.signalfd(-1, &sigset, 0) };
        errdefer sigfile.close();
        var keymap = try key.KeyMap.init(allocator);
        errdefer keymap.deinit();
        try populateKeymap(t_info, &keymap);
        const size = try ios.tcgetwinsize(ttyfile.handle);

        var self = Term{
            .ttyfile = ttyfile,
            .sigfile = sigfile,
            .t_ios = t_ios,
            .t_info = t_info,
            .keymap = keymap,
            .buffer = try TermBuffer.init(allocator, size.ws_col, size.ws_row),
            .width = size.ws_col,
            .height = size.ws_row,
            .colors = t_info.getNumber(.max_colors) orelse 1,
            .supported_attrs = getSupportedAttrs(t_info),
        };

        try self.enterScreen();
        // communicate initial size to client
        try std.posix.raise(std.os.linux.SIG.WINCH);
        return self;
    }

    /// call this to finalize your interaction with the Term struct. This frees any
    /// allocated memory and closes any handles the Term my hold. It also returns the terminal
    /// to a sane state for shell interaction.
    pub fn deinit(self: *Term) void {
        self.exitScreen() catch |err| @panic(@errorName(err));
        self.showCursor() catch |err| @panic(@errorName(err));
        self.sigfile.close();
        self.buffer.deinit();
        self.t_info.deinit();
        self.keymap.deinit();
        self.ttyfile.close();
    }

    /// return true if the Term struct knows about the key, false if not.
    pub fn hasKey(self: Term, k: Key) bool {
        return self.keymap.hasKey(k);
    }

    /// return true if the terminal has this attribute, false if not.
    pub fn hasAttr(self: Term, a: Attribute) bool {
        return self.supported_attrs & a.toU8() != 0;
    }

    /// place the cursor. The coordinates are 0-based. The cursor position is not bound
    /// by the clip rectangle.
    // The y coordinate may be 1 line beyond the end of the terminal in order for the
    // scrolling to work at the bottom of the terminal
    pub fn setCursor(self: *Term, x: u16, y: u16) void {
        self.cursor.x = if (x < self.width) x else self.width - 1;
        self.cursor.y = if (y < self.height) y else self.height;
    }

    /// puts the cursor to the top left coordinate of the current clip rectangle
    pub fn homeCursor(self: *Term) void {
        self.cursor.x = self.buffer.clip.xmin;
        self.cursor.y = self.buffer.clip.ymin;
    }

    /// get the current cursor position
    pub fn getCursor(self: Term, x: *u16, y: *u16) void {
        x.* = self.cursor.x;
        y.* = self.cursor.y;
    }

    /// make the cursor visible
    pub fn showCursor(self: Term) !void {
        try self.writeStringCap(.cursor_normal);
    }

    /// make the cursor invisible
    pub fn hideCursor(self: Term) !void {
        try self.writeStringCap(.cursor_invisible);
    }

    /// sets the clip rectangle
    pub fn setClip(self: *Term, xmin: u16, xmax: u16, ymin: u16, ymax: u16) !void {
        return self.buffer.setClip(xmin, xmax, ymin, ymax);
    }

    /// resets the clip rectangle to cover the entire terminal
    pub fn resetClip(self: *Term) void {
        self.buffer.resetClip();
    }

    pub fn setHOverflow(self: *Term, v: HOverflow) void {
        self.hflow = v;
    }

    pub fn setVOverflow(self: *Term, v: VOverflow) void {
        self.vflow = v;
    }

    /// resets the clip rectangle, clears the entire screen to the current background color,
    /// and sets the cursor to position 0, 0.
    pub fn clearScreen(self: *Term) void {
        self.buffer.clearAll(self.bgcolor);
        self.setCursor(0, 0);
    }

    /// clears the clip rectangle to the current background color
    pub fn clear(self: Term) void {
        self.buffer.clear(self.bgcolor);
    }

    /// write a character to the terminal at position x, y. This does almost no checking
    /// on the character, only characters < space are output a space.
    pub fn writeCharAt(self: Term, x: u16, y: u16, char: u21) void {
        // the buffer handles chars < ' '
        self.buffer.setCell(x, y, .{ .char = char, .changed = true, .attr = self.attrs, .fg = self.fgcolor, .bg = self.bgcolor });
    }

    /// write a character at cursor pos, advancing cursor.This also handles the overflow
    /// disciplines. WriteChar() implements the \r and \n control codes, \r returning the
    /// cursor to the leftmost position within the current clip rectangle, and \n moving
    /// the cursor to the leftmost position within the clippling rectangle of the next line.
    /// Note that scrolling occurs not after the newline is issued, but when something is
    /// written to the new line.
    pub fn writeChar(self: *Term, char: u21) void {
        const clip = self.buffer.clip;
        if (self.cursor.x > clip.xmax and self.hflow == .wrap) {
            self.cursor.x = clip.xmin;
            self.cursor.y += 1;
        }
        if (self.cursor.y > clip.ymax and self.vflow == .scroll) {
            try self.scroll(.up, 1);
            self.cursor.y = clip.ymax;
        }
        switch (char) {
            '\r' => {
                self.cursor.x = clip.xmin;
            },
            '\n' => {
                self.cursor.x = clip.xmin;
                self.cursor.y += 1;
            },
            else => {
                self.writeCharAt(self.cursor.x, self.cursor.y, char);
                self.cursor.x += 1;
            },
        }
    }

    /// write a string to the screen at position x, y. This does not honor the overflow
    /// disciplines. Invalid utf8 characters are output as space.
    pub fn writeStringAt(self: Term, x: u16, y: u16, s: []const u8) !void {
        var rx = x;
        var utf8 = (try std.unicode.Utf8View.init(s)).iterator();
        while (utf8.nextCodepointSlice()) |cps| {
            const cp = std.unicode.utf8Decode(cps) catch ' ';
            self.writeCharAt(rx, y, cp);
            rx += 1;
        }
    }

    /// write a string at cursor pos, advancing cursor and honoring the overflow
    /// disciplines. Invalid utf8 characters are output as space, \r and \n are
    /// implemented as for writeChar()
    pub fn writeString(self: *Term, s: []const u8) !void {
        _ = try self.write(s);
    }

    const WriterError = error{InvalidUtf8};

    fn write(self: *Term, s: []const u8) WriterError!usize {
        var utf8 = (try std.unicode.Utf8View.init(s)).iterator();
        while (utf8.nextCodepointSlice()) |cps| {
            const cp = std.unicode.utf8Decode(cps) catch ' ';
            self.writeChar(cp);
        }
        return s.len;
    }

    pub const Writer = std.io.Writer(*Term, WriterError, write);

    /// returns a writer for the terminal that uses writeString() to output the data
    pub fn writer(self: *Term) Writer {
        return .{ .context = self };
    }

    /// sets foreground color. What values fg may take depends on the number
    /// of colors your terminal can display.
    pub fn setFgColor(self: *Term, fg: u8) void {
        self.fgcolor = fg;
    }

    /// sets background color. What values bg may take depends on the number
    /// of colors your terminal can display.
    pub fn setBgColor(self: *Term, bg: u8) void {
        self.bgcolor = bg;
    }

    /// sets text attributes. See enum Term.Attributes for which attributes are allowed here.
    pub fn setAttribute(self: *Term, attr: Attribute) void {
        self.attrs |= attr.toU8();
    }

    /// clears text attributes. See enum Term.Attributes for which attributes are allowed here.
    pub fn clearAttribute(self: *Term, attr: Attribute) void {
        self.attrs &= ~(attr.toU8());
    }

    /// clears all text attributes and resets the colors to their default values
    pub fn clearAllAttributes(self: *Term) void {
        self.attrs = 0;
        self.fgcolor = if (self.colors == 8) 7 else 15;
        self.bgcolor = 0;
    }

    /// scrolls the contents of the clip rectangle in the desired direction
    pub fn scroll(self: Term, dir: Direction, amount: u16) !void {
        self.buffer.scroll(dir, amount, self.bgcolor);
    }

    fn pollInput(self: Term) !Event {
        var buf: [16]u8 = undefined;
        const cnt = try self.ttyfile.read(&buf);

        if (self.keymap.get(buf[0..cnt])) |found| {
            return Event.keyEvent(found, 0);
        }

        if (buf[0] >= ' ') {
            return Event.keyEvent(Key.Character, try std.unicode.utf8Decode(buf[0..cnt]));
        }

        if (cnt == 1) {
            return Event.keyEvent(@as(Key, @enumFromInt(buf[0])), 0);
        }

        // DEBUG: dump buffer
        for (buf[0..cnt]) |c| {
            if (c >= '!' and c <= '~') {
                std.debug.print("{c}", .{c});
            } else {
                std.debug.print("\\x{x:02}", .{c});
            }
        }
        std.debug.print("\r\n", .{});
        // end DEBUG

        return Event.keyEvent(Key.Unknown, 0);
    }

    fn pollSignal(self: *Term) !Event {
        var buf: [@sizeOf(std.posix.siginfo_t)]u8 = undefined;
        _ = try self.sigfile.read(&buf);
        if (buf[0] != std.os.linux.SIG.WINCH) unreachable; // should not catch any other events
        const size = try ios.tcgetwinsize(self.ttyfile.handle);
        self.width = size.ws_col;
        self.height = size.ws_row;
        try self.buffer.resize(self.width, self.height);
        return Event.resizeEvent(size.ws_col, size.ws_row);
    }

    /// poll a single event from the terminal, or time out after tmout milliseconds.
    /// If tmout is -1, this behaves just like pollEvent(). If tmout is 0, this returns
    /// immediately with a noEvent, if no event is pending. Otherwise it waits for tmout
    /// milliseconds for an event, which it returns if one occurs, and otherwise returns
    /// noEvent. See the Event struct for what can be returned here.
    pub fn pollEventTimeout(self: *Term, tmout: i32) !Event {
        var pollfds = [_]std.posix.pollfd{
            .{ .fd = self.ttyfile.handle, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = self.sigfile.handle, .events = std.posix.POLL.IN, .revents = 0 },
        };

        // std.os.poll is not interrupted by signals!
        if (0 < try std.posix.poll(&pollfds, tmout)) {
            if (pollfds[0].revents & std.posix.POLL.IN != 0) {
                return self.pollInput();
            }
            if (pollfds[1].revents & std.posix.POLL.IN != 0) {
                return self.pollSignal();
            }
        }
        return Event.noEvent();
    }

    /// poll a single event from the terminal, blocking until an event is available.
    /// See the Event struct for what can be returned here.
    pub fn pollEvent(self: *Term) !Event {
        return self.pollEventTimeout(-1);
    }

    fn setAttributes(self: Term, want_attrs: u8) !void {
        const attrs = want_attrs & self.supported_attrs;
        try self.writeStringCap(.exit_attribute_mode);
        if (attrs & Attribute.toU8(.Standout) != 0) try self.writeStringCap(.enter_standout_mode);
        if (attrs & Attribute.toU8(.Underline) != 0) try self.writeStringCap(.enter_underline_mode);
        if (attrs & Attribute.toU8(.Reverse) != 0) try self.writeStringCap(.enter_reverse_mode);
        if (attrs & Attribute.toU8(.Blink) != 0) try self.writeStringCap(.enter_blink_mode);
        if (attrs & Attribute.toU8(.Dim) != 0) try self.writeStringCap(.enter_dim_mode);
        if (attrs & Attribute.toU8(.Bold) != 0) try self.writeStringCap(.enter_bold_mode);
        if (attrs & Attribute.toU8(.Italic) != 0) try self.writeStringCap(.enter_italics_mode);
        // if (attrs & 128 != 0) ...
    }

    /// push the most recent set of changes to the terminal
    pub fn update(self: *Term) !void {
        try self.writeStringCap(.exit_attribute_mode);
        var x: u16 = 0;
        var y: u16 = 0;
        var px: u16 = 65534;
        var py: u16 = 65535;
        var pcell = TermBuffer.Cell{};
        var changedCells = self.buffer.changedCellIterator();
        while (changedCells.next(&x, &y)) |cell| {
            if (cell.attr != pcell.attr) {
                try self.setAttributes(cell.attr);
                pcell.attr = cell.attr;
            }
            if (cell.fg != pcell.fg) {
                try self.writeStringCapParam(.set_a_foreground, .{cell.fg});
                pcell.fg = cell.fg;
            }
            if (cell.bg != pcell.bg) {
                try self.writeStringCapParam(.set_a_background, .{cell.bg});
                pcell.bg = cell.bg;
            }
            // if the current cell is one right from the previous cell, we use the fact that
            // the terminal advances the cursor when outputting a char
            if (py < y or px + 1 != x) {
                try self.writeStringCapParam(.cursor_address, .{ y, x });
            }
            px = x;
            py = y;
            if (cell.char != 0) {
                var u8char: [4]u8 = undefined;
                const len = try std.unicode.utf8Encode(cell.char, &u8char);
                _ = try self.ttyfile.write(u8char[0..len]);
            }
        }

        try self.writeStringCap(.exit_attribute_mode);
        if (self.cursor.y < self.height) {
            try self.writeStringCapParam(.cursor_address, .{ self.cursor.y, self.cursor.x });
        }
    }

    /// push the entire back buffer to the terminal, regardless of changed or not.
    pub fn redraw(self: *Term) !void {
        self.buffer.invalidate();
        try self.update();
    }
};

test "basic compilation" {
    @import("std").testing.refAllDecls(@This());
    @import("std").testing.refAllDecls(Term);
}

test "data corruption" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var t = try Term.init(allocator);
    defer t.deinit();
    for (t.buffer.contents) |c| {
        try std.testing.expect(c.char == ' ');
    }
    //t.writeCharAt(0, 0, 'X');
    //try std.testing.expect(t.buffer.contents[0].char == 'X');
    try t.update();
}
