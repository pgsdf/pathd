pub const input = struct {
    pub const events = @import("input/events.zig");
    pub const backend = @import("input/backend.zig");
    pub const stdin_raw = @import("input/stdin_raw.zig");
    pub const policy = @import("input/policy.zig");
    pub const focus = @import("input/focus.zig");
    pub const router = @import("input/router.zig");
};

pub const fs = struct {
    pub const move_samefs = @import("fs/move_samefs.zig");
    pub const exists_at = @import("fs/exists_at.zig");
};

pub const view = struct {
    pub const directory = @import("view/directory.zig");
};

pub const ui = struct {
    pub const view = @import("ui/view.zig");
    pub const scene = @import("ui/scene.zig");
};

pub const core = struct {
    pub const session = @import("core/session.zig");
};
