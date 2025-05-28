# term

term is a library that provides terminal handling for zig. It includes termios and terminfo capabilities on unix like platforms, plus a termbox like interface to the terminal.

The Term struct implements the termbox like interface, and it is planned to support windows, linux and other unix-like platforms in the future. But currently only linux is supported.

## Installation

As this is a library to be used with zig, you can install it into your projects source code by using

    git submodule add https://codeberg.org/gnarz/term term

For v0.12, this will be different, as the module system will be used. For the time being, it is not. `zig build` works on both zig v0.11 and zig master, also with test or run arguments.`zig build docs` only works on v0.11.

## Use

Either add term as a module to your build.zig and do

    const term = @import("term");

or just do

    const term = @import("term/term.zig");

then, term.ios contains the termios stuff, term.info contains the Terminfo struct that handles terminfo data, and term contains the Term struct that provides the simplified terminal interface.

## Documentation

You can generate the documentation by calling

    zig build docs

However, as zig's documentation generator is experimental and seems to miss some of the functions, there is also the bit that follows here, and you may also have to refer to the source code.

## term

### Enums

- Key are the names of the recognized keys, that do not return a printable value. The keys are available in plain, shift, control and control+shift variants. See term/key.zig for a list.

### Structs

- struct Term 
  + enum Attribute are the attributes to be used with the set/clearAttribute functions. They are: Standout, Underline, Reverse, Blink, Dim, Bold, Italic
  + field width: u16, height: u16  
    size of the terminal, updated on resize
  + field colors: i32  
    maximum number of colors the terminal can handle
  + `pub fn init(allocator: std.mem.Allocator) !Term`  
    initializes the library, switches the terminal to the alternate screen buffer and clears the screen
  + `pub fn deinit(self: *Term) void`  
    finalizes use of the library, releases any allocated memory and resets the terminal to normal mode.
  + `pub fn hasKey(self: Term, key: Key) bool`  
    returns true if the terminal can return the key, false if not
  + `pub fn hasAttr(self: Term, a: Attribute) bool`  
    return true if the terminal has this attribute, false if not.
  + `pub fn setCursor(self: *Term, x: i32, y: i32) !void`  
    places the cursor at coordinates x,y on the terminal. The top-left corner is 0, 0
  + `pub fn homeCursor(self: *Term) void`  
    places the cursor in the top left cormer of the current clip rectangle
  + `pub fn getCursor(self: Term, x: *u16, y: *u16) void`  
    returns the current cursor position in x.*, y.*
  + `pub fn showCursor(self: Term) !void`  
    unhides the cursor
  + `pub fn hideCursor(self: Term) !void`  
    hides the cursor
  + `pub fn setClip(self: *Term, xmin: u16, xmax: u16, ymin: u16, ymax: u16) !void`  
    sets the clip rectangle. min and max coordinates are inclusive.
  + `pub fn resetClip(self: *Term) void`  
    resets the clip rectangle for the terminal to cover tne entire terminal screen.
  + `pub fn setHOverflow(self: *Term, v: HOverflow) void`  
    sets the horizintal overflow discipline, either .clip or .wrap
  + `pub fn setVOverflow(self: *Term, v: VOverflow) void`  
    sets the vertical overflow discipline, either .clip or .scroll
  + `pub fn clearScreen(self: Term) !void`  
    resets the clip rectangle, clears the entire screen to the current background color, and sets the cursor to position 0, 0.
  + `pub fn clear(self: Term) void`  
    clears the clip rectangle to the current background color
  + `pub fn writeCharAt(self: *Term, x: i32, y: i32, char: u21) !void`  
    places the character char on the terminal at position x, y
  + `pub fn writeChar(self: *Term, char: u21) void`  
    write a character at cursor pos, advancing cursor.This also handles the overflow disciplines. WriteChar() implements the \r and \n control codes, \r returning the cursor to the leftmost position of the current clip rectangle on the current line, and \n moving the cursor to the leftmost position of the clippling rectangle on the next line.
  + `pub fn writeStringAt(self: Term, x: u16, y: u16, s: []const u8) !void`  
    write a string to the screen at position x, y
  + `pub fn writeString(self: *Term, s: []const u8) !void`  
    write a string at cursor pos, advancing cursor and honoring the overflow disciplines
  + `pub fn writer(self: *Term) Writer`  
    returns a writer for the terminal that uses writeString() to output the data
  + `pub fn setFgColor(self: *Term, fg: u8) !void`  
    sets the current foreground color. What values fg may take depends on the number of colors your terminal can display.
  + `pub fn setBgColor(self: *Term, bg: u8) !void`  
    sets the current background color. What values bg may take depends on the number of colors your terminal can display.
  + `pub fn setAttribute(self: *Term, attr: Attribute) !void`  
    sets an attribute for the following text.
  + `pub fn clearAttribute(self: *Term, attr: Attribute) !void`  
    clears an attribute for the following text
  + `pub fn clearAllAttributes(self: *Term) !void`  
    clears all text attributes and resets the colors to their default values
  + `pub fn scroll(self: Term, dir: Direction, amount: u16) !void`  
    scrolls the contents of the clip rectangle in the desired direction
  + `pub fn pollEventTimeout(self: *Term, tmout: i32) !Event`  
    poll a single event from the terminal, or time out after tmout milliseconds. If tmout is -1, this behaves just like pollEvent(). If tmout is 0, this returns immediately with a noEvent, if no event is pending. Otherwise it waits for tmout milliseconds for an event, which it returns if one occurs, and otherwise returns noEvent. See the Event struct for what can be returned here.
  + `pub fn pollEvent(self: *Term) !Event`  
    poll a single event from the terminal, blocking until an event is available. See the Event struct for what can be returned here.
