//! This is an implementation of the termios interface for zig. As the functions are
//! the same as from C, you can refer to man 2 termios for details. The main difference
//! is that error conditions are signalled by returning an error union, so that
//! functions that return only a status code in C will return TermiosError!void here.
//!
//! The constants for tcflag_t and speed_t are available from std.os.system

const std = @import("std");
const os = std.os;
const posix = std.posix;
const system = posix.system;

const fd_t = posix.fd_t;
const tcflag_t = posix.tcflag_t;
const speed_t = system.speed_t;
const pid_t = posix.pid_t;

pub const termios = posix.termios;

pub const winsize = packed struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

pub const TermiosError = error{
    InvalidValue,
    BadFileDescriptor,
    InaccessibleMemoryArea,
    NotATty,
} || posix.UnexpectedError;

fn checkerror(code: usize) !void {
    switch (system.E.init(code)) {
        .SUCCESS => return,
        .BADF => return error.BadFileDescriptor,
        .FAULT => return error.InaccessibleMemoryArea,
        .INVAL => return error.InvalidValue,
        .NOTTY => return error.NotATty,
        // other errors can be returned here?
        else => |err| return posix.unexpectedErrno(err),
    }
}

// tcgetattr(handle: fd_t) TermiosGetError!termios
pub const tcgetattr = posix.tcgetattr;
//pub fn tcsetattr(handle: fd_t, optional_action: TCSA, termios_p: termios) TermiosSetError!void
pub const tcsetattr = posix.tcsetattr;

pub fn tcgetwinsize(fd: fd_t) TermiosError!winsize {
    var wsz: winsize = undefined;
    try checkerror(system.ioctl(fd, system.T.IOCGWINSZ, @intFromPtr(&wsz)));
    return wsz;
}

pub fn tcsetwinsize(fd: fd_t, wsz: winsize) TermiosError!void {
    try checkerror(system.ioctl(fd, system.T.IOCSWINSZ, @intFromPtr(&wsz)));
}

pub fn tcsendbreak(fd: fd_t, dur: i32) TermiosError!void {
    try checkerror(system.ioctl(fd, system.T.CSBRK, @as(u64, @intCast(dur))));
}

pub fn tcdrain(fd: fd_t) TermiosError!void {
    try checkerror(system.ioctl(fd, system.T.CSBRK, 1));
}

pub fn tcflow(fd: fd_t, action: i32) TermiosError!void {
    try checkerror(system.ioctl(fd, system.T.CXONC, @as(u64, @intCast(action))));
}

pub fn tcflush(fd: fd_t, queue: i32) TermiosError!void {
    try checkerror(system.ioctl(fd, system.T.CFLSH, @as(u64, @intCast(queue))));
}

pub fn tcgetsid(fd: fd_t) TermiosError!pid_t {
    var sid: pid_t = 0;
    try checkerror(system.ioctl(fd, system.T.IOCGSID, @intFromPtr(&sid)));
    return sid;
}

pub fn cfmakeraw(tio: *termios) void {
    tio.iflag.BRKINT = false;
    tio.iflag.PARMRK = false;
    tio.iflag.ISTRIP = false;
    tio.iflag.INLCR = false;
    tio.iflag.IGNCR = false;
    tio.iflag.IXON = false;

    tio.iflag.IGNBRK = false;

    tio.oflag.OPOST = false;
    tio.lflag.ECHO = false;
    tio.lflag.ECHONL = false;
    tio.lflag.ICANON = false;
    tio.lflag.ISIG = false;
    tio.lflag.IEXTEN = false;
    tio.cflag.PARENB = false;
    tio.cflag.CSIZE = .CS8;
    tio.cc[@intFromEnum(system.V.MIN)] = 1;
    tio.cc[@intFromEnum(system.V.TIME)] = 1;
}

pub fn cfgetospeed(tio: termios) speed_t {
    return tio.ospeed;
}

pub fn cfgetispeed(tio: termios) speed_t {
    return tio.ispeed;
}

pub fn cfsetospeed(tio: *termios, speed: speed_t) !void {
    tio.ospeed = speed;
}

pub fn cfsetispeed(tio: *termios, speed: speed_t) !void {
    tio.ispeed = speed;
}

pub const cfsetspeed = cfsetospeed;

test "basic compilation" {
    std.testing.refAllDecls(@This());
}
