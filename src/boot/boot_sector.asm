; boot.asm
[ORG 0x7c00] ; set code offset to 0x7c00(where the bootloader is loaded)
BITS 16

code_start:
xor ax, ax ; zero ax
mov ds, ax ; set data offset to 0 (needed for the org directive to work)
mov ss, ax
mov sp, 0xFFFF ; move stack 2000h past code start

cld ; clear direction flag

call cls

mov si, loading ; ds:si is loaded with address of string
call sprint

; Got through the check by first checking master then slave
; For any questions on ATA PIO please refer to https://wiki.osdev.org/ATA_PIO_Mode
checkdrive:
mov al, [drive] ; load master or slave drive id
mov dx, 0x1f6 ; Drive select port/register
out dx, al ; set drive
; clear sectorcount, LBAlo, mid, and hi registers
; this is needed to issue the IDENTIFY command to the ATA Controller
; ATA Controller is a legacy chipset that allows access to HDDs
; Many modern devices run in compatibility mode on boot
xor ax, ax
mov dx, 0x1f2 ; sector count
out dx, al
inc dx ; 0x1f3 lba low
out dx, al
inc dx ; 0x1f4 lba mid
out dx, al
inc dx ; 0x1f5 ;ba high
out dx, al
; send command
mov dx, 0x1f7 ; Command register (when written to)
mov al, 0xec ; IDENTIFY command
out dx, al ; Send command
in al, dx ; 0x1f7 is also the status register when read
test al, al ; if it is 0 or 0xFF then there is no disk
jz nodisk
cmp al, 0xFF ;
jz nodisk

; wait untill not busy
isbusy:
in al, dx
test al, 0x80
jnz isbusy


; check if drive detected is ata
mov dx, 0x1f4
in al, dx
inc dx ; 0x1f5
mov ah, al
in al, dx
test ax, ax ; If it is not 0, then it is not a pure ata device
jnz nodisk ; enter fail state


; wait for ready or err
mov dx, 0x1f7
waitstatus:
in al, dx
test al, 1001b
jz waitstatus

test al, 1000b ; If error enter fail state
jz nodisk

; Read identity
mov dx, 0x1f0 ; Set to ATA PIO data RW port
; Set output address to 0x7E00:0000
mov ax, 0x7E0
mov es, ax
xor di, di
; Read
mov cx, 256 ; data transfer for ATA PIO is done in 256 word sized chunks or 512 bytes
rep insw

mov di, 83*2 ; move to an offset in the read data
test word [es:di], 10000000000b ; Check to see if LBA 48 is supported
jz hang ; If not, fail (we have limited the scope, this may cause it to not owrk on certain VMs)

mov si, loading
call sprint

; enable LBA, 48 only
mov al, 0xE0
mov dx, 0x1f6
out dx, al

;Set output address to 0x7E00:0000 (right after boot sector)
mov ax, 0x7E0
mov es, ax
xor di, di

; This reads the rest of the protected sectors as mentioned in the FAT header
mov ebx, 1 ; Start Sector
mov cx, 7 ; How many sectors to read
call read_sector

; By loading the rest of the data right after the boot sector, they now act like a single program and can access data from each other using fixed adresses

; Here we verify this is indeed true by checking if a magic value is in ram after the bootloader
xor ax, ax
mov es, ax
mov ds, ax

mov si, magic_check
mov di, magic ; es:di = es << 8 + di
CMPSD

jne no_magic

; If all is well, jump out of the first secotr to the rest of the loading code
jmp stage_2

no_magic:
mov si, missing_magic
call sprint
nodisk: ; If master failed, switch to slave and restart verify.
    cmp byte [drive], 0xB0
    je endboot
    mov byte [drive], 0xB0
endboot:
    mov si, err
    call sprint

; Enter a hang state
hang:
    jmp hang

