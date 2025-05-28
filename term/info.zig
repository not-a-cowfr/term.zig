//! This is an interface to the terminfo database for zig. It offers a type safe
//! interface to the predefined capabilities.
//! All numbers handled by this interface are i32, even those returned from legacy
//! format terminfo database files.
//! For details on the capabilities, check the terminfo(5) manpage.

const std = @import("std");
const fs = std.fs;
const os = std.os;
const getEnvVar = std.process.getEnvVarOwned;
const mem = std.mem;

const ParamEvaluator = @import("param.zig").ParamEvaluator;

/// names of all the boolean capabilities, both predefined and extended.
pub const Booleans = enum(u16) {
    auto_left_margin,
    auto_right_margin,
    no_esc_ctlc,
    ceol_standout_glitch,
    eat_newline_glitch,
    erase_overstrike,
    generic_type,
    hard_copy,
    has_meta_key,
    has_status_line,
    insert_null_glitch,
    memory_above,
    memory_below,
    move_insert_mode,
    move_standout_mode,
    over_strike,
    status_line_esc_ok,
    dest_tabs_magic_smso,
    tilde_glitch,
    transparent_underline,
    xon_xoff,
    needs_xon_xoff,
    prtr_silent,
    hard_cursor,
    non_rev_rmcup,
    no_pad_char,
    non_dest_scroll_region,
    can_change,
    back_color_erase,
    hue_lightness_saturation,
    col_addr_glitch,
    cr_cancels_micro_mode,
    has_print_wheel,
    row_addr_glitch,
    semi_auto_right_margin,
    cpi_changes_res,
    lpi_changes_res,
    backspaces_with_bs,
    crt_no_scrolling,
    no_correctly_working_cr,
    gnu_has_meta_key,
    linefeed_is_newline,
    has_hardware_tabs,
    return_does_clr_eol,

    // extended parameters follow

    AX = chksum("AX"),
    RGB = chksum("RGB"),
    XT = chksum("XT"),
};

/// names of all the number capabilities, both predefined and extended.
pub const Numbers = enum(u16) {
    columns,
    init_tabs,
    lines,
    lines_of_memory,
    magic_cookie_glitch,
    padding_baud_rate,
    virtual_terminal,
    width_status_line,
    num_labels,
    label_height,
    label_width,
    max_attributes,
    maximum_windows,
    max_colors,
    max_pairs,
    no_color_video,
    buffer_capacity,
    dot_vert_spacing,
    dot_horz_spacing,
    max_micro_address,
    max_micro_jump,
    micro_col_size,
    micro_line_size,
    number_of_pins,
    output_res_char,
    output_res_line,
    output_res_horz_inch,
    output_res_vert_inch,
    print_rate,
    wide_char_size,
    buttons,
    bit_image_entwining,
    bit_image_type,
    magic_cookie_glitch_ul,
    carriage_return_delay,
    new_line_delay,
    backspace_delay,
    horizontal_tab_delay,
    number_of_function_keys,

    // extended parameters follow
    RGB = chksum("RGB"),
    U8 = chksum("U8"),
};

