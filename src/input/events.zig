pub const KeyState = enum { press, release, repeat };

pub const Key = enum(u16) {
    up,
    down,
    left,
    right,
    enter,
    backspace,
    esc,
    q,
    r,
    unknown,
};

pub const Modifiers = packed struct(u8) {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    _pad: u5 = 0,
};

pub const InputEvent = union(enum) {
    key: struct {
        key: Key,
        state: KeyState,
        mods: Modifiers = .{},
    },
    pointer_motion: struct { dx: i32, dy: i32 },
    pointer_button: struct { button: u8, down: bool },
};
