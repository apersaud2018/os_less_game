%ifndef CONSOLE_INC
%define CONSOLE_INC
cpos dw 0
hexstring db "0123456789ABCDEF"

cls32:
    pusha ; save registers
    mov edi, 0xb8000 ; point to text memory
    mov cx, 25*80 ; how many characters there are
    xor eax, eax
    rep stosw ; write 0s to all characters
    popa
    ret
 
cprint32:
    ;input al
    pusha ; save registers
    ; point to text memory
    ;set dest
    mov cx, ax
    mov ax, word [cpos] ; loads previouse cursor pos
    movzx edi, ax
    add edi, 0xb8000
    
    mov ah, 0x0a ; set display format (black bg with green fg)
    mov al, cl
    .sprintloop:
    ;if
            cmp al, 10 ; there is a newline
            jne .notnewline
            add word [cpos], 160 ; add line width
            mov cx, ax ; save char
            mov ax, word [cpos]
            xor dx, dx
            mov bx, 160
            div bx ; integer division
            mul bx ; multiplying back gives the line offset to the left side of the line
            mov word [cpos], ax ; save new offset
            movzx edi, ax ; set output pos
            add edi, 0xb8000
            mov ax, cx ; restore char
            jmp .endprintif
        .notnewline:
        ;else
            stosw ; if not newline write char (it is a word due to Format + Char)
            add word [cpos], 2 ; incriment offset
        .endprintif:
    ; Check if we are at end of screen
    mov bx, word [cpos]
    cmp bx, 25*160
    jl .noscroll
    ; If we are, clear screen
    call cls32
    ; Set offset to 0
    xor bx, bx
    mov word [cpos], bx
    movzx edi, bx
    add edi, 0xb8000
    .noscroll:
    popa
    ret
 
sprint32:
    pusha ; save registers
    ; point to text memory
    ;set dest
    mov ax, word [cpos] ; loads previouse cursor pos
    movzx edi, ax
    add edi, 0xb8000
    
    ;write loop
    lodsb ; load char into al from ds:si
    mov ah, 0x0a ; set display format (black bg with green fg)
    .sprintloop:
    ;if
            cmp al, 10 ; there is a newline
            jne .notnewline
            add word [cpos], 160 ; add line width
            mov cx, ax ; save char
            mov ax, word [cpos]
            xor dx, dx
            mov bx, 160
            div bx ; integer division
            mul bx ; multiplying back gives the line offset to the left side of the line
            mov word [cpos], ax ; save new offset
            movzx edi, ax ; set output pos
            add edi, 0xb8000
            mov ax, cx ; restore char
            jmp .endprintif
        .notnewline:
        ;else
            stosw ; if not newline write char (it is a word due to Format + Char)
            add word [cpos], 2 ; incriment offset
        .endprintif:
    ; Check if we are at end of screen
    mov bx, word [cpos]
    cmp bx, 25*160
    jl .noscroll
    ; If we are, clear screen
    call cls32
    ; Set offset to 0
    xor bx, bx
    mov word [cpos], bx
    movzx edi, bx
    add edi, 0xb8000
    .noscroll:
    ; load next char into al
    lodsb
    ; If 0, done
    cmp al, 0
    jne .sprintloop
    popa
    ret

printbyte:
    pusha
    mov ecx, eax
    
    movzx ebx, cl
    and bl, 11110000b
    shr bl, 4
    add ebx, hexstring
    mov al, byte [ebx]
    
    call cprint32
    
    movzx ebx, cl
    and bl, 1111b
    add ebx, hexstring
    mov al, byte [ebx]
    
    call cprint32
    
    popa
    ret
%endif