/// names of all the string cpabilities, both predefined and extended.
pub const Strings = enum(u16) {
    back_tab,
    bell,
    carriage_return,
    change_scroll_region,
    clear_all_tabs,
    clear_screen,
    clr_eol,
    clr_eos,
    column_address,
    command_character,
    cursor_address,
    cursor_down,
    cursor_home,
    cursor_invisible,
    cursor_left,
    cursor_mem_address,
    cursor_normal,
    cursor_right,
    cursor_to_ll,
    cursor_up,
    cursor_visible,
    delete_character,
    delete_line,
    dis_status_line,
    down_half_line,
    enter_alt_charset_mode,
    enter_blink_mode,
    enter_bold_mode,
    enter_ca_mode,
    enter_delete_mode,
    enter_dim_mode,
    enter_insert_mode,
    enter_secure_mode,
    enter_protected_mode,
    enter_reverse_mode,
    enter_standout_mode,
    enter_underline_mode,
    erase_chars,
    exit_alt_charset_mode,
    exit_attribute_mode,
    exit_ca_mode,
    exit_delete_mode,
    exit_insert_mode,
    exit_standout_mode,
    exit_underline_mode,
    flash_screen,
    form_feed,
    from_status_line,
    init_1string,
    init_2string,
    init_3string,
    init_file,
    insert_character,
    insert_line,
    insert_padding,
    key_backspace,
    key_catab,
    key_clear,
    key_ctab,
    key_dc,
    key_dl,
    key_down,
    key_eic,
    key_eol,
    key_eos,
    key_f0,
    key_f1,
    key_f10,
    key_f2,
    key_f3,
    key_f4,
    key_f5,
    key_f6,
    key_f7,
    key_f8,
    key_f9,
    key_home,
    key_ic,
    key_il,
    key_left,
    key_ll,
    key_npage,
    key_ppage,
    key_right,
    key_sf,
    key_sr,
    key_stab,
    key_up,
    keypad_local,
    keypad_xmit,
    lab_f0,
    lab_f1,
    lab_f10,
    lab_f2,
    lab_f3,
    lab_f4,
    lab_f5,
    lab_f6,
    lab_f7,
    lab_f8,
    lab_f9,
    meta_off,
    meta_on,
    newline,
    pad_char,
    parm_dch,
    parm_delete_line,
    parm_down_cursor,
    parm_ich,
    parm_index,
    parm_insert_line,
    parm_left_cursor,
    parm_right_cursor,
    parm_rindex,
    parm_up_cursor,
    pkey_key,
    pkey_local,
    pkey_xmit,
    print_screen,
    prtr_off,
    prtr_on,
    repeat_char,
    reset_1string,
    reset_2string,
    reset_3string,
    reset_file,
    restore_cursor,
    row_address,
    save_cursor,
    scroll_forward,
    scroll_reverse,
    set_attributes,
    set_tab,
    set_window,
    tab,
    to_status_line,
    underline_char,
    up_half_line,
    init_prog,
    key_a1,
    key_a3,
    key_b2,
    key_c1,
    key_c3,
    prtr_non,
    char_padding,
    acs_chars,
    plab_norm,
    key_btab,
    enter_xon_mode,
    exit_xon_mode,
    enter_am_mode,
    exit_am_mode,
    xon_character,
    xoff_character,
    ena_acs,
    label_on,
    label_off,
    key_beg,
    key_cancel,
    key_close,
    key_command,
    key_copy,
    key_create,
    key_end,
    key_enter,
    key_exit,
    key_find,
    key_help,
    key_mark,
    key_message,
    key_move,
    key_next,
    key_open,
    key_options,
    key_previous,
    key_print,
    key_redo,
    key_reference,
    key_refresh,
    key_replace,
    key_restart,
    key_resume,
    key_save,
    key_suspend,
    key_undo,
    key_sbeg,
    key_scancel,
    key_scommand,
    key_scopy,
    key_screate,
    key_sdc,
    key_sdl,
    key_select,
    key_send,
    key_seol,
    key_sexit,
    key_sfind,
    key_shelp,
    key_shome,
    key_sic,
    key_sleft,
    key_smessage,
    key_smove,
    key_snext,
    key_soptions,
    key_sprevious,
    key_sprint,
    key_sredo,
    key_sreplace,
    key_sright,
    key_srsume,
    key_ssave,
    key_ssuspend,
    key_sundo,
    req_for_input,
    key_f11,
    key_f12,
    key_f13,
    key_f14,
    key_f15,
    key_f16,
    key_f17,
    key_f18,
    key_f19,
    key_f20,
    key_f21,
    key_f22,
    key_f23,
    key_f24,
    key_f25,
    key_f26,
    key_f27,
    key_f28,
    key_f29,
    key_f30,
    key_f31,
    key_f32,
    key_f33,
    key_f34,
    key_f35,
    key_f36,
    key_f37,
    key_f38,
    key_f39,
    key_f40,
    key_f41,
    key_f42,
    key_f43,
    key_f44,
    key_f45,
    key_f46,
    key_f47,
    key_f48,
    key_f49,
    key_f50,
    key_f51,
    key_f52,
    key_f53,
    key_f54,
    key_f55,
    key_f56,
    key_f57,
    key_f58,
    key_f59,
    key_f60,
    key_f61,
    key_f62,
    key_f63,
    clr_bol,
    clear_margins,
    set_left_margin,
    set_right_margin,
    label_format,
    set_clock,
    display_clock,
    remove_clock,
    create_window,
    goto_window,
    hangup,
    dial_phone,
    quick_dial,
    tone,
    pulse,
    flash_hook,
    fixed_pause,
    wait_tone,
    user0,
    user1,
    user2,
    user3,
    user4,
    user5,
    user6,
    user7,
    user8,
    user9,
    orig_pair,
    orig_colors,
    initialize_color,
    initialize_pair,
    set_color_pair,
    set_foreground,
    set_background,
    change_char_pitch,
    change_line_pitch,
    change_res_horz,
    change_res_vert,
    define_char,
    enter_doublewide_mode,
    enter_draft_quality,
    enter_italics_mode,
    enter_leftward_mode,
    enter_micro_mode,
    enter_near_letter_quality,
    enter_normal_quality,
    enter_shadow_mode,
    enter_subscript_mode,
    enter_superscript_mode,
    enter_upward_mode,
    exit_doublewide_mode,
    exit_italics_mode,
    exit_leftward_mode,
    exit_micro_mode,
    exit_shadow_mode,
    exit_subscript_mode,
    exit_superscript_mode,
    exit_upward_mode,
    micro_column_address,
    micro_down,
    micro_left,
    micro_right,
    micro_row_address,
    micro_up,
    order_of_pins,
    parm_down_micro,
    parm_left_micro,
    parm_right_micro,
    parm_up_micro,
    select_char_set,
    set_bottom_margin,
    set_bottom_margin_parm,
    set_left_margin_parm,
    set_right_margin_parm,
    set_top_margin,
    set_top_margin_parm,
    start_bit_image,
    start_char_set_def,
    stop_bit_image,
    stop_char_set_def,
    subscript_characters,
    superscript_characters,
    these_cause_cr,
    zero_motion,
    char_set_names,
    key_mouse,
    mouse_info,
    req_mouse_pos,
    get_mouse,
    set_a_foreground,
    set_a_background,
    pkey_plab,
    device_type,
    code_set_init,
    set0_des_seq,
    set1_des_seq,
    set2_des_seq,
    set3_des_seq,
    set_lr_margin,
    set_tb_margin,
    bit_image_repeat,
    bit_image_newline,
    bit_image_carriage_return,
    color_names,
    define_bit_image_region,
    end_bit_image_region,
    set_color_band,
    set_page_length,
    display_pc_char,
    enter_pc_charset_mode,
    exit_pc_charset_mode,
    enter_scancode_mode,
    exit_scancode_mode,
    pc_term_options,
    scancode_escape,
    alt_scancode_esc,
    enter_horizontal_hl_mode,
    enter_left_hl_mode,
    enter_low_hl_mode,
    enter_right_hl_mode,
    enter_top_hl_mode,
    enter_vertical_hl_mode,
    set_a_attributes,
    set_pglen_inch,
    termcap_init2,
    termcap_reset,
    linefeed_if_not_lf,
    backspace_if_not_bs,
    other_non_function_keys,
    arrow_key_map,
    acs_ulcorner,
    acs_llcorner,
    acs_urcorner,
    acs_lrcorner,
    acs_ltee,
    acs_rtee,
    acs_btee,
    acs_ttee,
    acs_hline,
    acs_vline,
    acs_plus,
    memory_lock,
    memory_unlock,
    box_chars_1,

    // extended parameters follow

    Cr = chksum("Cr"),
    Cs = chksum("Cs"),
    E0 = chksum("E0"),
    E3 = chksum("E3"),
    kDC = chksum("kDC"),
    kDC10 = chksum("kDC10"),
    kDC11 = chksum("kDC11"),
    kDC12 = chksum("kDC12"),
    kDC13 = chksum("kDC13"),
    kDC14 = chksum("kDC14"),
    kDC15 = chksum("kDC15"),
    kDC16 = chksum("kDC16"),
    kDC3 = chksum("kDC3"),
    kDC4 = chksum("kDC4"),
    kDC5 = chksum("kDC5"),
    kDC6 = chksum("kDC6"),
    kDC7 = chksum("kDC7"),
    kDC8 = chksum("kDC8"),
    kDC9 = chksum("kDC9"),
    kDN = chksum("kDN"),
    kDN10 = chksum("kDN10"),
    kDN11 = chksum("kDN11"),
    kDN12 = chksum("kDN12"),
    kDN13 = chksum("kDN13"),
    kDN14 = chksum("kDN14"),
    kDN15 = chksum("kDN15"),
    kDN16 = chksum("kDN16"),
    kDN3 = chksum("kDN3"),
    kDN4 = chksum("kDN4"),
    kDN5 = chksum("kDN5"),
    kDN6 = chksum("kDN6"),
    kDN7 = chksum("kDN7"),
    kDN8 = chksum("kDN8"),
    kDN9 = chksum("kDN9"),
    kEND = chksum("kEND"),
    kEND10 = chksum("kEND10"),
    kEND11 = chksum("kEND11"),
    kEND12 = chksum("kEND12"),
    kEND13 = chksum("kEND13"),
    kEND14 = chksum("kEND14"),
    kEND15 = chksum("kEND15"),
    kEND16 = chksum("kEND16"),
    kEND3 = chksum("kEND3"),
    kEND4 = chksum("kEND4"),
    kEND5 = chksum("kEND5"),
    kEND6 = chksum("kEND6"),
    kEND7 = chksum("kEND7"),
    kEND8 = chksum("kEND8"),
    kEND9 = chksum("kEND9"),
    kHOM = chksum("kHOM"),
    kHOM10 = chksum("kHOM10"),
    kHOM11 = chksum("kHOM11"),
    kHOM12 = chksum("kHOM12"),
    kHOM13 = chksum("kHOM13"),
    kHOM14 = chksum("kHOM14"),
    kHOM15 = chksum("kHOM15"),
    kHOM16 = chksum("kHOM16"),
    kHOM3 = chksum("kHOM3"),
    kHOM4 = chksum("kHOM4"),
    kHOM5 = chksum("kHOM5"),
    kHOM6 = chksum("kHOM6"),
    kHOM7 = chksum("kHOM7"),
    kHOM8 = chksum("kHOM8"),
    kHOM9 = chksum("kHOM9"),
    kIC = chksum("kIC"),
    kIC10 = chksum("kIC10"),
    kIC11 = chksum("kIC11"),
    kIC12 = chksum("kIC12"),
    kIC13 = chksum("kIC13"),
    kIC14 = chksum("kIC14"),
    kIC15 = chksum("kIC15"),
    kIC16 = chksum("kIC16"),
    kIC3 = chksum("kIC3"),
    kIC4 = chksum("kIC4"),
    kIC5 = chksum("kIC5"),
    kIC6 = chksum("kIC6"),
    kIC7 = chksum("kIC7"),
    kIC8 = chksum("kIC8"),
    kIC9 = chksum("kIC9"),
    kLFT = chksum("kLFT"),
    kLFT10 = chksum("kLFT10"),
    kLFT11 = chksum("kLFT11"),
    kLFT12 = chksum("kLFT12"),
    kLFT13 = chksum("kLFT13"),
    kLFT14 = chksum("kLFT14"),
    kLFT15 = chksum("kLFT15"),
    kLFT16 = chksum("kLFT16"),
    kLFT3 = chksum("kLFT3"),
    kLFT4 = chksum("kLFT4"),
    kLFT5 = chksum("kLFT5"),
    kLFT6 = chksum("kLFT6"),
    kLFT7 = chksum("kLFT7"),
    kLFT8 = chksum("kLFT8"),
    kLFT9 = chksum("kLFT9"),
    kNXT = chksum("kNXT"),
    kNXT10 = chksum("kNXT10"),
    kNXT11 = chksum("kNXT11"),
    kNXT12 = chksum("kNXT12"),
    kNXT13 = chksum("kNXT13"),
    kNXT14 = chksum("kNXT14"),
    kNXT15 = chksum("kNXT15"),
    kNXT16 = chksum("kNXT16"),
    kNXT3 = chksum("kNXT3"),
    kNXT4 = chksum("kNXT4"),
    kNXT5 = chksum("kNXT5"),
    kNXT6 = chksum("kNXT6"),
    kNXT7 = chksum("kNXT7"),
    kNXT8 = chksum("kNXT8"),
    kNXT9 = chksum("kNXT9"),
    kp5 = chksum("kp5"),
    kpADD = chksum("kpADD"),
    kpCMA = chksum("kpCMA"),
    kpDIV = chksum("kpDIV"),
    kpDOT = chksum("kpDOT"),
    kpMUL = chksum("kpMUL"),
    kPRV = chksum("kPRV"),
    kPRV10 = chksum("kPRV10"),
    kPRV11 = chksum("kPRV11"),
    kPRV12 = chksum("kPRV12"),
    kPRV13 = chksum("kPRV13"),
    kPRV14 = chksum("kPRV14"),
    kPRV15 = chksum("kPRV15"),
    kPRV16 = chksum("kPRV16"),
    kPRV3 = chksum("kPRV3"),
    kPRV4 = chksum("kPRV4"),
    kPRV5 = chksum("kPRV5"),
    kPRV6 = chksum("kPRV6"),
    kPRV7 = chksum("kPRV7"),
    kPRV8 = chksum("kPRV8"),
    kPRV9 = chksum("kPRV9"),
    kpSUB = chksum("kpSUB"),
    kpZRO = chksum("kpZRO"),
    kRIT = chksum("kRIT"),
    kRIT10 = chksum("kRIT10"),
    kRIT11 = chksum("kRIT11"),
    kRIT12 = chksum("kRIT12"),
    kRIT13 = chksum("kRIT13"),
    kRIT14 = chksum("kRIT14"),
    kRIT15 = chksum("kRIT15"),
    kRIT16 = chksum("kRIT16"),
    kRIT3 = chksum("kRIT3"),
    kRIT4 = chksum("kRIT4"),
    kRIT5 = chksum("kRIT5"),
    kRIT6 = chksum("kRIT6"),
    kRIT7 = chksum("kRIT7"),
    kRIT8 = chksum("kRIT8"),
    kRIT9 = chksum("kRIT9"),
    kU = chksum("kU"),
    kUP = chksum("kUP"),
    kUP10 = chksum("kUP10"),
    kUP11 = chksum("kUP11"),
    kUP12 = chksum("kUP12"),
    kUP13 = chksum("kUP13"),
    kUP14 = chksum("kUP14"),
    kUP15 = chksum("kUP15"),
    kUP3 = chksum("kUP3"),
    kUP4 = chksum("kUP4"),
    kUP5 = chksum("kUP5"),
    kUP6 = chksum("kUP6"),
    kUP7 = chksum("kUP7"),
    kUP8 = chksum("kUP8"),
    kUP9 = chksum("kUP9"),
    Ms = chksum("Ms"),
    RGB = chksum("RGB"),
    rmxx = chksum("rmxx"),
    Se = chksum("Se"),
    smxx = chksum("smxx"),
    Ss = chksum("Ss"),
    XM = chksum("XM"),
    xm = chksum("xm"),
};

