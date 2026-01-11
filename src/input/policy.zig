const ev = @import("events.zig");

pub const Action = union(enum) {
    none,
    quit,
    refresh,
    cursor_up,
    cursor_down,
    enter_dir,
    go_up,
    pointer_motion: struct { x: i32, y: i32 },
    pointer_click: struct { x: i32, y: i32, button: u8, count: u8 },
    pointer_drag_begin: struct { x: i32, y: i32, button: u8 },
    pointer_drag_end: struct { x: i32, y: i32, button: u8 },
};

pub fn eventToAction(e: ev.InputEvent) Action {
    return switch (e) {
        .key => |k| switch (k.state) {
            .press, .repeat => switch (k.key) {
                .up => .cursor_up,
                .down => .cursor_down,
                .enter => .enter_dir,
                .backspace => .go_up,
                .r => .refresh,
                .q, .esc => .quit,
                else => .none,
            },
            .release => .none,
        },
        else => .none,
    };
}
