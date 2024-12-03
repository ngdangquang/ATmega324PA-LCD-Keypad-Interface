.include "m324padef.inc"                
.org 0x0000                              
rjmp reset_handler                       

; Define LCD control and data lines 
.equ LCDPORT = PORTA              
.equ LCDPORTDIR = DDRA               
.equ LCDPORTPIN = PINA               
.equ LCD_RS = PINA0       ; LCD_RS = PA0
.equ LCD_RW = PINA1       ; RW = PA1
.equ LCD_EN = PINA2       ; EN = PA2
.equ LCD_D7 = PINA7       ; PA7
.equ LCD_D6 = PINA6       ; PA6
.equ LCD_D5 = PINA5       ; PA5
.equ LCD_D4 = PINA4       ; PA4

.def LCDData = r16 

reset_handler: 
    CALL LCD_Init                   
    SER R16 
    OUT DDRD, R16                  ; Set PORTD (BAR LED) as output 
    
    LDI ZL, 0                      ; Initialize Z pointer for SRAM 
    LDI ZH, 7 
 
    LDI R16, $30                   ; ASCII offset for digits ('0') 
    MOV R10, R16                   ; Store in R10 
    LDI R16, $37                   ; ASCII offset for letters ('7') 
    MOV R11, R16                   ; Store in R11 
 
    CLR R15                        ; Null terminator for strings 
 
start: 
    CALL KEY_PAD_SCAN              ; Scan the keypad 
    MOV R24, R23                   ; Move scanned key to R24 
    OUT PORTD, R24                 ; Output to BAR LED on PORTD 
 
    CPI R24, 0xFF                  ; Check if no key pressed 
    BREQ CLEAR 
    CPI R24, 10                    ; Check if key is a digit (0-9) 
    BRCC ALPHA                      ; If key >= 10, it's an alpha key 
 
    ADD R24, R10                   ; Convert to ASCII digit 
    ST Z+, R24                     ; Store character in SRAM 
    ST Z, R15                      ; Null-terminate the string 
 
    LDI ZL, 0                      ; Reset Z pointer to start of string 
    LDI ZH, 7 
 
    CLR R16                        ; Row 0 
    CLR R17                        ; Column 0 
    CALL LCD_Move_Cursor           ; Move cursor to start position 
    CALL LCD_Send_String           ; Display string on LCD 
    RJMP start                      ; Repeat the loop 
 
ALPHA: 
    ADD R24, R11                   ; Convert to ASCII letter 
    ST Z+, R24                     ; Store character in SRAM 
    ST Z, R15                      ; Null-terminate the string 
 
    LDI ZL, 0                      ; Reset Z pointer to start of string 
    LDI ZH, 7 
 
    CLR R16                        ; Row 0 
    CLR R17                        ; Column 0 
    CALL LCD_Move_Cursor           ; Move cursor to start position 
    CALL LCD_Send_String           ; Display string on LCD 
    RJMP start 
 
CLEAR: 
    LDI R16, 0x01                  ; Clear Display command  
    CALL LCD_Send_Command 
    RJMP start 
 
LCD_Init: 
    ; Set up data direction register for PORTA 
    LDI R16, 0b11110111            ; Set PA7-PA4, PA2-PA0 as outputs 
    OUT LCDPORTDIR, R16 
    ; Wait for LCD to power up 
    CALL DELAY_10MS 
    CALL DELAY_10MS 
         
    ; Send initialization sequence 
    LDI R16, 0x02                  ; Function Set: 4-bit interface 
    CALL LCD_Send_Command 
    LDI R16, 0x28                  ; Function Set: 2 lines, 5x7 dots 
    CALL LCD_Send_Command 
    LDI R16, 0x0C                  ; Display Control: Display ON, Cursor OFF 
    CALL LCD_Send_Command 
    LDI R16, 0x01                  ; Clear Display 
    CALL LCD_Send_Command 
    LDI R16, 0x80                  ; Set DDRAM address to 0x00 
    CALL LCD_Send_Command 
    RET 
 