// the start of the extended capabilities. This value was chosen because there are 414
// predefined string capabilities, and a lot less for the number or boolean capabilities,
// so there should be no collisions between predefined and extended capabilities.
const ExtendedParameterStart: u16 = 512;

// this is a slightly modified fletcher16 checksum function. It's purpose is to generate
// a unique 16-bit value for each extended capability name. The modification consists of
// adding bytes with the calue 31 to the checksum until it's value is larget than or
// equal to 512. This is to avoid collisions with the predefined capabilities. The value
// 31 was chosen because it is not part of the printable 8-bit charset, so it will not
// occur in any of the names, and also because it has the low 5 bits all set, and is
// prime. Note that for all extended names I have seen so far, this extension was not
// invoked. It is here only so that future extensions will not break the code. The
// algorithm is also rather simple, so it is quite possible that there may be collisions
// if a lot of extended capabilities are added. There is a check for this below, the
// "checksum collisions" test. If you add more extended capabilities, please also add them
// to the test.
fn chksum(data: []const u8) u16 {
    var sum1: u16 = 0;
    var sum2: u16 = 0;

    for (data) |c| {
        sum1 = (sum1 + c) % 255;
        sum2 = (sum2 + sum1) % 255;
    }

    // this is the modification
    while (((sum2 << 8) | sum1) < ExtendedParameterStart) {
        sum1 = (sum1 + 31) % 255;
        sum2 = (sum2 + sum1) % 255;
    }

    return (sum2 << 8) | sum1;
}

