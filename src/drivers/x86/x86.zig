pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8), // Output constraint
        : [port] "{dx}" (port), // Input constraint - use dx register
    );
}

pub inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        : // No Outputs
        : [value] "{al}" (value), // Input constraints
          [port] "{dx}" (port), // Use dx register for port
    );
}

pub inline fn outw(port: u16, value: u16) void {
    asm volatile ("outw %[value], %[port]"
        : // No Outputs
        : [value] "{ax}" (value), // Input constraints
          [port] "{dx}" (port), // Use dx register for port
    );
}
