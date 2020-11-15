[bits 32]
[ORG 0x01000000]
jmp main

%include "lib/console.asm"
%include "lib/keyboard.asm"

main:
    call cls32
    
    mov esi, helloworld
    call sprint32
    
    ; doesn't work so skipping
    ; call init_keyboard
    
    call getcontrollerstatus
    mov byte [tempb], al
    call printbyte
    
    .main_loop:
    call handle_buffer
    
    mov eax, keycode_a
    call is_pressed
    test eax, eax
    jz .skip_print
    mov esi, a_pressed_msg
    call sprint32
    
    .skip_print:
    jmp .main_loop

helloworld db "Hello World!",10,0
a_pressed_msg db "A pressed!",10,0

tempb db 0