// iterates over unix style colon separated path lists
const PathListIterator = struct {
    path: []const u8,
    pos: u32,

    pub fn init(path: []const u8) PathListIterator {
        return PathListIterator{
            .path = path,
            .pos = 0,
        };
    }

    pub fn next(self: *PathListIterator) ?[]const u8 {
        const pos = self.pos;
        var end = pos;
        if (pos >= self.path.len) return null;
        while (end < self.path.len and self.path[end] != ':') end += 1;
        self.pos = end + 1;
        return self.path[pos..end];
    }
};

fn tryTerminfoOpen(path: []const u8, dir: []const u8, term: []const u8) fs.File.OpenError!?fs.File {
    var buf: [fs.max_path_bytes]u8 = undefined;
    const fullpath = (if (dir.len == 0)
        std.fmt.bufPrint(&buf, "{s}/{c}/{s}", .{ path, term[0], term })
    else
        std.fmt.bufPrint(&buf, "{s}/{s}/{c}/{s}", .{ path, dir, term[0], term })) catch return fs.File.OpenError.NameTooLong;
    return fs.openFileAbsolute(fullpath, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
}

// see https://www.man7.org/linux/man-pages/man5/terminfo.5.html
// section Fetching Compiled Descriptions
fn openTerminfoFile(allocator: std.mem.Allocator, term: []const u8) !fs.File {

    // special: if term contains a path separator, it is treated as a file name
    // instead of being searched along any of the following paths
    if (mem.indexOfScalar(u8, term, '/') != null) {
        return try fs.cwd().openFile(term, .{ .mode = .read_only });
    }

    var envv = try getEnvVar(allocator, "TERMINFO");
    if (try tryTerminfoOpen(envv, "", term)) |f| {
        return f;
    }

    envv = try getEnvVar(allocator, "TERMINFO_DIRS");
    var iter = PathListIterator.init(envv);
    while (iter.next()) |path| {
        var f: ?fs.File = null;
        if (path.len == 0) {
            f = try tryTerminfoOpen("/etc/terminfo", "", term);
        } else {
            f = try tryTerminfoOpen(path, "", term);
        }
        if (f != null) return f.?;
    }

    envv = try getEnvVar(allocator, "HOME");
    if (try tryTerminfoOpen(envv, ".terminfo", term)) |f| {
        return f;
    }

    if (try tryTerminfoOpen("/etc/terminfo", "", term)) |f| {
        return f;
    }

    if (try tryTerminfoOpen("/lib/terminfo", "", term)) |f| {
        return f;
    }

    if (try tryTerminfoOpen("/usr/share/terminfo", "", term)) |f| {
        return f;
    }

    return error.FileNotFound;
}

fn readI16(buf: []const u8, idx: u16) i16 {
    return @as(i16, buf[idx]) | (@as(i16, buf[idx + 1]) << 8);
}

fn readI32(buf: []const u8, idx: u16) i32 {
    return @as(i32, buf[idx]) | (@as(i32, buf[idx + 1]) << 8) | (@as(i32, buf[idx + 2]) << 16) | (@as(i32, buf[idx + 3]) << 24);
}

/// this represents the terminfo data for a terminal.
pub const Terminfo = struct {

    // struct for extended capabilities. They are all stored with their value as i32.
    const ExtCap = struct {
        hash: u16 = 0,
        value: union(enum) {
            boolean: bool,
            number: i32,
            string: u16,
        },
    };

    allocator: mem.Allocator,
    names: []const u8,
    booleans: []bool,
    numbers: []i32,
    strings: []i16,
    stable: []u8,
    extcaps: ?[]ExtCap = null,
    extstable: ?[]u8 = null,

    interpolator: *ParamEvaluator,

    pub const InitError = fs.File.OpenError || std.posix.ReadError || mem.Allocator.Error || std.process.GetEnvVarOwnedError || error{
        StreamTooLong,
        InvalidMagicNumber,
    };

    /// Initialize the Terminfo struct from a slice. The slice must contain a compiled
    /// terminfo description.
    pub fn initFromMem(allocator: mem.Allocator, descr: []const u8) InitError!Terminfo {
        var number_len: u16 = 2;
        const magic = readI16(descr, 0);
        if (magic == 0o1036) {
            number_len = 4;
        } else if (readI16(descr, 0) != 0o0432) {
            return error.InvalidMagicNumber;
        }

        // read header
        const namelen = @as(u16, @intCast(readI16(descr, 2)));
        const numbools = @as(u16, @intCast(readI16(descr, 4)));
        const numnums = @as(u16, @intCast(readI16(descr, 6)));
        const numstrs = @as(u16, @intCast(readI16(descr, 8)));
        const stlen = @as(u16, @intCast(readI16(descr, 10)));

        // TODO sanity check on header values

        var idx: u16 = 12; // data starts here
        var end = idx + namelen;

        const names = try allocator.alloc(u8, namelen - 1);
        errdefer allocator.free(names);
        @memcpy(names, descr[idx .. end - 1]);

        idx = end;
        end = idx + @as(u16, @intCast(numbools));
        var cnt: u16 = 0;
        var booleans = try allocator.alloc(bool, numbools);
        errdefer allocator.free(booleans);
        while (idx < end) : (idx += 1) {
            booleans[cnt] = if (descr[idx] == 0) false else true;
            cnt += 1;
        }

        // the numbers begin on an even position in the file
        idx = if (end & 1 == 1) end + 1 else end;
        cnt = 0;
        var numbers = try allocator.alloc(i32, numnums);
        errdefer allocator.free(numbers);
        while (cnt < numnums) : (cnt += 1) {
            if (number_len == 4) {
                numbers[cnt] = readI32(descr, idx);
            } else {
                numbers[cnt] = readI16(descr, idx);
            }
            idx += number_len;
        }

        end = idx + numstrs * 2;
        cnt = 0;
        var strings = try allocator.alloc(i16, numstrs);
        errdefer allocator.free(strings);
        while (idx < end) : (idx += 2) {
            strings[cnt] = readI16(descr, idx);
            cnt += 1;
        }

        end = idx + stlen;
        const stable = try allocator.alloc(u8, stlen);
        errdefer allocator.free(stable);
        @memcpy(stable, descr[idx..end]);

        const interpolator: *ParamEvaluator = try allocator.create(ParamEvaluator);
        errdefer allocator.destroy(interpolator);
        interpolator.* = ParamEvaluator.init(allocator);

        var res = Terminfo{
            .allocator = allocator,
            .names = names,
            .booleans = booleans,
            .numbers = numbers,
            .strings = strings,
            .stable = stable,
            .interpolator = interpolator,
        };

        // extended capabilities
        if (end < descr.len) {
            idx = end;
            if (idx & 1 != 0) idx += 1; // correct alignment
            const extbools = @as(u16, @intCast(readI16(descr, idx)));
            const extnums = @as(u16, @intCast(readI16(descr, idx + 2)));
            const extstrs = @as(u16, @intCast(readI16(descr, idx + 4)));
            const extnames = @as(u16, @intCast(readI16(descr, idx + 6))) - extstrs;
            //var extstlen = @intCast(u16, readI16(descr, idx + 8));
            idx += 10;
            const exttotal = extbools + extnums + extstrs;
            var extcaps = try allocator.alloc(ExtCap, exttotal);
            errdefer allocator.free(extcaps);
            // we read the extended capabilities all into one continuous array
            cnt = 0;
            end = idx + extbools;
            while (idx < end) : (idx += 1) {
                extcaps[cnt].value = .{ .boolean = if (readI16(descr, idx) == 0) false else true };
                cnt += 1;
            }

            idx = if (end & 1 == 1) end + 1 else end; // align for numbers
            end = idx + extnums * number_len;
            while (idx < end) : (idx += number_len) {
                if (number_len == 4) {
                    extcaps[cnt].value = .{ .number = readI32(descr, idx) };
                } else {
                    extcaps[cnt].value = .{ .number = readI16(descr, idx) };
                }
                cnt += 1;
            }

            end = idx + extstrs * 2;
            while (idx < end) : (idx += 2) {
                extcaps[cnt].value = .{ .string = @as(u16, @intCast(readI16(descr, idx))) };
                cnt += 1;
            }

            // extract ext string table
            const extstbase = idx + extnames * 2;
            var extstlen = @as(u16, @intCast(readI16(descr, idx - 2)));
            while (descr[extstbase + extstlen] != 0) extstlen += 1;
            extstlen += 1;
            const extstable = try allocator.alloc(u8, extstlen);
            errdefer allocator.free(extstable);
            @memcpy(extstable, descr[extstbase .. extstbase + extstlen]);

            // and then, starting from the first entry, we fix the names
            const extnamebase = extstbase + extstlen;
            cnt = 0;
            end = idx + extnames * 2;
            while (idx < end) : (idx += 2) {
                const nidx = @as(u16, @intCast(readI16(descr, idx)));
                var nend = nidx;
                while (descr[extnamebase + nend] != 0) nend += 1;
                const capname = descr[extnamebase + nidx .. extnamebase + nend];
                extcaps[cnt].hash = chksum(capname);
                cnt += 1;
            }

            res.extcaps = extcaps;
            res.extstable = extstable;
        }

        return res;
    }

    /// Initialize the Terminfo struct from a file. The file must contain a compiled
    /// terminfo description.
    /// If term is a plain terminal name, the description is searched for using the
    /// algorithm described in the terminfo(5) manpage. If term contains a '/'
    /// character, it is opened as a file relative to the cwd (i.e. using std.fs.cwd())
    pub fn init(allocator: mem.Allocator, term: []const u8) InitError!Terminfo {
        var f = try openTerminfoFile(allocator, term);
        defer f.close();
        const buf = try f.reader().readAllAlloc(allocator, 64 * 1024);
        defer allocator.free(buf);
        return Terminfo.initFromMem(allocator, buf);
    }

    /// Deinitialize the Terminfo struct. This must always be called when done with
    /// it, as it cleans up allocated resources.
    pub fn deinit(self: *Terminfo) void {
        self.allocator.free(self.names);
        self.allocator.free(self.booleans);
        self.allocator.free(self.numbers);
        self.allocator.free(self.strings);
        self.allocator.free(self.stable);
        if (self.extcaps != null) self.allocator.free(self.extcaps.?);
        if (self.extstable != null) self.allocator.free(self.extstable.?);
        self.interpolator.deinit();
        self.allocator.destroy(self.interpolator);
    }

    fn getExtendedCap(self: Terminfo, hash: u16) ?ExtCap {
        if (self.extcaps == null) return null;
        for (self.extcaps.?) |cap| {
            if (hash == cap.hash) return cap;
        }
        return null;
    }

    /// Return the value of a boolean capability. Queries for boolean capabilities
    /// that are not present in the terminfo description (either absent or cancelled)
    /// return false.
    pub fn getBoolean(self: Terminfo, b: Booleans) bool {
        const idx: u16 = @intFromEnum(b);
        if (idx < self.booleans.len) {
            return self.booleans[idx];
        } else if (idx >= ExtendedParameterStart) {
            if (self.getExtendedCap(idx)) |cap| {
                if (cap.value == .boolean) return cap.value.boolean;
            }
        }
        return false;
    }

    /// Return the value of a number capability. Even though numbers in the legacy
    /// storage format are 16-bit signed ints, we always return i32. Queries for
    /// number capabilities that are not present in the terminfo description (either
    /// absent or cancelled) return null.
    pub fn getNumber(self: Terminfo, n: Numbers) ?i32 {
        const idx: u16 = @intFromEnum(n);
        if (idx < self.numbers.len) {
            if (self.numbers[idx] < 0) return null;
            return if (self.numbers[idx] < 0) null else self.numbers[idx];
        } else if (idx >= ExtendedParameterStart) {
            if (self.getExtendedCap(idx)) |cap| {
                if (cap.value == .number) return cap.value.number;
            }
        }
        return null;
    }

    /// Return the value of a string capability. The returned slice points into
    /// Terminfo-owned memory and must not be free'd. Queries for string capabilities
    /// that are not present in the terminfo description (either absent or cancelled)
    /// return null.
    pub fn getString(self: Terminfo, s: Strings) ?[]const u8 {
        const idx: u16 = @intFromEnum(s);
        if (idx < self.strings.len) {
            if (self.strings[idx] < 0) return null;
            const start: u16 = @as(u16, @intCast(self.strings[idx]));
            var end = start;
            while (self.stable[end] != 0 and end < self.stable.len) end += 1;
            return self.stable[start..end];
        } else if (idx >= ExtendedParameterStart) {
            if (self.getExtendedCap(idx)) |cap| {
                if (cap.value != .string) return null;
                const start: u16 = @as(u16, @intCast(cap.value.string));
                var end = start;
                while (self.extstable.?[end] != 0 and end < self.extstable.?.len) end += 1;
                return self.extstable.?[start..end];
            }
        }
        return null;
    }

    /// Convert an alternate-character-set string to canonical form: sorted and
    /// unique. This function was adapted from the the file dump_entry.c in the
    /// ncurses source: https://github.com/mirror/ncurses/blob/master/progs/dump_entry.c
    /// note: this fixes the acsc_chars string in place! This also means that if you
    /// need to call this at all, you need to call it only once.
    pub fn repairAcsc(self: *Terminfo) void {
        const idx: u16 = @intFromEnum(Strings.acs_chars);
        if (idx >= self.strings.len or self.strings[idx] < 0) return;
        const start: u16 = @as(u16, @intCast(self.strings[idx]));
        var end = start;
        while (self.stable[end] != 0) end += 1;
        var acs_chars = self.stable[start..end];

        var n: u16 = 0;
        var source: u8 = 0;

        // check if chars are sorted
        const fix_needed: bool = while (n < acs_chars.len) : (n += 1) {
            const target = acs_chars[n];
            if (source > target) break true;
            source = target;
        } else false;

        // this is basically a radix sort
        if (fix_needed) {
            var mapped: [256]u8 = undefined;
            var m: u16 = 0;
            var extra: u8 = 0;

            @memset(&mapped, 0);

            n = 0;
            while (n < acs_chars.len) : (n += 1) {
                source = acs_chars[n];
                if (n + 1 < acs_chars.len) {
                    mapped[source] = acs_chars[n + 1];
                    n += 1;
                } else {
                    extra = source;
                }
            }
            n = 0;
            m = 0;
            while (n < mapped.len) : (n += 1) {
                if (mapped[n] != 0) {
                    acs_chars[m] = @as(u8, @truncate(n));
                    acs_chars[m + 1] = mapped[n];
                    m += 2;
                }
            }
            if (extra != 0) acs_chars[m] = extra; // this probably should not happen
        }
    }

    /// Fetch a parameterized string from the terminfo description evaluating the
    /// %-escapes in the string. The parameter list may contain string- and number
    /// parameters, but the caller needs to make sure that the parameter types match
    /// what is wanted in the string.
    /// The caller must free the returned memory.
    pub fn getInterpolatedString(self: Terminfo, s: Strings, plist: anytype) ParamEvaluator.Error!?[]const u8 {
        const str = self.getString(s) orelse return null;
        return try self.interpolator.run(str, plist);
    }

    /// free the return value of getInterpolatedString(). This takes an optional slice as
    /// it's argument, as returned by getInterpolatedString(), so that you need not check
    /// for null before defer()ing the deallocation.
    pub fn freeInterpolatedString(self: Terminfo, s: ?[]const u8) void {
        if (s != null) {
            self.allocator.free(s.?);
        }
    }

    /// Decode a string from the pattern specified in the user6 string capability. This
    /// is the terminal answer when querying the cursor position with the user7 string
    /// capability.
    /// The return value is the amount of chars consumed from str1 in order to decode
    /// the user6 answer from the terminal, or 0 if the string was not valid or
    /// incomplete. Also returns 0 if there is no user6 string in the terminal
    /// description. Check for this using getString().
    /// If the return value is >0, x.* and y.* are set to the values as retrieved from
    /// string, otherwise the values of x.* and y.* are undefined.
    pub fn decodeUser6(self: Terminfo, str: []const u8, x: *i32, y: *i32) usize {
        const u6str = self.getString(.user6) orelse return 0;
        var idxu: usize = 0;
        var idxs: usize = 0;
        var is_y: bool = true;
        var postdec: bool = false;
        while (idxu < u6str.len) {
            if (u6str[idxu] == '%') {
                idxu += 1;
                if (u6str[idxu] == 'i') {
                    postdec = true;
                } else if (u6str[idxu] == 'd' and '0' <= str[idxs] and str[idxs] <= '9') {
                    var num: i32 = 0;
                    while ('0' <= str[idxs] and str[idxs] <= '9') {
                        num = num * 10 + str[idxs] - '0';
                        idxs += 1;
                    }
                    if (is_y) {
                        y.* = num;
                        is_y = false;
                    } else {
                        x.* = num;
                    }
                } else return 0;
                idxu += 1;
            } else if (u6str[idxu] == str[idxs]) {
                idxu += 1;
                idxs += 1;
            } else return 0;
        }
        if (postdec) {
            x.* -= 1;
            y.* -= 1;
        }
        return idxs;
    }

    //pub fn decodeUser8(self: Terminfo, str: []const u8, ) {
    //}
};

test "basic compilation" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Terminfo);
}

