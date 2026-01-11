const view = @import("../ui/view.zig");

pub const FocusTarget = union(enum) {
    root,
    view: view.ViewId,
    none,
};

pub const FocusState = struct {
    target: FocusTarget = .root,

    pub fn setRoot(self: *FocusState) void {
        self.target = .root;
    }

    pub fn setView(self: *FocusState, id: view.ViewId) void {
        self.target = .{ .view = id };
    }

    pub fn clear(self: *FocusState) void {
        self.target = .none;
    }
};
