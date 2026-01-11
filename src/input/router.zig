const std = @import("std");
const events = @import("events.zig");
const policy = @import("policy.zig");
const focus = @import("focus.zig");
const scene_mod = @import("../ui/scene.zig");

pub const Router = struct {
    focus_state: focus.FocusState = .{},

    pointer_x: i32 = 0,
    pointer_y: i32 = 0,

    last_click_ns: u64 = 0,
    last_click_x: i32 = -1,
    last_click_y: i32 = -1,
    dbl_click_ns: u64 = 400_000_000,

    button_down: bool = false,
    down_x: i32 = 0,
    down_y: i32 = 0,
    drag_started: bool = false,
    drag_threshold_px: i32 = 6,

    pub fn route(self: *Router, scene: *const scene_mod.Scene, e: events.InputEvent) policy.Action {
        switch (e) {
            .pointer_motion => |m| {
                self.pointer_x += m.dx;
                self.pointer_y += m.dy;

                if (self.pointer_x < 0) self.pointer_x = 0;
                if (self.pointer_y < 0) self.pointer_y = 0;
                if (scene.root_rect.w > 0 and self.pointer_x >= scene.root_rect.w) self.pointer_x = scene.root_rect.w - 1;
                if (scene.root_rect.h > 0 and self.pointer_y >= scene.root_rect.h) self.pointer_y = scene.root_rect.h - 1;

                if (self.button_down and !self.drag_started) {
                    const dx = self.pointer_x - self.down_x;
                    const dy = self.pointer_y - self.down_y;
                    const adx = if (dx < 0) -dx else dx;
                    const ady = if (dy < 0) -dy else dy;
                    if (adx + ady >= self.drag_threshold_px) {
                        self.drag_started = true;
                        return .{ .pointer_drag_begin = .{ .x = self.down_x, .y = self.down_y, .button = 1 } };
                    }
                }

                if (self.button_down) return .{ .pointer_motion = .{ .x = self.pointer_x, .y = self.pointer_y } };
                return .none;
            },

            .pointer_button => |b| {
                if (b.down) {
                    self.button_down = true;
                    self.drag_started = false;
                    self.down_x = self.pointer_x;
                    self.down_y = self.pointer_y;

                    if (scene.hitTest(self.pointer_x, self.pointer_y)) |vid| {
                        self.focus_state.setView(vid);
                    } else {
                        self.focus_state.clear();
                    }

                    const now_ns: u64 = @intCast(std.time.nanoTimestamp());
                    var count: u8 = 1;

                    if (self.last_click_ns != 0 and now_ns - self.last_click_ns <= self.dbl_click_ns) {
                        const dx = self.pointer_x - self.last_click_x;
                        const dy = self.pointer_y - self.last_click_y;
                        const adx = if (dx < 0) -dx else dx;
                        const ady = if (dy < 0) -dy else dy;
                        if (adx + ady <= 6) count = 2;
                    }

                    self.last_click_ns = now_ns;
                    self.last_click_x = self.pointer_x;
                    self.last_click_y = self.pointer_y;

                    return .{ .pointer_click = .{ .x = self.pointer_x, .y = self.pointer_y, .button = b.button, .count = count } };
                } else {
                    self.button_down = false;
                    if (self.drag_started) {
                        self.drag_started = false;
                        return .{ .pointer_drag_end = .{ .x = self.pointer_x, .y = self.pointer_y, .button = b.button } };
                    }
                    return .none;
                }
            },

            else => {},
        }

        return policy.eventToAction(e);
    }
};