test "enum range check" {
    try std.testing.expect(@intFromEnum(Booleans.auto_left_margin) == 0);
    try std.testing.expect(@intFromEnum(Booleans.lpi_changes_res) == 36);
    try std.testing.expect(@intFromEnum(Booleans.return_does_clr_eol) == 43);
    try std.testing.expect(@intFromEnum(Numbers.columns) == 0);
    try std.testing.expect(@intFromEnum(Numbers.bit_image_type) == 32);
    try std.testing.expect(@intFromEnum(Numbers.number_of_function_keys) == 38);
    try std.testing.expect(@intFromEnum(Strings.back_tab) == 0);
    try std.testing.expect(@intFromEnum(Strings.set_pglen_inch) == 393);
    try std.testing.expect(@intFromEnum(Strings.box_chars_1) == 413);
}

test "open invalid terminfo" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.FileNotFound, Terminfo.init(allocator, "+++invalid+++"));
}

// very basic test, just checks that we can call the param string interpolator via
// the Terminfo struct. We choose a known string with params from an ubiquitous
// terminal
test "param string interpolator" {
    const allocator = std.testing.allocator;
    var ti = try Terminfo.init(allocator, "vt100");
    defer ti.deinit();

    const result = try ti.getInterpolatedString(.cursor_address, .{ 1, 2 });
    defer allocator.free(result.?);
    try std.testing.expect(result.?.len > 0);
}

