const std = @import("std");
const builtin = @import("builtin");
const term = @import("terminal/terminal.zig").terminal;
const arch = @import("arch/mod.zig");

const MultiBoot = extern struct {
    magic: u32,
    flags: u32,
    checksum: u32,
};

// 64-bit Long Mode constants
const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const FLAGS = ALIGN | MEMINFO;
const MAGIC = 0x1BADB002;

// Define our stack size for long mode
const STACK_SIZE = 16 * 1024; // 16 KB

export var stack_bytes: [STACK_SIZE]u8 align(16) linksection(".bss") = undefined;

export var multiboot align(8) linksection(".multiboot") = MultiBoot{
    .magic = MAGIC,
    .flags = FLAGS,
    .checksum = -%@as(u32, MAGIC +% FLAGS),
};

pub extern fn halt() noreturn;

export fn kernel_main() noreturn {
    arch.initialize();
    term.initialize();
    term.write("Hello from Long Mode!");
    term.write("\nWelcome to zig-os in 64-bit mode!\n");
    term.write("GDT and Page Tables initialized.\n");
    while (true) {
        term.handleInput();
    }
}
