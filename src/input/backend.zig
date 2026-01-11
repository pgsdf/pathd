const std = @import("std");
const ev = @import("events.zig");

pub const InputBackend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: fn (ctx: *anyopaque) void,
        fd: fn (ctx: *anyopaque) std.posix.fd_t,
        readEvent: fn (ctx: *anyopaque, out: *ev.InputEvent) anyerror!bool,
    };

    pub fn deinit(self: *InputBackend) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn fd(self: *InputBackend) std.posix.fd_t {
        return self.vtable.fd(self.ptr);
    }

    pub fn readEvent(self: *InputBackend, out: *ev.InputEvent) !bool {
        return self.vtable.readEvent(self.ptr, out);
    }
};
