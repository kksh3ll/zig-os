.global _start
.extern kernel_main

.set VIDEO_MEM, 0xB8000

.section .multiboot, "a"
.align 8
multiboot_header:
    .long 0xE85250D6
    .long 0
    .long multiboot_header_end - multiboot_header
    .long -(0xE85250D6 + 0 + (multiboot_header_end - multiboot_header))
    .word 0
    .word 0
    .long 8
multiboot_header_end:

.section .bss
.align 16
stack_bottom:
    .skip 16384
stack_top:

.align 4096
pml4:
    .skip 4096
pdpt:
    .skip 4096
pd:
    .skip 4096

.section .data
.align 16
gdt64:
    .quad 0
    .quad 0x00AF9A000000FFFF
    .quad 0x00CF92000000FFFF
gdt64_end:

.section .text
.code32
_start:
    mov $VIDEO_MEM, %edi
    mov $0x0F42, %eax
    mov %eax, (%edi)

    mov $stack_top, %esp
    cli

    sub $6, %esp
    movw $gdt64_end - gdt64 - 1, (%esp)
    movl $gdt64, 2(%esp)
    lgdtl (%esp)
    add $6, %esp

    lea pml4, %edi
    xor %eax, %eax
    mov $1024, %ecx
    cld
1:  stosl
    loop 1b

    lea pdpt, %edi
    xor %eax, %eax
    mov $1024, %ecx
1:  stosl
    loop 1b

    lea pd, %edi
    xor %eax, %eax
    mov $1024, %ecx
1:  stosl
    loop 1b

    lea pdpt, %eax
    or $0x03, %eax
    mov %eax, pml4

    lea pd, %eax
    or $0x03, %eax
    mov %eax, pdpt

    mov $0x83, %eax
    mov %eax, pd

    lea pml4, %eax
    mov %eax, %cr3

    mov %cr4, %eax
    or $0x20, %eax
    mov %eax, %cr4

    mov $0xC0000080, %ecx
    xor %edx, %edx
    rdmsr
    or $0x100, %eax
    wrmsr

    mov %cr0, %eax
    or $0x80000000, %eax
    mov %eax, %cr0

    ljmp $0x08, $long_mode_start

.code64
long_mode_start:
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    mov %cr0, %rax
    and $0xFFFB, %ax
    or $0x2, %ax
    mov %rax, %cr0

    mov %cr4, %rax
    or $0x600, %rax
    mov %rax, %cr4

    mov $VIDEO_MEM + 2, %rdi
    mov $0x0F36, %eax
    mov %eax, (%rdi)

    mov $stack_top, %rsp

    call kernel_main

    cli
1:  hlt
    jmp 1b
