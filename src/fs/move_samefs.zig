const std = @import("std");

pub const MoveResult = enum {
    moved,
    refused_cross_fs,
    refused_invalid,
    failed,
};

fn statDev(dir: std.fs.Dir) !u64 {
    var st: std.posix.Stat = undefined;
    try std.posix.fstat(dir.fd, &st);
    return @as(u64, @intCast(st.dev));
}

pub fn moveNameSameFs(src_dir: std.fs.Dir, src_name: []const u8, dst_dir: std.fs.Dir, dst_name: []const u8) !MoveResult {
    if (src_name.len == 0 or dst_name.len == 0) return .refused_invalid;

    const src_dev = try statDev(src_dir);
    const dst_dev = try statDev(dst_dir);
    if (src_dev != dst_dev) return .refused_cross_fs;

    std.posix.renameat(src_dir.fd, src_name, dst_dir.fd, dst_name) catch {
        return .failed;
    };
    return .moved;
}
