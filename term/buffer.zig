const std = @import("std");

pub const TermBuffer = struct {
    pub const Cell = struct {
        char: u21 = ' ',
        changed: bool = true,
        attr: u8 = 0,
        fg: u8 = 0,
        bg: u8 = 0,
    };

    pub const Direction = enum {
        left,
        right,
        up,
        down,
    };

    allocator: std.mem.Allocator,
    w: u16,
    h: u16,
    clip: struct {
        xmin: u16,
        xmax: u16,
        ymin: u16,
        ymax: u16,
    },
    contents: []Cell,

    pub const ChangedCellIterator = struct {
        buffer: *const TermBuffer,
        x: u16,
        y: u16,
        ptr: u16,

        pub fn init(buffer: *const TermBuffer) ChangedCellIterator {
            return .{
                .buffer = buffer,
                .x = 0,
                .y = 0,
                .ptr = 0,
            };
        }

        fn inc(self: *ChangedCellIterator) void {
            if (self.ptr == self.buffer.contents.len) return;
            self.x += 1;
            if (self.x == self.buffer.w) {
                self.x = 0;
                self.y += 1;
            }
            self.ptr += 1;
        }

        pub fn next(self: *ChangedCellIterator, x: *u16, y: *u16) ?Cell {
            const buffer = self.buffer;
            if (self.ptr >= buffer.contents.len) return null;
            defer self.inc();
            x.* = self.x;
            y.* = self.y;
            while (self.ptr < buffer.contents.len) {
                if (buffer.contents[self.ptr].changed) {
                    buffer.contents[self.ptr].changed = false;
                    return buffer.contents[self.ptr];
                }
                self.inc();
                x.* = self.x;
                y.* = self.y;
            }
            return null;
        }
    };

    pub fn init(allocator: std.mem.Allocator, w: u16, h: u16) !TermBuffer {
        // TODO sanity check
        var empty = [0]Cell{};
        var self = TermBuffer{
            .allocator = allocator,
            .w = 0,
            .h = 0,
            .clip = undefined,
            .contents = &empty,
        };
        try self.resize(w, h);
        return self;
    }

    pub fn deinit(self: *TermBuffer) void {
        self.allocator.free(self.contents);
    }

    pub fn resize(self: *TermBuffer, w: u16, h: u16) !void {
        const size: u32 = @as(u32, w) * @as(u32, h);
        var mem = try self.allocator.alloc(Cell, size);
        @memset(mem, Cell{});
        if (self.contents.len != 0) {
            const minw = @min(self.w, w);
            const minh = @min(self.h, h);
            var orow: u32 = 0;
            var nrow: u32 = 0;

            var y: u16 = 0;
            while (y < minh) : (y += 1) {
                var x: u16 = 0;
                while (x < minw) : (x += 1) {
                    mem[nrow + x] = self.contents[orow + x];
                }
                orow += self.w;
                nrow += w;
            }
            self.allocator.free(self.contents);
        }
        self.contents = mem;
        self.w = w;
        self.h = h;
        self.resetClip();
    }

    pub fn clearAll(self: *TermBuffer, bgcol: u8) void {
        self.resetClip();
        self.clear(bgcol);
    }

    pub fn clear(self: TermBuffer, bgcol: u8) void {
        const EmptyCell = Cell{
            .bg = bgcol,
        };

        const xmin = self.clip.xmin;
        const xmax = self.clip.xmax;
        const ymin = self.clip.ymin;
        const ymax = self.clip.ymax;
        const clipw: u16 = xmax - xmin + 1;
        var ptr = ymin * self.w + xmin;
        var y: u16 = ymin;
        while (y <= ymax) : (y += 1) {
            @memset(self.contents[ptr .. ptr + clipw], EmptyCell);
            ptr += self.w;
        }
    }

    pub fn setCell(self: TermBuffer, x: u16, y: u16, cell: Cell) void {
        if (x < self.clip.xmin or x > self.clip.xmax or y < self.clip.ymin or y > self.clip.ymax) return;
        self.contents[y * self.w + x] = cell;
        self.contents[y * self.w + x].changed = true;
        if (cell.char < ' ') self.contents[y * self.w + x].char = ' ';
    }

    pub fn getCell(self: TermBuffer, x: u16, y: u16) !Cell {
        if (x >= self.w or y >= self.h) return error.OutOfRange;
        return self.contents[y * self.w + x];
    }

    pub fn setClip(self: *TermBuffer, xmin: u16, xmax: u16, ymin: u16, ymax: u16) !void {
        if (xmin > xmax or ymin > ymax) return error.InvalidParameterOrder;
        self.clip = .{
            .xmin = if (xmin < self.w) xmin else self.w,
            .xmax = if (xmax < self.w) xmax else self.w - 1,
            .ymin = if (ymin < self.h) ymin else self.h,
            .ymax = if (ymax < self.h) ymax else self.h - 1,
        };
    }

    pub fn resetClip(self: *TermBuffer) void {
        self.clip = .{
            .xmin = 0,
            .xmax = self.w - 1,
            .ymin = 0,
            .ymax = self.h - 1,
        };
    }

    // blit and fill are internal functions that assume that the parameter ranges have been checked
    // before calling
    fn blit(self: TermBuffer, xmin: u16, xmax: u16, ymin: u16, ymax: u16, x: u16, y: u16) void {
        const w: i32 = xmax - xmin;
        const h: i32 = ymax - ymin;
        var xs: i32 = xmin;
        var xe: i32 = xmax;
        var xd: i32 = x;
        var xo: i32 = 1;
        if (x > xmin) {
            xs = xmax;
            xe = xmin;
            xd = x + w;
            xo = -1;
        }
        var ys: i32 = ymin;
        var ye: i32 = ymax;
        var yd: i32 = y;
        var yo: i32 = 1;
        if (y > ymin) {
            ys = ymax;
            ye = ymin;
            yd = y + h;
            yo = -1;
        }
        var ry: i32 = ys;
        while (true) : (ry += yo) {
            var rx: i32 = xs;
            var rxd = xd;
            while (true) : (rx += xo) {
                self.contents[@as(u32, @intCast(yd * self.w + rxd))] = self.contents[@as(u32, @intCast(ry * self.w + rx))];
                self.contents[@as(u32, @intCast(yd * self.w + rxd))].changed = true;
                if (rx == xe) break;
                rxd += xo;
            }
            if (ry == ye) break;
            yd += yo;
        }
    }

    fn fill(self: TermBuffer, xmin: u16, xmax: u16, ymin: u16, ymax: u16, cell: Cell) void {
        var ccell = cell;
        ccell.changed = true;
        var y = ymin;
        while (y <= ymax) : (y += 1) {
            var x = xmin;
            while (x <= xmax) : (x += 1) {
                self.contents[y * self.w + x] = ccell;
            }
        }
    }

    pub fn scroll(self: TermBuffer, dir: Direction, amount: u16, bgcol: u8) void {
        if (amount == 0) return;
        const xmin = self.clip.xmin;
        const xmax = self.clip.xmax;
        const ymin = self.clip.ymin;
        const ymax = self.clip.ymax;
        const w = xmax - xmin + 1;
        const h = ymax - ymin + 1;
        if ((dir == .left or dir == .right) and amount > w) return self.clear(bgcol);
        if ((dir == .up or dir == .down) and amount > h) return self.clear(bgcol);
        switch (dir) {
            .up => {
                self.blit(self.clip.xmin, self.clip.xmax, self.clip.ymin + amount, self.clip.ymax, self.clip.xmin, self.clip.ymin);
                self.fill(self.clip.xmin, self.clip.xmax, self.clip.ymax - amount + 1, self.clip.ymax, Cell{ .bg = bgcol });
            },
            .down => {
                self.blit(self.clip.xmin, self.clip.xmax, self.clip.ymin, self.clip.ymax - amount, self.clip.xmin, self.clip.ymin + amount);
                self.fill(self.clip.xmin, self.clip.xmax, self.clip.ymin, self.clip.ymin + amount - 1, Cell{ .bg = bgcol });
            },
            .left => {
                self.blit(self.clip.xmin + amount, self.clip.xmax, self.clip.ymin, self.clip.ymax, self.clip.xmin, self.clip.ymin);
                self.fill(self.clip.xmax - amount + 1, self.clip.xmax, self.clip.ymin, self.clip.ymax, Cell{ .bg = bgcol });
            },
            .right => {
                self.blit(self.clip.xmin, self.clip.xmax - amount, self.clip.ymin, self.clip.ymax, self.clip.xmin + amount, self.clip.ymin);
                self.fill(self.clip.xmin, self.clip.xmin + amount - 1, self.clip.ymin, self.clip.ymax, Cell{ .bg = bgcol });
            },
        }
    }

    pub fn invalidate(self: TermBuffer) void {
        for (self.contents) |*cell| cell.changed = true;
    }

    pub fn changedCellIterator(self: *TermBuffer) ChangedCellIterator {
        return ChangedCellIterator.init(self);
    }
};

test "basic compilation" {
    @import("std").testing.refAllDecls(@This());
    @import("std").testing.refAllDecls(TermBuffer);
}
