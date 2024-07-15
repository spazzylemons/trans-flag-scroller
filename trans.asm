; Transgender Boot Sector -- (c) 2024 spazzylemons
; Licensed under MIT.

cpu 8086

; Boot sector starts here.
org 0x7c00

; This is where the row buffers will be stored.
; TODO better explanation for how this works
row_buffers equ 0x6000
; Other variables are stored directly in code to save space.
bit_index     equ bit_index_ins     + 1
byte_index    equ byte_index_ins    + 1
column_pixel  equ column_pixel_ins  + 1
char_column   equ char_column_ins   + 1
message_index equ message_index_ins + 1
last_clock    equ last_clock_ins    + 2

start:
    ; Turn off interrupts while we set up the segments.
    cli
    ; Set direction for string instructions.
    cld
    ; Set segments.
    xor ax, ax
    mov ss, ax
    mov ds, ax
    ; Define our stack.
    mov sp, 0x7bff
    ; Enable interrupts now that we're ready.
    sti
    ; Enter CGA.
    mov ax, 0x04
    int 0x10
    ; Set VGA palette for better appearance on VGA cards.
    mov si, colors
    mov dx, 0x3c8
set_vga_colors:
    ; Read palette index.
    lodsb
    ; If zero, stop.
    or al, al
    jz init_row_buffers
    ; Write palette index.
    out dx, al
    ; Move to data port.
    inc dx
    mov cl, 3
    ; If we weren't targeting 8086, we could do a rep outsb.
.write:
    lodsb
    out dx, al
    loop .write
    dec dx
    jmp set_vga_colors
init_row_buffers:
    ; Initialize our buffers.
    mov al, 0xff
    mov cx, 6400
    push ds
    pop es
    mov di, row_buffers
    rep stosb
    ; Draw the flag pattern in both halves of the screen.
    mov ax, 0xb800
    call draw_flag_pattern
    mov ax, 0xba00
    call draw_flag_pattern
main_loop:
message_index_ins:
    ; Get the current font column byte.
    mov al, 0x00
    mov bx, message
    xlat
char_column_ins:
    add al, 0x00
    mov bx, font - 1
    xlat
    mov dh, al
    ; Loop four times to update each of the four buffers.
    mov cl, 4
    mov bp, row_buffers + 4800
draw_column:
    push cx
    ; Which column should we draw to?
bit_index_ins:
    mov al, 0x00
    sub al, cl
byte_index_ins:
    mov cl, 0x00
    ; If column index exceeds 4, move to next byte in buffer.
    test al, 4
    jz .same_byte
    or cl, cl
    jnz .no_overflow
    mov cl, 80
.no_overflow:
    dec cl
    and al, 3
.same_byte:
    ; Get a pointer to the byte to write to in DI...
    mov di, bp
    add di, cx
    ; ...and the bitmask in AL.
    mov bx, bitmask_lookup
    xlat
    ; Move forward 80 bytes in the buffer with each write.
    mov si, 80
    ; Copy font column byte.
    mov dl, dh
    ; Five bits to read in this byte.
    mov bl, 5
draw_column_loop:
    mov cl, 4
    ; Should we set or clear pixels?
    test dl, dl
    jns .set_pixels
    not al
    ; Clear the pixels using the mask.
.clear_pixels:
    and [di], al
    add di, si
    loop .clear_pixels
    not al
    jmp .end
    ; Set the pixels using the mask.
.set_pixels:
    or [di], al
    add di, si
    loop .set_pixels
.end:
    ; Move to checking next bit.
    shl dl, 1
    dec bl
    jnz draw_column_loop
    ; Move to next buffer.
    sub bp, 1600
    pop cx
    loop draw_column
    ; Copy the buffers to the screen.
    mov ax, 0xb8e1
    call copy_text_to_screen
    mov ax, 0xbae1
    call copy_text_to_screen
update_counters:
    ; Increment bit index, mod 4.
    mov al, [bit_index]
    inc al
    and al, 3
    mov [bit_index], al
    ; Move to next byte in buffers?
    or al, al
    jnz .no_byte_increment
    ; Increment byte index, mod 80.
    mov al, [byte_index]
    inc al
    cmp al, 80
    jnz .no_byte_reset
    xor al, al
.no_byte_reset:
    mov [byte_index], al
.no_byte_increment:
    ; Increment font width counter, mod 4.
