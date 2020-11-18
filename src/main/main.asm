[bits 32]
[ORG 0x01000000]
jmp main
%include "lib/keyboard.asm"
%include "images/temp.asm"
%include "images/char.asm"
%include "lib/attack_patterns.asm"

; buffer for double buffering the screen
screen_buffer TIMES 64000 db 0
game_state db 0 ; 0 = main menu, 1 = game run state

player_x dd 0
player_y dd 110
player_vy dd 0
frame_count db 0
castle_y dd 60

ground_x dd -320

obstacle_x TIMES 9 dd 400
obstacle_y TIMES 9 dd 40
obstacle_ready dd 0, 0, 0, 0, 0, 0, 0, 0, 1
obstacle_speed dd 10

max_lives equ 3

score dd 0

main:
    ;mov esi, helloworld
    mov ebp, max_lives
    

    ;call sprint32
    ;jmp main

main_loop:
    mov eax, 0
    mov ebx, 0
    mov edx, 0
    mov al, [frame_count]
    inc al
    mov [frame_count], al
    mov al, [game_state]
    cmp al, 0
    je main_menu
    cmp al, 1
    je game_run
    ; draw main menu state
main_menu:
    mov eax,0
    call handle_buffer
    mov eax, keycode_enter
    call is_pressed
    test eax, eax
    jz stay_in_menu
        mov al, 1
        mov [game_state], al
        mov dword [score], 0
        mov ebp, max_lives
        ;seed the RNG with frame count when user presses enter
       
        mov eax, [frame_count]
        mov [rng], eax
    stay_in_menu:
    mov eax, 0
    call draw_main_menu
    call draw_score
    call draw_character
    ;mov ebx, 0
    ;mov edx, 0
    ;mov eax, zero_img
    ;call drawimg
    ;mov ebx, 10
    ;mov edx, 0
    ;mov eax, one_img
    ;call drawimg

    jmp end_main_loop
    ; game run state
game_run:
 
    ; check for spacebar press
    mov eax,0
    call handle_buffer
    mov eax, keycode_space
    call is_pressed
    test eax, eax
    jz skip_jump
        ;initiate jump
        mov Dword[player_vy], -10
        
    skip_jump:
    ; prevent player from falling through the ground
    mov eax, [player_y]
    add eax, [player_vy]
    mov ebx, 110
    cmp eax, ebx
    jl .keep_falling
        mov eax, 110
        mov Dword[player_vy], 0
    .keep_falling:
    ; prevent player from jumping out of bounds
    mov ebx, -20
    cmp eax, ebx
    jg .player_in_bounds
        mov eax, -20
        mov Dword[player_vy], 1
    .player_in_bounds:
    
    mov [player_y], eax
    
    mov eax, Dword[player_vy]
    inc eax
 
    

    
    mov Dword[player_vy], eax
   
   
    ; draw background
    mov ebx, 0
    mov edx, 0
    mov eax, temp_img
    call drawimg
    ; draw ground
    mov ebx, [ground_x]
    sub ebx, 6
    mov edx, -320
    cmp ebx, edx
    jg .skip_ground_reset
        mov ebx, 0
    .skip_ground_reset:
    mov [ground_x], ebx
    mov edx, 180
    mov eax, ground_img
    call drawimg
    mov ebx, [ground_x]
    add ebx, 320
    mov edx, 180
    mov eax, ground_img
    call drawimg
    mov ebx, [ground_x]
    add ebx, 320
    mov edx, 180
    mov eax, ground_img
    ;call drawimg
    call drawimg
    ;draw floating castle
   
    call draw_castle
   
    ;draw player
    call draw_character
   
    call draw_obstacles
   
    call draw_score
    
    ;spawn new obstacles
    mov eax, [obstacle_ready+32]
    cmp eax, 0
    jne .skip_ob_spawn
        call spawn_obstacles
    .skip_ob_spawn:
    mov eax, [hit]
    cmp eax, 0
    je .skip_hit_counter
        dec eax
        mov [hit], eax
    .skip_hit_counter:
    ;mov eax, 0
    ;mov ebx, 0
    ;mov edx, 0
    jmp end_main_loop


