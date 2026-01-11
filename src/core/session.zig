const std = @import("std");
const build_options = @import("build_options");

const DirectoryView = @import("../view/directory.zig").DirectoryView;
const policy = @import("../input/policy.zig");
const router_mod = @import("../input/router.zig");
const stdin_raw = @import("../input/stdin_raw.zig");
const backend = @import("../input/backend.zig");
const scene_mod = @import("../ui/scene.zig");
const movefs = @import("../fs/move_samefs.zig");
const exists = @import("../fs/exists_at.zig");

pub const Session = struct {
    alloc: std.mem.Allocator,
    dir_view: DirectoryView,
    router: router_mod.Router = .{},
    scene: scene_mod.Scene = .{},

    input: ?backend.InputBackend = null,
    should_quit: bool = false,

    cursor: usize = 0,
    scroll: usize = 0,

    drag_active: bool = false,
    drag_src_index: usize = 0,
    drag_hover_index: ?usize = null,
    drag_hover_is_dir: bool = false,

    status_buf: [256]u8 = undefined,
    status_len: usize = 0,

    pub fn init(alloc: std.mem.Allocator) !Session {
        var dv = try DirectoryView.init(alloc);
        try dv.setPath(".");
        var s: Session = .{
            .alloc = alloc,
            .dir_view = dv,
        };
        s.scene.setSize(640, 480);
        return s;
    }

    pub fn deinit(self: *Session) void {
        if (self.input) |*ib| ib.deinit();
        self.dir_view.deinit();
    }

    pub fn start(self: *Session) !void {
        if (!build_options.demo) {
            @compileError("drawfs mode not wired in this archive. Build with -Ddemo=true.");
        }
        self.input = try stdin_raw.init(self.alloc);
        self.setStatus("demo mode");
    }

    fn setStatus(self: *Session, msg: []const u8) void {
        const n = @min(msg.len, self.status_buf.len);
        @memcpy(self.status_buf[0..n], msg[0..n]);
        self.status_len = n;
    }

    fn entryIndexAt(self: *Session, y: i32) ?usize {
        // Very simple mapping for demo. Header and footer consume one line each.
        const row_h: i32 = 16;
        const rows_total: i32 = 20; // pretend 320 px tall text area
        const header_h: i32 = row_h;
        const footer_y: i32 = (rows_total - 1) * row_h;
        if (y < header_h) return null;
        if (y >= footer_y) return null;
        const vr: usize = @intCast((y - header_h) / row_h);
        const idx = self.scroll + vr;
        if (idx >= self.dir_view.entries.items.len) return null;
        return idx;
    }

    fn updateDragHoverStatus(self: *Session) void {
        if (!self.drag_active) return;
        self.drag_hover_index = null;
        self.drag_hover_is_dir = false;

        const idx_opt = self.entryIndexAt(self.router.pointer_y);
        if (idx_opt) |idx| {
            const ent = self.dir_view.entries.items[idx];
            self.drag_hover_index = idx;
            self.drag_hover_is_dir = ent.is_dir;
            if (ent.is_dir) {
                var tmp: [256]u8 = undefined;
                const s = std.fmt.bufPrint(&tmp, "drag to {s}/", .{ent.name}) catch "drag";
                self.setStatus(s);
            } else {
                var tmp: [256]u8 = undefined;
                const s = std.fmt.bufPrint(&tmp, "drag over file {s}", .{ent.name}) catch "drag";
                self.setStatus(s);
            }
        } else {
            self.setStatus("drag");
        }
    }

    pub fn pump(self: *Session) !void {
        // Pump input and apply policy. Rendering is a terminal print for now.
        if (self.input == null) return;

        var e: @import("../input/events.zig").InputEvent = undefined;
        var changed = false;

        while (try self.input.?.readEvent(&e)) {
            const a = self.router.route(&self.scene, e);
            if (try self.applyAction(a)) changed = true;
        }

        if (changed) self.printState();
    }

    fn printState(self: *Session) void {
        // Clear screen
        std.debug.print("\x1b[2J\x1b[H", .{});
        std.debug.print("Pathd demo  cwd {s}\n", .{self.dir_view.path});
        if (self.status_len != 0) std.debug.print("status {s}\n", .{self.status_buf[0..self.status_len]});
        std.debug.print("\n", .{});

        const start = self.scroll;
        const end = @min(self.dir_view.entries.items.len, start + 18);
        var i: usize = start;
        while (i < end) : (i += 1) {
            const ent = self.dir_view.entries.items[i];
            const mark: u8 = if (i == self.cursor) '>' else ' ';
            const t: u8 = if (ent.is_dir) '/' else ' ';
            std.debug.print("{c}{c} {s}\n", .{ mark, t, ent.name });
        }

        std.debug.print("\nKeys: arrows move  Enter enter dir  Backspace up  r refresh  q quit\n", .{});
        std.debug.print("Pointer: h j k l move  space click and drag\n", .{});
    }

    fn applyAction(self: *Session, a: policy.Action) !bool {
        switch (a) {
            .none => return false,
            .quit => { self.should_quit = true; return true; },
            .refresh => {
                try self.dir_view.setPath(self.dir_view.path);
                self.setStatus("refreshed");
                return true;
            },
            .cursor_up => {
                const n = self.dir_view.entries.items.len;
                if (n == 0) return false;
                if (self.cursor == 0) self.cursor = n - 1 else self.cursor -= 1;
                return true;
            },
            .cursor_down => {
                const n = self.dir_view.entries.items.len;
                if (n == 0) return false;
                self.cursor = (self.cursor + 1) % n;
                return true;
            },
            .enter_dir => {
                const n = self.dir_view.entries.items.len;
                if (n == 0) return false;
                const ent = self.dir_view.entries.items[self.cursor];
                if (!ent.is_dir) return false;
                const next = try std.fs.path.join(self.alloc, &[_][]const u8{ self.dir_view.path, ent.name });
                defer self.alloc.free(next);
                try self.dir_view.setPath(next);
                self.cursor = 0;
                self.scroll = 0;
                return true;
            },
            .go_up => {
                const parent = try std.fs.path.join(self.alloc, &[_][]const u8{ self.dir_view.path, ".." });
                defer self.alloc.free(parent);
                try self.dir_view.setPath(parent);
                self.cursor = 0;
                self.scroll = 0;
                return true;
            },
            .pointer_click => |p| {
                _ = p;
                if (self.entryIndexAt(self.router.pointer_y)) |idx| {
                    self.cursor = idx;
                    if (p.count == 2) {
                        const ent = self.dir_view.entries.items[idx];
                        if (ent.is_dir) {
                            const next = try std.fs.path.join(self.alloc, &[_][]const u8{ self.dir_view.path, ent.name });
                            defer self.alloc.free(next);
                            try self.dir_view.setPath(next);
                            self.cursor = 0;
                            self.scroll = 0;
                        }
                    }
                    return true;
                }
                return false;
            },
            .pointer_motion => |_| {
                if (self.drag_active) {
                    self.updateDragHoverStatus();
                    return true;
                }
                return false;
            },
            .pointer_drag_begin => |_| {
                if (self.entryIndexAt(self.router.pointer_y)) |idx| {
                    self.drag_active = true;
                    self.drag_src_index = idx;
                    self.updateDragHoverStatus();
                    return true;
                }
                return false;
            },
            .pointer_drag_end => |_| {
                if (!self.drag_active) return false;
                self.drag_active = false;

                const dst_idx_opt = self.entryIndexAt(self.router.pointer_y);
                if (dst_idx_opt == null) {
                    self.status_len = 0;
                    self.drag_hover_index = null;
                    self.drag_hover_is_dir = false;
                    return true;
                }

                const dst_idx = dst_idx_opt.?;
                const dst_ent = self.dir_view.entries.items[dst_idx];
                if (!dst_ent.is_dir) {
                    self.status_len = 0;
                    self.drag_hover_index = null;
                    self.drag_hover_is_dir = false;
                    return true;
                }

                const src_ent = self.dir_view.entries.items[self.drag_src_index];
                if (std.mem.eql(u8, src_ent.name, ".") or std.mem.eql(u8, src_ent.name, "..")) {
                    self.setStatus("refused move of dot entry");
                    return true;
                }
                if (std.mem.eql(u8, dst_ent.name, src_ent.name)) {
                    self.setStatus("refused drop onto self");
                    return true;
                }

                var src_dir = if (std.fs.path.isAbsolute(self.dir_view.path))
                    try std.fs.openDirAbsolute(self.dir_view.path, .{})
                else
                    try std.fs.cwd().openDir(self.dir_view.path, .{});
                defer src_dir.close();

                const dst_path = try std.fs.path.join(self.alloc, &[_][]const u8{ self.dir_view.path, dst_ent.name });
                defer self.alloc.free(dst_path);

                var dst_dir = if (std.fs.path.isAbsolute(dst_path))
                    try std.fs.openDirAbsolute(dst_path, .{})
                else
                    try std.fs.cwd().openDir(dst_path, .{});
                defer dst_dir.close();

                if (exists.existsAt(dst_dir, src_ent.name)) {
                    self.setStatus("refused, destination exists");
                    return true;
                }

                const res = try movefs.moveNameSameFs(src_dir, src_ent.name, dst_dir, src_ent.name);
                switch (res) {
                    .moved => {
                        var tmp: [256]u8 = undefined;
                        const s = std.fmt.bufPrint(&tmp, "moved {s} -> {s}/", .{src_ent.name, dst_ent.name}) catch "moved";
                        self.setStatus(s);
                        try self.dir_view.setPath(self.dir_view.path);
                        const n = self.dir_view.entries.items.len;
                        if (n != 0 and self.cursor >= n) self.cursor = n - 1;
                    },
                    .refused_cross_fs => self.setStatus("refused cross filesystem move"),
                    .refused_invalid => self.setStatus("refused invalid move"),
                    .failed => self.setStatus("move failed"),
                }

                return true;
            },
        }
    }
};
