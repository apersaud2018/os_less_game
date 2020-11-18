%ifndef KEYBOARD_INC
%define KEYBOARD_INC

%include "lib/console.asm"
%include "lib/keycodes.asm"

key_is_pressed times 88 db 0

keyboard_hang_read_ready:
    ; waits for read bit to be set
    push edx
    push eax
    
    mov dx, 0x64
    .loop:
    in al, dx
    test al, 1b
    jz .loop
    
    pop eax
    pop edx
    ret

keyboard_hang_write_ready:
    ; waits for write bit to be cleared
    push edx
    push eax
    
    mov dx, 0x64
    .loop:
    in al, dx
    test al, 10b
    jnz .loop
    
    pop eax
    pop edx
    ret


is_pressed:
    push ebx
    mov ebx, key_is_pressed
    add ebx, eax
    movzx eax, byte[ebx]
    pop ebx
    ret

handle_buffer:
    ; Reads buffer untill empty
    push edx
    push eax
    push ecx
    
    ; check if there is anyhting in buffer/is ready for read
    .start_read:
    mov dx, 0x64
    in al, dx
    test al, 1b
    jz .done
    
    ; read code
    mov dx, 0x60
    in al, dx
    
    
    ; This is an ack, ignore it
    cmp al, 0xFA
    je .start_read
    ; special key byte (is followed by 1 other byte)
    cmp al, 0xe0
    je .set1
    ; same as e0, should not appear in page 1, but checked for anyways
    cmp al, 0xf0
    je .set1
    ; special key byte (is followed by 2 other bytes)
    cmp al, 0xe1
    je .set2
    
    jmp .no_skip
    
    .set1:
    mov cx, 1
    jmp .skip_read
    .set2:
    mov cx, 2
    
    ; throw out unsupported scans
    .skip_read:
    call keyboard_hang_read_ready
    in al, dx
    loop .skip_read
    jmp .start_read
    
    .no_skip:
    ; bit 7 means released
    test al, 128
    jz .pressed
    
    mov ecx, 0
    and eax, 0x7f
    jmp .update
    .pressed:
    mov ecx, 1
    
    .update:
    ;xchg bx, bx
    mov edx, key_is_pressed
    add edx, eax
    dec edx
    mov byte [edx], cl
    
    mov al, cl
    
    jmp .start_read
    
    .done:
    pop ecx
    pop eax
    pop edx
    ret
    
    
init_keyboard:
    ; Init keyboard to scancode set 2
    ; doesn't work so code page 1 is set isntead to 100% make sure that is in use
    ; I think it's broken so we won't even bother
    push edx
    push eax
    
    ; set status register so commands goto devices
    mov dx, 0x64
    in al, dx
    and al, 11110111b
    out dx, al
    
    call keyboard_hang_write_ready
    
    ; set scancode command
    .redo_com:
    mov dx, 0x60
    mov al, 0xf0
    out dx, al
    
    call keyboard_hang_read_ready
    in al, dx
    call printbyte
    cmp al, 0xFE
    je .redo_com
    
    
    call keyboard_hang_write_ready
    
    ; set scancode 2
    .redo_com2:
    mov al, 2
    out dx, al
    
    call keyboard_hang_read_ready
    in al, dx
    call printbyte
    cmp al, 0xFE
    je .redo_com2
    
    
    pop eax
    pop edx
    ret

getcontrollerstatus:
    push edx
    mov dx, 0x64
    in al, dx
    pop edx
    ret

testread:
    push edx
    mov dx, 0x64
    in al, dx
    
    test al, 1b
    jz .noread
    
    .read:
    mov dx, 0x60
    in al, dx
    clc
    jmp .done
    
    .noread:
    stc
    
    .done:
    pop edx
    ret

%endif