; 48 LBA mode only
; 32 bit address only
; cx sectorcount 2 1
; ebx 32 bit address ; 4 3 2 1
; byte 5, 6 will be 0
; es:di is output address
; dx and ax are used
read_sector:
    mov dx, 0x1f2
    mov al, ch
    out dx, al ; sector count high byte
    
    bswap ebx ; Current order: 1 2 3 4
    
    inc dx
    mov al, bl ; send byte 4
    out dx, al
    
    inc dx
    xor ax,ax ; send byte 5
    out dx, al
    
    inc dx
    out dx, al ; send byte 6
    
    add dx, -3
    mov al, cl
    out dx, al ; sector count low byte
    
    mov ah, bh
    bswap ebx ; Current order: 4 3 2 1
    
    inc dx
    mov al, bl ; send byte 1
    out dx, al
    
    inc dx
    mov al, bh ; send byte 2
    out dx, al
    
    inc dx
    mov al, ah ; send byte 3
    out dx, al
    
    add dx, 2 ; 0x1f7
    mov al, 0x24 ; Issue LBA 48 read
    out dx, al
    
    mov bx, cx ; move sector count to bx
    .check:
    ; A 400ms delay is needed before what the status says is accurate
    ; a read causes roughly 100ms of delay
    mov cx, 4
    .delay:
    in al, dx
    loop .delay
    
    ; Error check taken from osdev PIO
    .readnotready:
    in al, dx
    test al, 1000b ; 0x80
    jz .readnotready ; (if busy)
    test al, 8
    jne .read_data ; If Data ready
    test al, 0x21
    jne .fail ; If error
    
    .read_data:
    sub dx, 7 ; 0x1f0
    mov cx, 256
    rep insw ; read 256 words
    dec bx ; decrease remaining sectors
    add dx, 7 ; set back to 0x1f7
    test bx, bx ; see if we are done
    jnz .check ; redo status check
    jmp .done
    
    .fail:
    mov si, err
    call sprint
    
    .done:
    ret

    
cls:
    pusha ; save registers
    mov ax, 0xb800 ; point to text memory
    mov es, ax
    mov cx, 25*80 ; how many characters there are
    xor ax, ax
    mov di, ax ; set index to 0
    rep stosw ; write 0s to all characters
    popa
    ret

sprint:
    pusha ; save registers
    mov ax, 0xb800
    mov es, ax ; point to text memory
    
    ;set dest
    mov ax, word [cpos] ; loads previouse cursor pos
    mov di, ax
    
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
            mov di, ax ; set output pos
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
    call cls
    ; Set offset to 0
    xor bx, bx
    mov word [cpos], bx
    mov di, bx
    .noscroll:
    ; load next char into al
    lodsb
    ; If 0, done
    cmp al, 0
    jne .sprintloop
    popa
    ret
    


loading db "Load",10,0
err db "E: chck dsk",0
missing_magic db "No Magic",10,0
cpos dw 0
drive db 0xA0
lba48 db 0
magic_check db "MMLD"
times 510-($-$$) db 0 ; Fill remaining 512 bytes with 0
; Boot signature, needed by BIOS to detect boot sector
db 0x55
db 0xAA
; End of 512 byte boot sector

; Stage 2
magic db "MMLD"
stage_2:
mov si, stage_2_msg
call sprint

cli ; disable inturrupts to be safe
; actually just never reenable them cause it breaks something idk

; load gdt descriptor
setup_gdt:
    lgdt [gdt_des]
    mov si, gdt_done
    call sprint

; allows for access to higher memory
enable_a20:
    ; check a20
    in al, 0x92
    test al, 2
    jnz .done
    
    ; try bios
    mov     ax, 2401h
    int     15h
    
    ; check a20
    in al, 0x92
    test al, 2
    jnz .done
    
    ; try fast a20
    in al, 0x92
    or al, 2
    and al, 0xFE
    out 0x92, al
    
    ; check a20
    in al, 0x92
    test al, 2
    jnz .done
    
    .fail:
    mov si, a_fail
    call sprint
    jmp stage_2_hang
    
    .done:
    mov si, a_success
    call sprint

; this + A20 allows for full 32 bit addressing
move_to_protected:
; set video mode to VGA mode 0x13
    mov ax, 0x13
    int 0x10

    mov eax, cr0 
    or al, 1       ; set PE (Protection Enable) bit in CR0 (Control Register 0)
    mov cr0, eax
    
    jmp 0x08:protection_starts

    
BITS 32


; copy of 16 bit code as it needs to be reassembled in 32 bit format