test "decodeUser6" {
    const allocator = std.testing.allocator;
    // choose a terminal type with a known user6 string: user6=\E[%i%d;%dR
    var ti = try Terminfo.init(allocator, "xterm");
    defer ti.deinit();

    var x: i32 = 0;
    var y: i32 = 0;
    const fakeu6 = "\x1b[12;34R";
    try std.testing.expect(ti.decodeUser6(fakeu6, &x, &y) == fakeu6.len);
    try std.testing.expect(x == 33 and y == 11);
}

// this test checks for collosions of the checksums of known extended attributes.
// If you add more extended attributes, you should also add them here.
test "checksum collisions" {
    const print = std.debug.print;

    const strings = [_][]const u8{
        // booleans (RGB also occurs as a number or a string)
        "AX",     "RGB",    "XT",
        // numbers
        "U8",
        // strings
            "Cr",     "Cs",
        "E0",     "E3",     "Ms",
        "Se",     "Ss",     "XM",
        "smxx",   "rmxx",   "xm",
        "kp5",    "kpADD",  "kpCMA",
        "kpDIV",  "kpDOT",  "kpMUL",
        "kpSUB",  "kpZRO",  "kDC",
        "kDC3",   "kDC4",   "kDC5",
        "kDC6",   "kDC7",   "kDC8",
        "kDC9",   "kDC10",  "kDC11",
        "kDC12",  "kDC13",  "kDC14",
        "kDC15",  "kDC16",  "kDN",
        "kDN3",   "kDN4",   "kDN5",
        "kDN6",   "kDN7",   "kDN8",
        "kDN9",   "kDN10",  "kDN11",
        "kDN12",  "kDN13",  "kDN14",
        "kDN15",  "kDN16",  "kEND",
        "kEND3",  "kEND4",  "kEND5",
        "kEND6",  "kEND7",  "kEND8",
        "kEND9",  "kEND10", "kEND11",
        "kEND12", "kEND13", "kEND14",
        "kEND15", "kEND16", "kHOM",
        "kHOM3",  "kHOM4",  "kHOM5",
        "kHOM6",  "kHOM7",  "kHOM8",
        "kHOM9",  "kHOM10", "kHOM11",
        "kHOM12", "kHOM13", "kHOM14",
        "kHOM15", "kHOM16", "kIC",
        "kIC3",   "kIC4",   "kIC5",
        "kIC6",   "kIC7",   "kIC8",
        "kIC9",   "kIC10",  "kIC11",
        "kIC12",  "kIC13",  "kIC14",
        "kIC15",  "kIC16",  "kLFT",
        "kLFT3",  "kLFT4",  "kLFT5",
        "kLFT6",  "kLFT7",  "kLFT8",
        "kLFT9",  "kLFT10", "kLFT11",
        "kLFT12", "kLFT13", "kLFT14",
        "kLFT15", "kLFT16", "kNXT",
        "kNXT3",  "kNXT4",  "kNXT5",
        "kNXT6",  "kNXT7",  "kNXT8",
        "kNXT9",  "kNXT10", "kNXT11",
        "kNXT12", "kNXT13", "kNXT14",
        "kNXT15", "kNXT16", "kPRV",
        "kPRV3",  "kPRV4",  "kPRV5",
        "kPRV6",  "kPRV7",  "kPRV8",
        "kPRV9",  "kPRV10", "kPRV11",
        "kPRV12", "kPRV13", "kPRV14",
        "kPRV15", "kPRV16", "kRIT",
        "kRIT3",  "kRIT4",  "kRIT5",
        "kRIT6",  "kRIT7",  "kRIT8",
        "kRIT9",  "kRIT10", "kRIT11",
        "kRIT12", "kRIT13", "kRIT14",
        "kRIT15", "kRIT16", "kUP",
        "kUP3",   "kUP4",   "kUP5",
        "kUP6",   "kUP7",   "kUP8",
        "kUP9",   "kUP10",  "kUP11",
        "kUP12",  "kUP13",  "kUP14",
        "kUP15",  "kUP16",
    };

    var hashes: [65536]?[]const u8 = undefined;

    var n: u32 = 0;
    while (n < 65536) : (n += 1) {
        hashes[n] = null;
    }

    for (strings) |s| {
        const h: u16 = chksum(s);
        if (hashes[h] == null) {
            hashes[h] = s;
        } else if (h < ExtendedParameterStart) {
            print("hash for {s} is {d} (< {d})\n", .{ s, h, ExtendedParameterStart });
            try std.testing.expect(false);
        } else {
            print("collision between {s} and {s} (hash {d})\n", .{ hashes[h].?, s, h });
            try std.testing.expect(false);
        }
    }
}

// for more tests check the perl skript test_terminfo.pl which generates
// exhaustive tests for terminal definitions.
