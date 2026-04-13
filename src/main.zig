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
    .checksum = -(MAGIC + FLAGS),
};

pub extern fn halt() noreturn;

export fn kernel_main() noreturn {
    // Initialize architecture components (GDT, paging, etc.)
    arch.initialize();
    
    term.initialize();
    term.write("Hello from Long Mode!");
    term.write("\nWelcome to zig-os in 64-bit mode!\n");
    term.write("GDT and Page Tables initialized.\n");
    while (true) {
        term.handleInput();
    }
}

export fn _start() callconv(.naked) noreturn {
    // Set up the stack pointer for x86_64
    asm volatile (
        \\  lea stack_bytes(%rip), %rsp
        \\  add %[stack_size], %rsp
        \\  call kernel_main
        :
        : [stack_size] "n" (STACK_SIZE),
        : "rsp"
    );
}
