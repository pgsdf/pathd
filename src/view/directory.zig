const std = @import("std");

pub const Entry = struct {
    name: []u8,
    is_dir: bool,
    size: u64,
    mtime_sec: i64,
};

pub const DirectoryView = struct {
    alloc: std.mem.Allocator,
    path: []u8,
    entries: std.ArrayList(Entry),

    pub fn init(alloc: std.mem.Allocator) !DirectoryView {
        return .{
            .alloc = alloc,
            .path = try alloc.dupe(u8, "."),
            .entries = std.ArrayList(Entry).init(alloc),
        };
    }

    pub fn deinit(self: *DirectoryView) void {
        for (self.entries.items) |e| self.alloc.free(e.name);
        self.entries.deinit();
        self.alloc.free(self.path);
    }

    pub fn setPath(self: *DirectoryView, p: []const u8) !void {
        self.alloc.free(self.path);
        self.path = try self.alloc.dupe(u8, p);
        try self.reload();
    }

    fn lessThan(_: void, a: Entry, b: Entry) bool {
        if (a.is_dir != b.is_dir) return a.is_dir;
        return std.ascii.lessThanIgnoreCase(a.name, b.name);
    }

    fn reload(self: *DirectoryView) !void {
        for (self.entries.items) |e| self.alloc.free(e.name);
        self.entries.clearRetainingCapacity();

        var dir: std.fs.Dir = undefined;
        if (std.fs.path.isAbsolute(self.path)) {
            dir = try std.fs.openDirAbsolute(self.path, .{ .iterate = true });
        } else {
            dir = try std.fs.cwd().openDir(self.path, .{ .iterate = true });
        }
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |dent| {
            const name_copy = try self.alloc.dupe(u8, dent.name);
            try self.entries.append(.{
                .name = name_copy,
                .is_dir = dent.kind == .directory,
                .size = 0,
                .mtime_sec = 0,
            });
        }

        std.sort.pdq(Entry, self.entries.items, {}, lessThan);
    }
};
