pub const ViewId = u32;

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn contains(self: Rect, px: i32, py: i32) bool {
        if (px < self.x) return false;
        if (py < self.y) return false;
        if (px >= self.x + self.w) return false;
        if (py >= self.y + self.h) return false;
        return true;
    }
};