end_main_loop:


    call write_buffer_to_screen
    call manage_lost
    jmp main_loop


manage_lost:
    cmp ebp, 0
    jge .cont
    mov byte [game_state], 0
    mov dword [player_x], 0
    mov dword [player_y], 110
    mov dword [player_vy], 0
    mov byte [frame_count], 0
    mov dword [castle_y], 60

    mov dword [ground_x], -320

    mov ebx, 0
    mov ecx, 9
    .reset:
        mov dword [obstacle_x+ebx], 400
        mov dword [obstacle_y+ebx], 40
        mov dword [obstacle_ready+ebx], 0
        add ebx, 4
    loop .reset
    mov dword [obstacle_ready+ebx-4], 1
    ; mov dword [obstacle_speed] dd 10
    .cont:
    ret


draw_main_menu:
    mov ebx, 0
    mov edx, 0
    mov eax, main_menu_img
    call drawimg
    ret

    
ob_count dd 0
draw_obstacles:
    mov ecx, 9
    
    .for_each_obstacle:
        mov [ob_count], ecx
        mov eax, 0
        mov eax, [obstacle_ready+(ecx-1)*4]
        cmp eax, 0
        je .exit_ob_loop
        ;draw each obstacle
        
        mov ebx, [obstacle_x+(ecx-1)*4]
        mov edx, [obstacle_y+(ecx-1)*4]
        mov eax, projectile_img
        call drawimg
        mov ecx, [ob_count]
        ;move the obstacle
        
        mov eax, [obstacle_x+(ecx-1)*4]
        sub eax, [obstacle_speed]
        mov [obstacle_x+(ecx-1)*4], eax
        
        ; check if obstacle is out of bounds
        cmp eax, -80
        jg .skip_obstacle_reset
            ; reset obstacle
            mov eax, 400
            mov [obstacle_x+(ecx-1)*4], eax
            mov byte[obstacle_ready+(ecx-1)*4], 0
            mov eax, [score]
            inc eax
            mov [score], eax
            
            
        .skip_obstacle_reset:
        
        ; calculate
        call compute_collision
        mov ecx, [ob_count]
        
    .exit_ob_loop:
    loop .for_each_obstacle
    
    ret

draw_castle:
    mov eax, 0
    mov al, [frame_count]
    shr al, 3
    and al, 0x7 ; mod by 8
    cmp eax, 3
    jg .move_up
        sub eax, 4
        neg eax
    jmp .move_down
    .move_up:
    sub eax, 4
    .move_down:
    mov edx, [castle_y]
    add edx, eax
    
    mov ebx, 136
    mov eax, castle_img
    call drawimg
    ret

draw_character:
    mov eax, [hit]
    shr eax, 1
    and eax, 0x1
    cmp eax, 1
    je .end_draw
    mov eax, 0
    mov al, [frame_count]
    shr al, 2
    and al, 0x3 ; mod by 4
    mov ebx, [player_y]
    mov edx, 110
    cmp ebx, edx
    je .skip_jump_animation
        mov eax, 0 
    .skip_jump_animation:
    mov ebx, 6408
    mul ebx
    add eax, char_img
    
    mov ebx, [player_x]
    mov edx, [player_y]
    ;mov eax, char_img
    call drawimg
    .end_draw:
    ret

write_buffer_to_screen:



    ;mov eax, screen_buffer
    ;add eax, ecx
    ;mov bl, [eax]

    ;mov eax, 0xA0000
    ;add eax, ecx
    ;mov byte[eax] , bl

    mov esi, screen_buffer
    mov edi, 0xA0000
    mov ecx, 64000
    rep movsb


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
    mov edx, [img_x]
    cmp edx, 0
    jl skip_pixel
    cmp edx, 320
    jge skip_pixel
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

rng dd 0
rng_a dd 1664525
rng_b dd 1013904223


