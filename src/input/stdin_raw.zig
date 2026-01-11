const std = @import("std");
const ev = @import("events.zig");
const backend = @import("backend.zig");

pub fn init(alloc: std.mem.Allocator) !backend.InputBackend {
    var s = try alloc.create(State);
    s.* = .{ .alloc = alloc };
    try s.enableRaw();

    // Make stdin nonblocking
    const flags = try std.posix.fcntl(std.posix.STDIN_FILENO, std.posix.F.GETFL, 0);
    _ = try std.posix.fcntl(std.posix.STDIN_FILENO, std.posix.F.SETFL, flags | std.posix.O.NONBLOCK);

    return .{ .ptr = s, .vtable = &VTABLE };
}

const State = struct {
    alloc: std.mem.Allocator,
    orig: std.posix.termios = undefined,
    raw_enabled: bool = false,
    buf: [64]u8 = undefined,
    buf_len: usize = 0,

    fn enableRaw(self: *State) !void {
        const fd = std.posix.STDIN_FILENO;
        self.orig = try std.posix.tcgetattr(fd);

        var t = self.orig;
        t.iflag &= ~(std.posix.BRKINT | std.posix.ICRNL | std.posix.INPCK | std.posix.ISTRIP | std.posix.IXON);
        t.oflag &= ~(std.posix.OPOST);
        t.cflag |= (std.posix.CS8);
        t.lflag &= ~(std.posix.ECHO | std.posix.ICANON | std.posix.IEXTEN | std.posix.ISIG);
        t.cc[@intFromEnum(std.posix.V.MIN)] = 0;
        t.cc[@intFromEnum(std.posix.V.TIME)] = 0;

        try std.posix.tcsetattr(fd, .NOW, t);
        self.raw_enabled = true;
    }

    fn disableRaw(self: *State) void {
        if (!self.raw_enabled) return;
        _ = std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, self.orig);
        self.raw_enabled = false;
    }

    fn deinit(self: *State) void {
        self.disableRaw();
        self.alloc.destroy(self);
    }

    fn fd(self: *State) std.posix.fd_t {
        _ = self;
        return std.posix.STDIN_FILENO;
    }

    fn readEvent(self: *State, out: *ev.InputEvent) !bool {
        var tmp: [32]u8 = undefined;
        const n = std.posix.read(std.posix.STDIN_FILENO, &tmp) catch |e| switch (e) {
            error.WouldBlock => return false,
            else => return e,
        };
        if (n == 0) return false;

        if (self.buf_len + n > self.buf.len) self.buf_len = 0;
        @memcpy(self.buf[self.buf_len .. self.buf_len + n], tmp[0..n]);
        self.buf_len += n;

        if (try parseOne(self, out)) return true;
        return false;
    }
};

fn parseOne(self: *State, out: *ev.InputEvent) !bool {
    if (self.buf_len == 0) return false;

    // Arrow keys ESC [ A/B/C/D
    if (self.buf[0] == 0x1b) {
        if (self.buf_len < 3) return false;
        if (self.buf[1] == '[') {
            const k = switch (self.buf[2]) {
                'A' => ev.Key.up,
                'B' => ev.Key.down,
                'C' => ev.Key.right,
                'D' => ev.Key.left,
                else => ev.Key.unknown,
            };
            out.* = .{ .key = .{ .key = k, .state = .press } };
            consume(self, 3);
            return true;
        }
        out.* = .{ .key = .{ .key = ev.Key.esc, .state = .press } };
        consume(self, 1);
        return true;
    }

    const c = self.buf[0];

    // Dev pointer controls
    if (c == 'h') { out.* = .{ .pointer_motion = .{ .dx = -8, .dy = 0 } }; consume(self, 1); return true; }
    if (c == 'l') { out.* = .{ .pointer_motion = .{ .dx =  8, .dy = 0 } }; consume(self, 1); return true; }
    if (c == 'k') { out.* = .{ .pointer_motion = .{ .dx = 0, .dy = -8 } }; consume(self, 1); return true; }
    if (c == 'j') { out.* = .{ .pointer_motion = .{ .dx = 0, .dy =  8 } }; consume(self, 1); return true; }
    if (c == ' ') { out.* = .{ .pointer_button = .{ .button = 1, .down = true } }; consume(self, 1); return true; }

    const key = switch (c) {
        0x0d, 0x0a => ev.Key.enter,
        0x7f => ev.Key.backspace,
        'q' => ev.Key.q,
        'r' => ev.Key.r,
        else => ev.Key.unknown,
    };

    out.* = .{ .key = .{ .key = key, .state = .press } };
    consume(self, 1);
    return true;
}

fn consume(self: *State, n: usize) void {
    if (n >= self.buf_len) {
        self.buf_len = 0;
        return;
    }
    const remain = self.buf_len - n;
    std.mem.copyForwards(u8, self.buf[0..remain], self.buf[n .. n + remain]);
    self.buf_len = remain;
}

const VTABLE = backend.InputBackend.VTable{
    .deinit = deinitThunk,
    .fd = fdThunk,
    .readEvent = readEventThunk,
};

fn deinitThunk(ctx: *anyopaque) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.deinit();
}

fn fdThunk(ctx: *anyopaque) std.posix.fd_t {
    const self: *State = @ptrCast(@alignCast(ctx));
    return self.fd();
}

fn readEventThunk(ctx: *anyopaque, out: *ev.InputEvent) anyerror!bool {
    const self: *State = @ptrCast(@alignCast(ctx));
    return self.readEvent(out);
}