column_pixel_ins:
    mov al, 0x00
    inc al
    and al, 3
    mov [column_pixel], al
    ; Should we move to next column in character?
    or al, al
    jnz .end
    ; Increment column index, mod 6.
    mov al, [char_column]
    inc al
    mov cl, al
    ; Should we move to next character?
    cmp al, 6
    jnz .store_char_column
    ; Move to next character.
    xor cl, cl
    mov al, [message_index]
    inc al
    cbw
    mov bx, ax
    ; If character value is zero, reset to beginning.
    cmp cl, [bx + message]
    jnz .not_at_end
    xor al, al
.not_at_end:
    mov [message_index], al
.store_char_column:
    mov [char_column], cl
.end:
    ; Check current BIOS clock.
    xor ah, ah
delay:
    int 0x1a
last_clock_ins:
    cmp dl, 0x00
    ; Loop until clock changes.
    jz delay
    mov [last_clock], dl
    ; Interrupt may have modified CX, so clear high byte just to be safe.
    xor ch, ch
    jmp main_loop

draw_flag_pattern:
    ; Set VRAM segment and offset.
    mov es, ax
    xor di, di
    ; Get pointer to pattern list.
    mov si, patterns
.loop:
    ; Get a pattern byte.
    lodsb
    ; If zero, stop.
    or al, al
    jz return
    ; Copy to VRAM and loop.
    mov cx, 1600
    rep stosb
    jmp .loop

copy_text_to_screen:
    ; Set VRAM segment and offset.
    mov es, ax
    xor di, di
    ; Find the buffer to copy from based on bit index...
    mov bx, di
    mov bl, [bit_index]
    shl bl, 1
    mov si, [bx + row_buffer_lookup]
    ; .. and add byte index.
    mov al, [byte_index]
    cbw
    add si, ax
    ; Copy 10 rows.
    mov al, 10
.loop:
    ; 80 bytes per row.
    mov cl, 40
    rep movsw
    ; Skip the copy.
    add si, 80
    dec al
    jnz .loop
; Shared return statement with draw_flag_pattern to save space.
return:
    ret


; Must preceed a 0 byte so that it is properly null-terminated
patterns:
    db 0x55, 0xaa, 0xff, 0xaa, 0x55

; Font table. Each character is a 5x5 graphic, with an extra empty column to
; make space between characters.
font:
    db 0x00,0x00,0x00,0x00,0x00,0x00 ; ' '
    db 0x38,0x50,0x90,0x50,0x38,0x00 ; 'A'
    db 0xf8,0xa8,0xa8,0xa8,0x88,0x00 ; 'E'
    db 0x70,0x88,0xa8,0xa8,0xb8,0x00 ; 'G'
    db 0xf8,0x20,0x20,0x20,0xf8,0x00 ; 'H'
    db 0x88,0x88,0xf8,0x88,0x88,0x00 ; 'I'
    db 0xf8,0x40,0x20,0x40,0xf8,0x00 ; 'M'
    db 0xf8,0x40,0x20,0x10,0xf8,0x00 ; 'N'
    db 0xf8,0xa0,0xa0,0xa0,0x58,0x00 ; 'R'
    db 0x48,0xa8,0xa8,0xa8,0x90,0x00 ; 'S'
    db 0x80,0x80,0xf8,0x80,0x80,0x00 ; 'T'
    db 0xf0,0x08,0x08,0x08,0xf0,0x00 ; 'U'
    db 0x20,0x20,0x20,0x20,0x20,0x00 ; '-'

; Pre-multiplied offsets into font array
; (plus 1, so that 0 can be the null terminator.)
SPACE equ 1
A equ 7
E equ 13
G equ 19
H equ 25
I equ 31
M equ 37
N equ 43
R equ 49
S equ 55
T equ 61
U equ 67
DASH equ 73

message:
    db T, R, A, N, S
    db SPACE
    db R, I, G, H, T, S
    db SPACE
    db A, R, E
    db SPACE
    db H, U, M, A, N
    db SPACE
    db R, I, G, H, T, S
    db SPACE
    db DASH, DASH, DASH
    db SPACE
    db 0

bitmask_lookup:
    db 0xc0, 0x30, 0x0c, 0x03

; VGA palette indices and values to write.
; Because row_buffer is aligned at least 256 bytes, we can omit the null
; terminator and use the first entry of row_buffer_lookup to null terminate.
colors:
    db 0x13
    db 0x16, 0x33, 0x3e
    db 0x15
    db 0x3d, 0x2a, 0x2e

row_buffer_lookup:
    dw row_buffers
    dw row_buffers + 1600
    dw row_buffers + 3200
    dw row_buffers + 4800

; Boot sector magic.
; We've still got a good amount of space free... could we rearrange this to
; allow a real FAT filesystem to be stored alongside this disk?
times 510-($-$$) db 0
db 0x55,0xaa
