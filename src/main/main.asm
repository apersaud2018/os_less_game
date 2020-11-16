[bits 32]
[ORG 0x01000000]
jmp main
%include "lib/keyboard.asm"
%include "images/temp.asm"
%include "images/char.asm"

; buffer for double buffering the screen
screen_buffer TIMES 64000 db 0 
game_state db 0 ; 0 = main menu, 1 = game run state

player_x dd 0
player_y dd 110

main:
    mov esi, helloworld
    
    ;call sprint32
    ;jmp main
    
main_loop:
    
    
    mov al, [game_state]
    cmp al, 0
    je main_menu
    cmp al, 1
    je game_run
    ; draw main menu state
main_menu:
    call handle_buffer
    mov eax, keycode_a
    call is_pressed
    test eax, eax
    jz stay_in_menu
        mov byte[game_state], 1
        mov eax, 0x0A0000
   
        mov byte[eax] , 42
    stay_in_menu:
    
    call draw_main_menu
    mov ebx, 0
    mov edx, 120
    mov eax, char_img
    call drawimg
    
    jmp end_main_loop
    ; game run state
game_run:
    
    
    mov ebx, 0
    mov edx, 0
    mov eax, temp_img
    call drawimg  
    mov ebx, [player_x]
    mov edx, [player_y]
    mov eax, char_img
    call drawimg
    jmp end_main_loop
    
    
end_main_loop:
    
    
    call write_buffer_to_screen
    
    jmp main_loop
    
hang_main:
    jmp hang_main

draw_main_menu:
    mov ebx, 0
    mov edx, 0
    mov eax, main_menu_img
    call drawimg
    ret

write_buffer_to_screen:
    mov ecx, 0xFFFF
    
buffer_write_loop:
    mov eax, screen_buffer
    add eax, ecx
    mov bl, [eax]
    
    mov eax, 0xA0000
    add eax, ecx
    mov byte[eax] , bl
    
    
    loop buffer_write_loop
    ret

    
helloworld db "Hello World!",10,0

max_x dd 0
max_y dd 0
img_x dd 0
img_y dd 0
img_pos_x dd 0
img_pos_y dd 0
img_data dd 0
drawimg: ; Draws image, image stored in EAX, EBX: x, EDX: y
    mov [img_pos_y], edx
    mov [img_pos_x], ebx
    
    mov ebx,[eax]
    mov [max_x],ebx
    add eax, 4
    mov ebx, [eax]
    mov [max_y],ebx
    add eax, 4
    mov [img_data], eax
    
    
    
    mov eax, [img_pos_x]
    mov [img_x], eax
    mov eax, [img_pos_y]
    mov [img_y], eax
    xor ecx, ecx
    ;jmp exit_draw_func
    
    
    
draw_loop:
    
    mov eax, [img_x]
    mov ebx, 320
    cmp eax, ebx
    jl check_y_bound
        
        mov eax, [img_pos_x]
        mov [img_x], eax
        mov eax, [img_y]
        inc eax
        mov [img_y], eax
        mov ebx, [img_pos_y]
        sub eax, ebx
        mov ebx, [max_x]
        mul ebx
        mov ecx, eax
        
    check_y_bound:
    
    mov eax, [img_y]
    mov ebx, 200
    cmp eax, ebx
    jge exit_draw_func
    
    mov eax, [img_x]
    mov ebx, [img_pos_x]
    add ebx, [max_x]
    
    cmp eax, ebx
    jl compare_y_bound
        mov eax, [img_pos_x]
        mov [img_x], eax
        mov eax, [img_y]
        inc eax
        mov [img_y], eax
    compare_y_bound:
    
    mov eax, [img_y]
    mov ebx, [img_pos_y]
    add ebx, [max_y]
    cmp eax, ebx
    jge exit_draw_func
    
    
    mov eax, [img_y]
    mov edx, 0
    mov ebx, 320
    mul ebx
    add eax, [img_x]
    add eax, screen_buffer
    ;0x0A0000
   ; mov bl, 55
    mov ebx, [img_data]
    add ebx, ecx
    mov bl, byte[ebx]
    cmp bl, 0
    je skip_pixel
    mov byte[eax] , bl
skip_pixel:
    inc ecx
    mov eax, [img_x]
    inc eax
    mov [img_x], eax
    cmp ecx, 0xFA00
    jne draw_loop

exit_draw_func:

    ret


