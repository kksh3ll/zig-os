const gdt = @import("gdt.zig");
const paging = @import("paging.zig");

pub const GDT = gdt;
pub const Paging = paging;

pub fn initialize() void {
    // Initialize GDT
    gdt.initialize();
    
    // Initialize page tables
    paging.initialize();
    
    // Enable paging and long mode
    paging.enablePaging();
}
