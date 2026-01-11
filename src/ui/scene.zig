const view = @import("view.zig");

pub const Scene = struct {
    root_view_id: view.ViewId = 1,
    root_rect: view.Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },

    pub fn setSize(self: *Scene, w: i32, h: i32) void {
        self.root_rect = .{ .x = 0, .y = 0, .w = w, .h = h };
    }

    pub fn hitTest(self: *const Scene, x: i32, y: i32) ?view.ViewId {
        if (self.root_rect.contains(x, y)) return self.root_view_id;
        return null;
    }
};
