const std = @import("std");

pub fn existsAt(dir: std.fs.Dir, name: []const u8) bool {
    var st: std.posix.Stat = undefined;
    return (std.posix.fstatat(dir.fd, name, &st, 0) == void{});
}
