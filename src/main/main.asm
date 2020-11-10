[bits 32]
[ORG 0x01000000]
jmp main

%include "lib/console.asm"

main:
    mov esi, helloworld
    call sprint32
    jmp main

helloworld db "Hello World!",10,0
