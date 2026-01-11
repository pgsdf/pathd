const std = @import("std");
const pathd = @import("pathd");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var s = try pathd.core.session.Session.init(alloc);
    defer s.deinit();

    try s.start();
    s.printState();

    while (!s.should_quit) {
        // poll stdin with a small timeout to keep CPU low
        var pfd = [_]std.posix.pollfd{ .{ .fd = std.posix.STDIN_FILENO, .events = std.posix.POLL.IN, .revents = 0 } };
        _ = try std.posix.poll(&pfd, 100);
        try s.pump();
    }
}