; 48 LBA mode only
; 32 bit address only
; cx sectorcount 2 1
; ebx 32 bit address ; 4 3 2 1
; byte 5, 6 will be 0
; edi is output address
; dx and ax are used
read_sector32:
    mov dx, 0x1f2
    mov al, ch
    out dx, al ; sector count high byte
    
    bswap ebx ; Current order: 1 2 3 4
    
    inc dx
    mov al, bl ; send byte 4
    out dx, al
    
    inc dx
    xor ax,ax ; send byte 5
    out dx, al
    
    inc dx
    out dx, al ; send byte 6
    
    add dx, -3
    mov al, cl
    out dx, al ; sector count low byte
    
    mov ah, bh
    bswap ebx ; Current order: 4 3 2 1
    
    inc dx
    mov al, bl ; send byte 1
    out dx, al
    
    inc dx
    mov al, bh ; send byte 2
    out dx, al
    
    inc dx
    mov al, ah ; send byte 3
    out dx, al
    
    add dx, 2 ; 0x1f7
    mov al, 0x24 ; Issue LBA 48 read
    out dx, al
    
    mov bx, cx ; move sector count to bx
    .check:
    ; A 400ms delay is needed before what the status says is accurate
    ; a read causes roughly 100ms of delay
    mov cx, 4
    .delay:
    in al, dx
    loop .delay
    
    ; Error check taken from osdev PIO
    .readnotready:
    in al, dx
    test al, 1000b ; 0x80
    jz .readnotready ; (if busy)
    test al, 8
    jne .read_data ; If Data ready
    test al, 0x21
    jne .fail ; If error
    
    .read_data:
    sub dx, 7 ; 0x1f0
    mov cx, 256
    rep insw ; read 256 words
    dec bx ; decrease remaining sectors
    add dx, 7 ; set back to 0x1f7
    test bx, bx ; see if we are done
    jnz .check ; redo status check
    clc
    jmp .done
    
    .fail:
    stc
    mov esi, err
    call sprint32
    
    .done:
    ret
 
 cls32:
    pusha ; save registers
    mov edi, 0xb8000 ; point to text memory
    mov cx, 25*80 ; how many characters there are
    xor eax, eax
    rep stosw ; write 0s to all characters
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

; entry point to protected mode
protection_starts:
    ; Init data segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x40000000
    ;sti, don't enable interupts, breaks
    mov esi, p_success
    call sprint32
    
    ; Read 
    mov ebx, 8 ; Start Sector
    mov cx, 1 ; How many sectors to read
    mov edi, 0x01000000 ; 16mb, after theoretical ISA memory hole
    call read_sector32
    
    ; get read value
    mov eax, [0x01000000]
    mov dword [prog_sec_count], eax
    
    ; read 255 sectors at a time
    mov edi, 0x01000000
    .read_more:
        cmp dword [prog_sec_count], 255
        jbe .no_adjust
        sub dword [prog_sec_count], 255
        mov ecx, 255
        jmp .do_read
        .no_adjust:
        mov ecx, dword [prog_sec_count]
        mov dword [prog_sec_count], 0
        
        .do_read:
        mov ebx, dword [prog_sec_track]
        add dword [prog_sec_track], ecx
        
        call read_sector32
        
        cmp dword [prog_sec_count], 0
        jnz .read_more
    
    ; jump to start of main program
    jmp 0x8:0x01000000
        
    .read_failed:
    mov esi, read_fail
    call sprint32
        
        
stage_2_hang:
    mov esi, general_error
    hlt
    jmp stage_2_hang

BITS 16
;;;;;;;;
stage_2_msg db "Welcome to outside the boot sector!",10,0
gdt_done db "GDT Loaded",10,0
a_fail db "A20 Failed",10,0
a_success db "A20 Succesfull",10,0
p_success db "Protected Succesfull",10,0
read_fail db "Read Failed",10,0

general_error db "Error, entered hang loop. Shouldn't be here.",10,0

prog_sec_count dd 0
prog_sec_track dd 9 ; sector after bootloader and sector count

; limit 0-15, base 0-15, base 16-23, accessbyte, flags+limit 16-19, base 16-23
gdt db 0,0,0,0,0,0,0,0, ; null entry
    db 0xFF,0xFF, 0,0,0, 10011110b, 11001111b, 0 ; flat code segment
    db 0xFF,0xFF, 0,0,0, 10010010b, 11001111b, 0 ; flat data segment
    dw 0xFFFF ; flat code segment 16
    db 0,0,0, 10011110b, 10000000b, 0 
    dw 0xFFFF ; flat data segment 16
    db 0,0,0, 10010010b, 10000000b, 0 
    ; db 0,0,0,0,0,0,0,0, ; maybe put an TSS here?
gdt_size equ ( $-gdt - 1)

gdt_des dw gdt_size
        dd gdt

times 4096-($-$$) db 0
