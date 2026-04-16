const std = @import("std");

// Page size constants
pub const PAGE_SIZE: usize = 4096;
pub const PAGE_ENTRIES: usize = 512;

// Page flags
pub const FLAG_PRESENT: u64 = 1 << 0;
pub const FLAG_WRITABLE: u64 = 1 << 1;
pub const FLAG_USER: u64 = 1 << 2;
pub const FLAG_WRITETHROUGH: u64 = 1 << 3;
pub const FLAG_NOCACHE: u64 = 1 << 4;
pub const FLAG_ACCESSED: u64 = 1 << 5;
pub const FLAG_DIRTY: u64 = 1 << 6;
pub const FLAG_LARGE: u64 = 1 << 7; // For 2MB pages in PDE
pub const FLAG_GLOBAL: u64 = 1 << 8;

// Page table entry type
pub const PageEntry = u64;

// Page tables structure (aligned to page boundaries)
var pml4_table: [PAGE_ENTRIES]PageEntry align(PAGE_SIZE) linksection(".bss") = [_]PageEntry{0} ** PAGE_ENTRIES;
var pdpt_table: [PAGE_ENTRIES]PageEntry align(PAGE_SIZE) linksection(".bss") = [_]PageEntry{0} ** PAGE_ENTRIES;
var pd_table: [PAGE_ENTRIES]PageEntry align(PAGE_SIZE) linksection(".bss") = [_]PageEntry{0} ** PAGE_ENTRIES;

// Identity map the first 2MB using large pages for simplicity
pub fn initialize() void {
    // Clear all tables (already zero-initialized, but be explicit)
    @memset(&pml4_table, 0);
    @memset(&pdpt_table, 0);
    @memset(&pd_table, 0);

    // Set up PML4T entry 0 -> points to PDPT
    pml4_table[0] = @intFromPtr(&pdpt_table) | FLAG_PRESENT | FLAG_WRITABLE | FLAG_USER;

    // Set up PDPT entry 0 -> points to PD
    pdpt_table[0] = @intFromPtr(&pd_table) | FLAG_PRESENT | FLAG_WRITABLE | FLAG_USER;

    // Set up PD entries for 2MB large pages
    // Map first 512 * 2MB = 1GB of physical memory
    var i: usize = 0;
    while (i < PAGE_ENTRIES) : (i += 1) {
        const phys_addr: u64 = @as(u64, i) * 2 * 1024 * 1024; // 2MB per entry
        pd_table[i] = (phys_addr & 0xFFFF_FFE0_0000) | FLAG_PRESENT | FLAG_WRITABLE | FLAG_USER | FLAG_LARGE;
    }

    // Load CR3 with PML4T address
    loadCR3();
}

fn loadCR3() void {
    const pml4t_addr: u64 = @intFromPtr(&pml4_table);
    asm volatile (
        \\ mov %[addr], %%cr3
        :
        : [addr] "r" (pml4t_addr),
        : .{ .memory = true });
}

pub fn enablePaging() void {
    var cr0: u64 = undefined;
    asm volatile (
        \\ mov %%cr0, %[out]
        : [out] "=r" (cr0),
    );

    cr0 |= (1 << 31);
    cr0 |= (1 << 16);

    asm volatile (
        \\ mov %[in], %%cr0
        :
        : [in] "r" (cr0),
        : .{ .memory = true });

    var cr4: u64 = undefined;
    asm volatile (
        \\ mov %%cr4, %[out]
        : [out] "=r" (cr4),
    );

    cr4 |= (1 << 5);
    cr4 |= (1 << 4);

    asm volatile (
        \\ mov %[in], %%cr4
        :
        : [in] "r" (cr4),
        : .{ .memory = true });

    var efer_low: u32 = undefined;
    var efer_high: u32 = undefined;
    asm volatile (
        \\ mov $0xC0000080, %%ecx
        \\ rdmsr
        : [low] "={eax}" (efer_low),
          [high] "={edx}" (efer_high),
        :
        : .{ .ecx = true });

    var efer: u64 = (@as(u64, efer_high) << 32) | efer_low;
    efer |= (1 << 8);
    efer |= (1 << 11);

    const efer_out_low: u32 = @truncate(efer);
    const efer_out_high: u32 = @truncate(efer >> 32);

    asm volatile (
        \\ mov $0xC0000080, %%ecx
        \\ wrmsr
        :
        : [low] "{eax}" (efer_out_low),
          [high] "{edx}" (efer_out_high),
        : .{ .ecx = true });

    var cr4_final: u64 = undefined;
    asm volatile (
        \\ mov %%cr4, %[out]
        : [out] "=r" (cr4_final),
    );

    cr4_final |= (1 << 6);
    cr4_final |= (1 << 9);
    cr4_final |= (1 << 10);

    asm volatile (
        \\ mov %[in], %%cr4
        :
        : [in] "r" (cr4_final),
        : .{ .memory = true });

    var efer_final_low: u32 = undefined;
    var efer_final_high: u32 = undefined;
    asm volatile (
        \\ mov $0xC0000080, %%ecx
        \\ rdmsr
        : [low] "={eax}" (efer_final_low),
          [high] "={edx}" (efer_final_high),
        :
        : .{ .ecx = true });

    efer_final_low |= (1 << 8);

    asm volatile (
        \\ mov $0xC0000080, %%ecx
        \\ wrmsr
        :
        : [low] "{eax}" (efer_final_low),
          [high] "{edx}" (efer_final_high),
        : .{ .ecx = true });
}

pub fn getPhysicalAddress(virtual_addr: usize) ?usize {
    // Simple identity mapping for now
    return virtual_addr;
}