LCD_Send_Command: 
    PUSH R17 
    CALL LCD_wait_busy             ; Check if LCD is busy  
    MOV R17, R16                   ; Save the command 
    ; Set RS=0 (Command mode), RW=0 (Write mode) 
    ANDI R17, 0xF0                 ; Send higher nibble first 
    ; Send command to LCD 
    OUT LCDPORT, R17 
    NOP 
    NOP 
    ; Pulse enable pin 
    SBI LCDPORT, LCD_EN 
    NOP 
    NOP 
    CBI LCDPORT, LCD_EN 
    SWAP R16                       ; Prepare lower nibble 
    ANDI R16, 0xF0 
    ; Send command to LCD 
    OUT LCDPORT, R16 
    ; Pulse enable pin 
    SBI LCDPORT, LCD_EN 
    NOP 
    NOP 
    CBI LCDPORT, LCD_EN 
    POP R17 
    RET 
 
LCD_Send_Data: 
    PUSH R17 
    CALL LCD_wait_busy             ; Check if LCD is busy 
    MOV R17, R16                   ; Save the data 
    ; Set RS=1 (Data mode), RW=0 (Write mode) 
    ANDI R17, 0xF0 
    ORI R17, 0x01 
    ; Send data to LCD 
    OUT LCDPORT, R17 
    NOP 
    ; Pulse enable pin 
    SBI LCDPORT, LCD_EN 
    NOP 
    CBI LCDPORT, LCD_EN 
    ; Send lower nibble 
    NOP 
    SWAP R16 
    ANDI R16, 0xF0 
    ; Set RS=1 (Data mode), RW=0 (Write mode) 
    ANDI R16, 0xF0 
    ORI R16, 0x01 
    ; Send data to LCD 
    OUT LCDPORT, R16 
    NOP 
    ; Pulse enable pin 
    SBI LCDPORT, LCD_EN 
    NOP 
    CBI LCDPORT, LCD_EN 
    POP R17 
    RET 
 
LCD_Move_Cursor: 
    CPI R16, 0                     ; Check if first row 
    BRNE LCD_Move_Cursor_Second 
    ANDI R17, 0x0F 
    ORI R17, 0x80 
    MOV R16, R17 
    ; Send command to LCD 
    CALL LCD_Send_Command 
    RET 
 
LCD_Move_Cursor_Second: 
    CPI R16, 1                     ; Check if second row 
    BRNE LCD_Move_Cursor_Exit      ; Else exit 
    ANDI R17, 0x0F 
    ORI R17, 0xC0 
    MOV R16, R17 
    ; Send command to LCD 
    CALL LCD_Send_Command 
LCD_Move_Cursor_Exit: 
    ; Return from function 
    RET 
 
LCD_Send_String: 
    PUSH ZH                          ; Preserve pointer registers 
    PUSH ZL 
    PUSH LCDData 
 
LCD_Send_String_01: 
    LD LCDData, Z+                 ; Get a character 
    CPI LCDData, 0                  ; Check for end of string 
    BREQ LCD_Send_String_02          ; Done 
 
    ; Arrive here if this is a valid character 
    CALL LCD_Send_Data               ; Display the character 
    RJMP LCD_Send_String_01          ; Not done, send another character 
 
LCD_Send_String_02: 
    POP LCDData 
    POP ZL                          ; Restore pointer registers 
    POP ZH 
    RET 
 
LCD_wait_busy: 
    PUSH R16 
    ; Set PA7-PA4 as inputs, PA2-PA0 as outputs 
    LDI R16, 0b00000111 
    OUT LCDPORTDIR, R16 
    ; Set RS=0, RW=1 for reading busy flag 
    LDI R16, 0b11110010 
    OUT LCDPORT, R16 
    NOP 
