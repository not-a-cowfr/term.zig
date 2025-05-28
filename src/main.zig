const std = @import("std");
const term = @import("term");

pub const Window = struct {
    const Self = @This();

    t: *term.Term,
    xmin: u16,
    xmax: u16,
    ymin: u16,
    ymax: u16,
    cx: u16 = 0,
    cy: u16 = 0,
    bg: u8 = 0,
    fg: u8 = 7,
    hv: term.Term.HOverflow = .clip,
    vv: term.Term.VOverflow = .clip,

    pub fn init(t: *term.Term, xmin: u16, xmax: u16, ymin: u16, ymax: u16) Window {
        return Window{
            .t = t,
            .xmin = xmin,
            .xmax = xmax,
            .ymin = ymin,
            .ymax = ymax,
            .cx = xmin,
            .cy = ymin,
        };
    }

    pub fn resize(self: *Self, xmin: u16, xmax: u16, ymin: u16, ymax: u16) void {
        self.xmin = xmin;
        self.xmax = xmax;
        self.ymin = ymin;
        self.ymax = ymax;
        self.homeCursor();
    }

    pub fn setColors(self: *Self, fg: u8, bg: u8) void {
        self.fg = fg;
        self.bg = bg;
    }

    pub fn setOverflow(self: *Self, h: term.Term.HOverflow, v: term.Term.VOverflow) void {
        self.hv = h;
        self.vv = v;
    }

    pub fn enter(self: *Self) !void {
        try self.t.setClip(self.xmin, self.xmax, self.ymin, self.ymax);
        self.t.setFgColor(self.fg);
        self.t.setBgColor(self.bg);
        self.t.setHOverflow(self.hv);
        self.t.setVOverflow(self.vv);
        self.t.setCursor(self.cx, self.cy);
    }

    pub fn homeCursor(self: *Self) void {
        self.cx = self.xmin;
        self.cy = self.ymin;
    }

    pub fn leave(self: *Self) void {
        self.t.getCursor(&self.cx, &self.cy);
        self.t.resetClip();
    }
};

pub fn printAt(t: *term.Term, x: u16, y: u16, a: term.Term.Attribute, s: []const u8) !void {
    t.setAttribute(a);
    defer t.clearAttribute(a);
    try t.writeStringAt(x, y, s);
}

pub fn drawScrollWindow(t: *term.Term) !void {
    const data: *const [63:0]u8 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:";
    var cnt: u16 = 0;
    while (cnt < 256) : (cnt += 1) {
        t.writeChar(data[cnt % 63]);
    }
}

pub fn drawColorBox(t: *term.Term) void {
    t.clearAllAttributes();
    t.setFgColor(0);
    var y: u8 = 0;
    while (y < 16) : (y += 1) {
        var x: u8 = 0;
        while (x < 16) : (x += 1) {
            t.setBgColor((y << 4) | x);
            t.writeCharAt(x * 2, y, 0);
            t.writeCharAt(x * 2 + 1, y, ' ');
        }
    }
}

pub fn drawStyledText(t: *term.Term) !void {
    t.clearAllAttributes();
    try t.writeStringAt(34, 0, "Standard");
    try printAt(t, 34, 2, .Standout, "Standout");
    try printAt(t, 34, 4, .Underline, "Underline");
    try printAt(t, 34, 6, .Reverse, "Reverse");
    try printAt(t, 34, 8, .Blink, "Blink");
    try printAt(t, 34, 10, .Dim, "Dim");
    try printAt(t, 34, 12, .Bold, "Bold");
    try printAt(t, 34, 14, .Italic, "Italic");
}

var msgWin: Window = undefined;
var scrollWin: Window = undefined;

pub fn redraw(t: *term.Term) !void {
    t.clearAllAttributes();
    t.clearScreen();
    drawColorBox(t);
    try drawStyledText(t);

    try scrollWin.enter();
    t.homeCursor();
    t.clear();
    try drawScrollWindow(t);
    scrollWin.leave();

    try msgWin.enter();
    t.clear();
    msgWin.leave();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var tty = try term.Term.init(gpa.allocator());
    defer tty.deinit();

    try tty.hideCursor();

    scrollWin = Window.init(&tty, 50, 65, 0, 15);
    scrollWin.setOverflow(.wrap, .scroll);
    scrollWin.setColors(6, 1);

    msgWin = Window.init(&tty, 1, tty.width - 2, 17, 24);
    msgWin.setOverflow(.wrap, .scroll);
    msgWin.setColors(7, 4);

    try redraw(&tty);

    var escape_once = false;
    while (true) {
        const evt = try tty.pollEvent();

        if (evt == .key) {
            if (evt.key.key == .Escape) {
                if (escape_once) {
                    break;
                } else {
                    try msgWin.enter();
                    defer msgWin.leave();
                    try tty.writeString("Escape pressed, once more to exit...\n");
                    escape_once = true;
                }
            } else {
                escape_once = false;
                switch (evt.key.key) {
                    .Up => {
                        try scrollWin.enter();
                        defer scrollWin.leave();
                        try tty.scroll(.up, 1);
                    },
                    .Down => {
                        try scrollWin.enter();
                        defer scrollWin.leave();
                        try tty.scroll(.down, 1);
                    },
                    .Left => {
                        try scrollWin.enter();
                        defer scrollWin.leave();
                        try tty.scroll(.left, 1);
                    },
                    .Right => {
                        try scrollWin.enter();
                        defer scrollWin.leave();
                        try tty.scroll(.right, 1);
                    },
                    .Character => {
                        if (evt.key.char == 'r') {
                            try scrollWin.enter();
                            defer scrollWin.leave();
                            try drawScrollWindow(&tty);
                        } else {
                            try msgWin.enter();
                            defer msgWin.leave();
                            try std.fmt.format(tty.writer(), "{any}\n", .{evt});
                        }
                    },
                    else => {
                        try msgWin.enter();
                        defer msgWin.leave();
                        try std.fmt.format(tty.writer(), "{any}\n", .{evt});
                    },
                }
            }
        } else if (evt == .resize) {
            msgWin.resize(1, evt.resize.w - 2, 17, 24);
            try redraw(&tty);
            try msgWin.enter();
            try std.fmt.format(tty.writer(), "{any}\n", .{evt});
            msgWin.leave();
        }

        try tty.update();
    }
}