- struct Event
  + Event == .none -> no event. Only returned by pollEventTimeout()
  + Event == .key -> Event.key.key for special keys, if Event.key.key == .Character then Event.key.char is the value
  + Event == .resize -> Event.resize { .w = width, .h = height }

### Clipping

the Term struct maintains a clip rectangle. After creation and after calls to resetClip(), the clip rectangle contains the entire terminal screen, but you can change it using setClip(). Clipping works on all write* functions, and also on clear(). For the writeChar(), writeString() functions and the Writer returned by writer(), an overflow discipline can be set. If the written text is outside of the clip rectangle, this discipline will be honored. Horizontal disciplines are clip (just cut the text) or wrap (wrap around to the next line). Vertical disciplines are clip and scroll (scroll the clip rectangle up until the new text is visible). The writeCharAt() and writeStringAt() functions always clip the output data.

The cursor position is not bound by the clip rectangle.

### Example

    ...
    const allocator = ...; // some allocator
    var term = Term.init(allocator);
    defer term.deinit();

    try term.setColor(7, 0);
    try term.setAttribute(.Italic);
    try term.setCell(10, 10, 'X');
    try term.setCellUtf8(12, 10, "Ö");

    while (true) {
      var evt = try term.pollEvent();

      if (needs_to_terminate) break;

      if (evt == .key) 
      // do something...

      term.update();
    }

## term.ios

check the man pages for the c functions for details. The constants needed for the functions are available from std.os.system.

### Structs

- struct winsize is used by term.ios.tcgetwinsize()/term.ios.tcsetwinsize(). Fields are as for the C equivalent.
- other data structures are used from std.os and std.os.system

### Errors

- all error returning functions return a term.ios.TermiosError

### Functions

These are the same as from C, so refer to man 3 termios.

- `pub fn tcgetattr(handle: fd_t) TermiosGetError!termios`  
- `pub fn tcsetattr(handle: fd_t, optional_action: TCSA, termios_p: termios) TermiosSetError!void`  
  (these first 2 functions are from std.os)
- `pub fn tcgetwinsize(fd: fd_t) TermiosError!winsize`  
- `pub fn tcsetwinsize(fd: fd_t, wsz: winsize) TermiosError!void`  
- `pub fn tcsendbreak(fd: fd_t, dur: i32) TermiosError!void`  
- `pub fn tcdrain(fd: fd_t) TermiosError!void`  
- `pub fn tcflow(fd: fd_t, action: i32) TermiosError!void`  
- `pub fn tcflush(fd: fd_t, queue: i32) TermiosError!void`  
- `pub fn tcgetsid(fd: fd_t) TermiosError!pid_t`  
- `pub fn cfmakeraw(tio: *termios) void`  
- `pub fn cfgetospeed(tio: termios) speed_t`  
- `pub fn cfgetispeed(tio: termios) speed_t`  
- `pub fn cfsetospeed(tio: *termios, speed: speed_t) !void`  
- `pub fn cfsetispeed(tio: *termios, speed: speed_t) !void`  

