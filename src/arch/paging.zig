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
        \\ mov %0, %%cr3
        :
        : "r"(pml4t_addr)
        : "memory"
    );
}

pub fn enablePaging() void {
    // Read CR0
    var cr0: u64 = undefined;
    asm volatile (
        \\ mov %%cr0, %0
        : "=r"(cr0)
        :
        : "memory"
    );

    // Set PG (bit 31) and WP (bit 16) bits
    cr0 |= (1 << 31); // PG - Paging
    cr0 |= (1 << 16); // WP - Write Protect

    // Write back to CR0
    asm volatile (
        \\ mov %0, %%cr0
        :
        : "r"(cr0)
        : "memory"
    );

    // Read CR4
    var cr4: u64 = undefined;
    asm volatile (
        \\ mov %%cr4, %0
        : "=r"(cr4)
        :
        : "memory"
    );

    // Set PAE (bit 5), PSE (bit 4), and SMEP/SMAP if desired
    cr4 |= (1 << 5); // PAE - Physical Address Extension
    cr4 |= (1 << 4); // PSE - Page Size Extension

    // Write back to CR4
    asm volatile (
        \\ mov %0, %%cr4
        :
        : "r"(cr4)
        : "memory"
    );

    // Enable long mode via EFER MSR (0xC0000080)
    // Read EFER
    var efer: u64 = undefined;
    asm volatile (
        \\ mov $0xC0000080, %%ecx
        \\ rdmsr
        \\ shl $32, %%rdx
        \\ or %%rax, %%rdx
        \\ mov %%rdx, %0
        : "=r"(efer)
        :
        : "rax", "rcx", "rdx", "memory"
    );

    // Set LME (bit 8) and NXE (bit 11)
    efer |= (1 << 8);  // LME - Long Mode Enable
    efer |= (1 << 11); // NXE - No-Execute Enable

    // Write back to EFER
    asm volatile (
        \\ mov %0, %%rax
        \\ shr $32, %%rax
        \\ mov %%rax, %%rdx
        \\ mov %0, %%rax
        \\ and $0xFFFFFFFF, %%rax
        \\ mov $0xC0000080, %%ecx
        \\ wrmsr
        :
        : "r"(efer)
        : "rax", "rcx", "rdx", "memory"
    );

    // Set MCE (bit 6), OSFXSR (bit 9), OSXMMEXCPT (bit 10) in CR4
    var cr4_final: u64 = undefined;
    asm volatile (
        \\ mov %%cr4, %0
        : "=r"(cr4_final)
        :
        : "memory"
    );
    cr4_final |= (1 << 6);  // MCE - Machine Check Exception
    cr4_final |= (1 << 9);  // OSFXSR - FXSAVE/FXRSTOR
    cr4_final |= (1 << 10); // OSXMMEXCPT - Unmasked SSE Exceptions

    asm volatile (
        \\ mov %0, %%cr4
        :
        : "r"(cr4_final)
        : "memory"
    );

    // Finally, set LME bit in EFER and enable paging
    // This is done by setting bit 31 (PG) in CR0 which we already did above
    // But we need to ensure LME was set before enabling PG
    
    // Set LME in EFER properly
    var efer_low: u32 = 0;
    var efer_high: u32 = 0;
    asm volatile (
        \\ mov $0xC0000080, %%ecx
        \\ rdmsr
        \\ mov %%eax, %0
        \\ mov %%edx, %1
        : "=r"(efer_low), "=r"(efer_high)
        :
        : "rax", "rcx", "rdx", "memory"
    );
    
    efer_low |= (1 << 8); // LME
    
    asm volatile (
        \\ mov %0, %%eax
        \\ mov %1, %%edx
        \\ mov $0xC0000080, %%ecx
        \\ wrmsr
        :
        : "r"(efer_low), "r"(efer_high)
        : "rax", "rcx", "rdx", "memory"
    );
}

pub fn getPhysicalAddress(virtual_addr: usize) ?usize {
    // Simple identity mapping for now
    return virtual_addr;
}
