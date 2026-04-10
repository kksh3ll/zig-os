const x86 = @import("../drivers/x86/x86.zig");
const vga = @import("../drivers/vga/buffer.zig");

pub const Cursor = struct {
    row: usize,
    column: usize,
    max_width: usize,
    max_height: usize,
    needs_scroll: bool,

    const Self = @This();

    pub fn init(width: usize, height: usize) Self {
        return Self{
            .row = 0,
            .column = 0,
            .max_width = width,
            .max_height = height,
            .needs_scroll = false,
        };
    }

    pub fn getPosition(self: *const Self) struct { usize, usize } {
        return .{ self.row, self.column };
    }

    pub fn moveTo(self: *Self, r: usize, col: usize) void {
        if (r >= self.max_height or col >= self.max_width) return;
        self.row = r;
        self.column = col;
        self.needs_scroll = false;
        self.updateHardwareCursor();
    }

    pub fn advance(self: *Self) void {
        self.column += 1;
        if (self.column >= self.max_width) {
            self.column = 0;
            self.row += 1;
            if (self.row >= self.max_height) {
                self.row = self.max_height - 1;
                self.needs_scroll = true;
            }
        }
        self.updateHardwareCursor();
    }

    pub fn backOne(self: *Self) void {
        if (self.column > 0) {
            self.column = self.column - 1;
            self.updateHardwareCursor();
            return;
        }
        if (self.row == 0) {
            return;
        }

        self.row = self.row - 1;
        self.column = self.max_width - 1;
        self.needs_scroll = false;
        self.updateHardwareCursor();
    }

    pub fn newLine(self: *Self) void {
        self.column = 0;
        self.row += 1;
        if (self.row >= self.max_height) {
            self.row -= 1;
            self.needs_scroll = true;
        }
        self.updateHardwareCursor();
    }

    pub fn reset(self: *Self) void {
        self.column = 0;
        self.row = 0;
        self.needs_scroll = false;
        self.updateHardwareCursor();
    }

    pub fn checkScroll(self: *Self) bool {
        const needs = self.needs_scroll;
        self.needs_scroll = false;
        return needs;
    }

    pub fn updateHardwareCursor(self: *const Self) void {
        const offset = self.row * vga.VGABuffer.WIDTH + self.column;
        x86.outb(0x3D4, 0x0E);
        x86.outb(0x3D5, @as(u8, @truncate(offset >> 8)));
        x86.outb(0x3D4, 0x0F);
        x86.outb(0x3D5, @as(u8, @truncate(offset)));
    }
};