spawn_obstacles:
    ;generate a random number
    mov eax, [rng]
    mov ebx, [rng_a]
    mov edx, 0
    mul ebx
    add eax, [rng_b]
    mov [rng], eax
    and eax, 0x7
    cmp eax, 0
    je .pattern_1
    cmp eax, 1
    je .pattern_2
    cmp eax, 2
    je .pattern_3
    cmp eax, 3
    je .pattern_4
    cmp eax, 4
    je .pattern_5
    cmp eax, 5
    je .pattern_6
    cmp eax, 6
    je .pattern_7
    cmp eax, 7
    je .pattern_8
    
    .pattern_1:
    mov ecx, 9
    mov esi, pattern_x_1
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_1
    mov edi, obstacle_y
    rep movsd
    jmp .ready_obstacles
    
    .pattern_2:
    mov ecx, 9
    mov esi, pattern_x_2
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_2
    mov edi, obstacle_y
    rep movsd
    jmp .ready_obstacles
    
    .pattern_3:
    mov ecx, 9
    mov esi, pattern_x_3
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_3
    mov edi, obstacle_y
    rep movsd    
    jmp .ready_obstacles
    
    .pattern_4:
    mov ecx, 9
    mov esi, pattern_x_4
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_4
    mov edi, obstacle_y
    rep movsd   
    jmp .ready_obstacles
    
    .pattern_5:
    mov ecx, 9
    mov esi, pattern_x_5
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_5
    mov edi, obstacle_y
    rep movsd
    jmp .ready_obstacles
    
    .pattern_6:
    mov ecx, 9
    mov esi, pattern_x_6
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_6
    mov edi, obstacle_y
    rep movsd
    jmp .ready_obstacles
    
    .pattern_7:
    mov ecx, 9
    mov esi, pattern_x_7
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_7
    mov edi, obstacle_y
    rep movsd    
    jmp .ready_obstacles
    
    .pattern_8:
    mov ecx, 9
    mov esi, pattern_x_8
    mov edi, obstacle_x
    rep movsd
    mov ecx, 9
    mov esi, pattern_y_8
    mov edi, obstacle_y
    rep movsd   
    jmp .ready_obstacles
    .ready_obstacles:
    mov ecx, 9
    .reset_ob_loop:
        mov eax, 1
        mov [obstacle_ready+(ecx-1)*4], eax
    loop .reset_ob_loop
    
    ret

hit dd 0

compute_collision:
    mov ecx, [ob_count]
    mov ebx, [obstacle_x+(ecx-1)*4]
    add ebx, 40
    sub ebx, [player_x]
    sub ebx, 33
    mov eax, ebx
    mul ebx
    mov ebx, eax
    mov eax, [player_y]
    add eax, 50
    sub eax, [obstacle_y+(ecx-1)*4]
    sub eax, 20
    mul eax
 
    add eax, ebx
    ;eax now contains square of distance
    cmp eax, 1600
    jg .no_collision 
        mov eax, 400
        mov [obstacle_x+(ecx-1)*4], eax
        mov byte[obstacle_ready+(ecx-1)*4], 0
        mov eax, 50
        mov [hit], eax
        sub ebp, 1
    .no_collision:
    
    ret
temp_var dd 0
temp_count dd 0
%include "images/ui.asm"
draw_score:
    ;draw the score
    mov ebx, 0
    mov edx, 0
    mov eax, score_img
    call drawimg
    
    
    
    mov eax, [score]
    shl eax, 21
    mov ecx, 0
    mov [temp_var], eax
    .score_loop:
    mov eax, [temp_var]
    mov ebx, eax
    and ebx, 0x80000000
    shl eax, 1
    mov [temp_count], ecx
    mov [temp_var], eax
    cmp ebx, 0
    je .display_zero
        
       
        mov eax, ecx
        mov ebx, 10
        mul ebx
        add eax, 35
        mov edx, 0
        mov ebx, eax
        mov eax, one_img
        call drawimg
    jmp .display_one
        
    .display_zero:
        mov eax, ecx
        mov ebx, 10
        mul ebx
        add eax, 35
        mov edx, 0
        mov ebx, eax
        mov eax, zero_img
        call drawimg 
    .display_one:
    mov ecx, [temp_count]
    inc ecx
    cmp ecx, 11
    jl .score_loop
    ret