LCD_wait_busy_loop: 
    SBI LCDPORT, LCD_EN 
    NOP 
    NOP 
    IN R16, LCDPORTPIN 
    CBI LCDPORT, LCD_EN 
    NOP 
    ; Read lower nibble (ignored) 
    SBI LCDPORT, LCD_EN 
    NOP 
    NOP 
    CBI LCDPORT, LCD_EN 
    NOP 
    ANDI R16, 0x80                   ; Mask busy flag 
    CPI R16, 0x80 
    BREQ LCD_wait_busy_loop 
    ; Set PA7-PA4 as outputs, PA2-PA0 as outputs 
    LDI R16, 0b11110111 
    OUT LCDPORTDIR, R16 
    ; Set RS=0, RW=0 for command mode 
    LDI R16, 0b00000000 
    OUT LCDPORT, R16 
    POP R16 
    RET 
 
DELAY_10MS: 
    LDI R16, 10 
LOOP2: 
    LDI R17, 250 
LOOP1: 
    NOP 
    DEC R17 
    BRNE LOOP1 
    DEC R16 
    BRNE LOOP2 
    RET 
 
KEY_PAD_SCAN: 
    ; PB0-PB3: OUTPUT (Columns) 
    ; PB4-PB7: INPUT (Rows) 

    LDI R16, 0x0F                  ; Set PB0-PB3 as outputs, PB4-PB7 as inputs 
    OUT DDRB, R16 

    LDI R16, 0xF0                  ; Activate pull-ups on PB4-PB7 
    OUT PORTB, R16 

    LDI R22, 0b11111110            ; Initial column mask (column 0 active low) 
    LDI R24, 0                     ; Column index (0-3) 

KEYPAD_SCAN_LOOP: 
    OUT PORTB, R22                 ; Output column pattern 
    NOP 
    NOP 
    SBIC PINB, 4                    ; Check row 0 
    RJMP CHECK_ROW_1 
    LDI R23, 0                     ; Row 0 is pressed 
    RJMP KEYPAD_SCAN_FOUND 

CHECK_ROW_1: 
    SBIC PINB, 5                    ; Check row 1 
    RJMP CHECK_ROW_2 
    LDI R23, 1                     ; Row 1 is pressed 
    RJMP KEYPAD_SCAN_FOUND 

CHECK_ROW_2: 
    SBIC PINB, 6                    ; Check row 2 
    RJMP CHECK_ROW_3 
    LDI R23, 2                     ; Row 2 is pressed 
    RJMP KEYPAD_SCAN_FOUND 

CHECK_ROW_3: 
    SBIC PINB, 7                    ; Check row 3 
    RJMP NEXT_COLUMN 
    LDI R23, 3                     ; Row 3 is pressed 
    RJMP KEYPAD_SCAN_FOUND 

NEXT_COLUMN: 
    INC R24                        ; Increment column index 
    CPI R24, 4 
    BRGE KEYPAD_SCAN_NOT_FOUND      ; All columns scanned 
    LSL R22                        ; Shift zero left to activate next column 
    ORI R22, 0x01                  ; Keep PB4-PB7 high (pull-ups) 
    RJMP KEYPAD_SCAN_LOOP 

KEYPAD_SCAN_FOUND: 
    ; Combine row and column to get key value (0-15) 
    LSL R23                        ; Multiply row by 4 
    LSL R23 
    ADD R23, R24                   ; Add column index 
    MOV R24, R23                   ; Move result to R24 
    RET 

KEYPAD_SCAN_NOT_FOUND: 
    LDI R24, 0xFF                  ; No key pressed 
    RET 
 
BUTTON: 
    LDI R17, 50 
DEBOUNCING_1: 
    IN R16, PINB 
    CPI R16, 0xFF                  ; Detect status of buttons 
    BREQ DEBOUNCING_1               ; If no button pressed, loop 
    DEC R17 
    BRNE DEBOUNCING_1 
    RET