## term.info

This implements reading and querying of compiled terminfo files. Legacy and extended number formats are supported, as is the extended storage format. Terminfo data may be read from a file on disk or from a slice in memory.

Querying the predefined capabilities is done by their C name. The extended capabilities are referred to by their names, which are short and cryptic names. They have no long and friendly names. So the for example name for the shift-cursor-left key is Strings.key_sleft, as this is a predefined capability, but for shift-cursor-up it is Strings.kUP.

### Enums

- enum term.info.Booleans, term.info.Numbers, term.info.Strings are the names of the bool/number/string capabilities. Both predefined and extended capabilities are here.

### Structs

- struct Terminfo
    + `pub fn initFromMem(allocator: mem.Allocator, descr: []const u8) InitError!Terminfo`  
      initializes a Terminfo struct from a slice containing a compiled terminfo description.
    + `pub fn init(allocator: mem.Allocator, term: []const u8) InitError!Terminfo`  
      initializes a Terminfo struct from a file in the terminfo database
    + `pub fn deinit(self: *Terminfo) void`  
      call this when you're done with the Terminfo struct
    + `pub fn getBoolean(self: Terminfo, b: Booleans) bool`  
      get the value of a boolean capability from the terminfo description
    + `pub fn getNumber(self: Terminfo, n: Numbers) ?i32`  
      get the value of a number capability from the terminfo description
    + `pub fn getString(self: Terminfo, s: Strings) ?[]const u8`  
      get the value of a string capability from a terminfo description
    + `pub fn getInterpolatedString(self: *Terminfo, s: Strings, plist: anytype) !?[]const u8`  
      gets the value of a parameterized string from the terminfo description, instantiated by evaluating the string using he supplied parameters, and returning an allocated string that is owned by the caller.
    + `pub fn freeInterpolatedString(?[]const u8) void`  
      deallocates the return value of getInterpolatedString()
    + `pub fn repairAcsc(self: *Terminfo) void`  
      Convert an alternate-character-set string to canonical form: sorted and unique. The conversion is done in-place.
    + `pub fn decodeUser6(self: Terminfo, str: []const u8, x: *i32, y: *i32) usize`  
      Decode a string from the pattern specified in the user6 string capability. This is the terminal answer when querying the cursor position with the user7 string capability.

### Errors

- Terminfo.InitError

### Example

    ...
    const allocator = ...; // some allocator

    var terminal = std.os.getenv("TERM");
    if (terminal == null) return error.NOTTY;
    var ti = try term.Terminfo.init(allocator, terminal.?);
    defer ti.deinit();

    // these are just functions that return values or pointers into the Terminfo
    // struct's private memory
    var has_meta_key: bool = ti.getBoolean(.has_meta_key);
    var columns: i32 = ti.getNumber(.columns);
    var clear_screen: []const u8 = ti.getString(.clear_screen);

    // this returns a newly allocated string. There is a convenience function to
    // deallocate this string using the same allocator that was used to allocate it.
    var set_cursor: []const u8 = ti.getInterpolatedString(.cursor_address, .{y, x});
    defer ti.freeInterpolatedString(set_cursor);
    ...

## References

- https://www.man7.org/linux/man-pages/man5/terminfo.5.html
- https://www.man7.org/linux/man-pages/man5/term.5.html
- https://www.man7.org/linux/man-pages/man5/user_caps.5.html
- https://www.man7.org/linux/man-pages/man3/curs_terminfo.3x.html
- https://invisible-island.net/ncurses/terminfo.src.html#toc-_T_E_R_M_I_N_A_L__T_Y_P_E__D_E_S_C_R_I_P_T_I_O_N_S__S_O_U_R_C_E__F_I_L_E
- https://invisible-island.net/ncurses/ncurses.faq.html#modified_keys
- /usr/include/term.h
- https://github.com/termstandard/colors
