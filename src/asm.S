.set STACK_SIZE, 16384

.section .text
.global _start

_start:
    leaq stack_bytes(%rip), %rsp
    addq $STACK_SIZE, %rsp
    call kernel_main
1:
    hlt
    jmp 1b

.global asm_lgdt

asm_lgdt:
    lgdt (%rdi)
    ret
