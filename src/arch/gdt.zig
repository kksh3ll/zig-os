const std = @import("std");

// GDT Entry structure (64-bit)
pub const GDTEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    limit_high: u4,
    flags: u4,
    base_high: u8,
    base_upper: u32,
    reserved: u32 = 0,
};

// GDT Pointer structure
pub const GDTPtr = packed struct {
    limit: u16,
    offset: u64,
};

// Access byte constants
pub const ACCESS_PRESENT: u8 = 1 << 7;
pub const ACCESS_RING0: u8 = 0 << 5;
pub const ACCESS_RING3: u8 = 3 << 5;
pub const ACCESS_DESCRIPTOR: u8 = 1 << 4;
pub const ACCESS_EXECUTABLE: u8 = 1 << 3;
pub const ACCESS_DATA_WRITEABLE: u8 = 1 << 1;
pub const ACCESS_CODE_READABLE: u8 = 1 << 1;

// Flag constants
pub const FLAG_LONG_MODE: u8 = 1 << 1;
pub const FLAG_DEFAULT_SIZE: u8 = 1 << 2;
pub const FLAG_GRANULARITY: u8 = 1 << 3;

// GDT entries count
const GDT_ENTRIES = 5;

// Global GDT storage
var gdt: [GDT_ENTRIES]GDTEntry align(16) linksection(".data") = undefined;
var gdt_ptr: GDTPtr align(16) linksection(".data") = undefined;

pub fn initialize() void {
    // Null segment (index 0)
    gdt[0] = GDTEntry{
        .limit_low = 0,
        .base_low = 0,
        .base_middle = 0,
        .access = 0,
        .limit_high = 0,
        .flags = 0,
        .base_high = 0,
        .base_upper = 0,
    };

    // Kernel Code Segment (index 1)
    gdt[1] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = ACCESS_PRESENT | ACCESS_RING0 | ACCESS_DESCRIPTOR | ACCESS_EXECUTABLE | ACCESS_CODE_READABLE,
        .limit_high = 0xF,
        .flags = FLAG_LONG_MODE | FLAG_GRANULARITY,
        .base_high = 0,
        .base_upper = 0,
    };

    // Kernel Data Segment (index 2)
    gdt[2] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = ACCESS_PRESENT | ACCESS_RING0 | ACCESS_DESCRIPTOR | ACCESS_DATA_WRITEABLE,
        .limit_high = 0xF,
        .flags = FLAG_GRANULARITY,
        .base_high = 0,
        .base_upper = 0,
    };

    // User Code Segment (index 3)
    gdt[3] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = ACCESS_PRESENT | ACCESS_RING3 | ACCESS_DESCRIPTOR | ACCESS_EXECUTABLE | ACCESS_CODE_READABLE,
        .limit_high = 0xF,
        .flags = FLAG_LONG_MODE | FLAG_GRANULARITY,
        .base_high = 0,
        .base_upper = 0,
    };

    // User Data Segment (index 4)
    gdt[4] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = ACCESS_PRESENT | ACCESS_RING3 | ACCESS_DESCRIPTOR | ACCESS_DATA_WRITEABLE,
        .limit_high = 0xF,
        .flags = FLAG_GRANULARITY,
        .base_high = 0,
        .base_upper = 0,
    };

    // Set up GDT pointer
    gdt_ptr.limit = @as(u16, @intCast(@sizeOf(GDTEntry) * GDT_ENTRIES)) - 1;
    gdt_ptr.offset = @intFromPtr(&gdt);

    // Load GDT
    loadGDT();
}

extern fn asm_lgdt(ptr: *const GDTPtr) callconv(.c) void;

fn loadGDT() void {
    asm_lgdt(&gdt_ptr);
}

pub fn getKernelCodeSelector() u16 {
    return 0x08; // Index 1, TI=0, RPL=0
}

pub fn getKernelDataSelector() u16 {
    return 0x10; // Index 2, TI=0, RPL=0
}

pub fn getUserCodeSelector() u16 {
    return 0x18; // Index 3, TI=0, RPL=0
}

pub fn getUserDataSelector() u16 {
    return 0x20; // Index 4, TI=0, RPL=0
}
