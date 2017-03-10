.include "m128def.inc"; Include definition file
;ROBOT
;***********************************************************
;*Internal Register Definitions and Constants
;***********************************************************
.deffreeze_counter = r23
.defmpr = r16; Multi-Purpose Register
.defaddr_flag = r17; 1 if address matched, 0 otherwise
.def    sent_freeze = r18
.defwaitcnt = r19
.defilcnt = r20
.defolcnt = r21
.defprev_move = r22
.equWTime2 = 200
.equWTime = 100
.equWskrR = 0; Right Whisker Input Bit
.equWskrL = 1; Left Whisker Input Bit
.equEngEnR = 4; Right Engine Enable Bit
.equEngEnL = 7; Left Engine Enable Bit
.equEngDirR = 5; Right Engine Direction Bit
.equEngDirL = 6; Left Engine Direction Bit
.equBotAddress = 0b00000111;smart receiver address
;.equBotAddress = 0b01000111;dummy receiver address
; Macros listed: values to make the TekBot Move.
.equMovFwd =  (1<<EngDirR|1<<EngDirL);0b01100000 Move Forward Action Code
.equMovBck =  $00;0b00000000 Move Backward Action Code
.equTurnR =   (1<<EngDirL);0b01000000 Turn Right Action Code
.equTurnL =   (1<<EngDirR);0b00100000 Turn Left Action Code
.equHalt =    (1<<EngEnR|1<<EngEnL);0b10010000 Halt Action Code
;***********************************************************
;*Start of Code Segment
;***********************************************************
.cseg; Beginning of code segment
;***********************************************************
;*Interrupt Vectors
;***********************************************************
.org$0000; Beginning of IVs
rjmp INIT; Reset interrupt
.org $0002; {IRQ0 => pin0, PORTD}
rcall HitRight        ; Call hit right function
reti                    ; Return from interrupt
.org $0004; {IRQ1 => pin1, PORTD}
rcall HitLeft         ; Call hit left function
reti                   ; Return from interrupt
.org $003C; RXD1 vector => pin2, PORTD
rcall receive
reti
.org$0046; End of Interrupt Vectors
;***********************************************************
;*Program Initialization
;***********************************************************
INIT:
; Initialize Stack Pointer
ldi mpr, high(RAMEND)
out SPH, mpr
ldi mpr, low(RAMEND)
out SPL, mpr
; Configure I/O ports
ldi mpr, 0b11111111
out DDRB, mpr
; Initialize Port D for input
ldi mpr, 0b00000000
out DDRD, mpr ; Set the DDR register for Port D
ldi mpr, (1<<WskrL)|(1<<WskrR)
out PORTD, mpr ; Set the Port D to Input with Hi-Z
; Enable USART1 at double transmission spd
ldi mpr, (1<<U2X1)
sts UCSR1A, mpr
; Baudrate = 2400
ldi mpr, high(832)
sts UBRR1H, mpr
ldi mpr, low(832)
sts UBRR1L, mpr
; Set frame formats: 8 data, 2 stop bits, asynchronous
ldi mpr, (0<<UMSEL1)|(1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
sts UCSR1C, mpr
; Enable both receiver and transmitter, and receive interrupt
ldi mpr, (1<<RXEN1)|(1<<TXEN1)|(1<<RXCIE1)
;ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
; Set the Interrupt Sense Control to falling edge
ldi mpr, (1<<ISC01)|(0<<ISC00 )|(1<<ISC11)|(0<<ISC10)|(1<<ISC21)|(0<<ISC20)
sts EICRA, mpr ; Use sts, EICRA in extended I/O space
; Set the External Interrupt Mask
ldi mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)
out EIMSK, mpr
; Initialize Fwd Movement
ldi mpr, MovFwd
mov prev_move, mpr
out PORTB, mpr
ldi freeze_counter,0
; Turn on interrupts
sei

;***********************************************************
;*Main Program
;***********************************************************
MAIN:
rjmpMAIN
;***********************************************************
;*Functions and Subroutines
;***********************************************************
receive:
push  mpr
;in  prev_move, PINB
lds   mpr, UDR1
sbrc  mpr, 7;if byte is an address, skip
breq  command;if byte is an action, go to command
ldi   addr_flag, 0;clear address flag
cpi   mpr, 0b01010101
breq  Frozen; in incoming signal is a freeze, go to Frozen
cpi   mpr, BotAddress
brne  end_receive;if address doesn't match, go to end receive
ldi   addr_flag, 1;if address does match, set the address flag
jmp   end_receive
command:
tst   addr_flag
breq  end_receive
rcall exec_command
ldi   addr_flag, 0
jmp  end_receive
Frozen:
;disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
inc freeze_counter
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
jmp   Frozen
ldi   mpr, Halt
out   PORTB, mpr
ldi   addr_flag, 0
;call out waiting function to freeze movement
ldi   waitcnt, WTime
rcall wait
ldi   waitcnt, WTime2
rcall wait
ldi   waitcnt, WTime2
rcall wait
cpi freeze_counter, 3
brne im_alive

im_dead:
rjmp im_dead
im_alive:
ldi mpr, (1<<INT0 | 1<<INT1)
out EIFR, mpr
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
jmp  end_receive
end_receive:
out   PORTB, prev_move
pop   mpr
ret
exec_command:
push  mpr
; Check for freeze command
cpimpr, 0b11111000
brneother_command
rcallTx_Freeze
jmpend_exec
other_command:
lsl   mpr
mov   prev_move, mpr
end_exec:
pop   mpr
ret
Tx_Freeze:
pushmpr
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
Transmission_Freeze:
lds   mpr, UCSR1A
; Check if buffer is empty
sbrs  mpr, UDRE1
rjmp  Transmission_Freeze
ldi   mpr, 0b01010101
sts   UDR1, mpr
ldi   sent_freeze, 1
freeze_wait:
lds   mpr, UCSR1A
sbrs  mpr, TXC1 ; Check if buffer is empty
jmp freeze_wait
wait_pause:
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
rjmp  wait_pause
receive_wait:
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore mpr
ret; Return from subroutine
HitRight:
push mpr; Save mpr register
push waitcnt; Save wait register
in mpr, SREG; Save program state
push mpr
;disable incoming interrupts
; Disable receiver and it's interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldi mpr, MovBck; Load Move Backward command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 seconds
rcall Wait; Call wait function
; Turn left for a second
ldi mpr, TurnL; Load Turn Left Command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 second
rcall Wait; Call wait function
; Resume previous movement
out PORTB, prev_move; Send command to port
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore program state
out SREG, mpr
pop waitcnt; Restore wait register
pop mpr; Restore mpr
ret; Return from subroutine
HitLeft:
pushmpr; Save mpr register
pushwaitcnt; Save wait register
inmpr, SREG; Save program state
pushmpr

; Disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldimpr, MovBck; Load Move Backward command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 seconds
rcallWait; Call wait function
; Turn right for a second
ldimpr, TurnR; Load Turn Left Command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 second
rcallWait; Call wait function
; Return to Previous Movement
outPORTB, prev_move ; Send command to port
;enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldimpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
stsUCSR1B, mpr
popmpr; Restore program state
outSREG, mpr
popwaitcnt; Restore wait register
popmpr; Restore mpr
ret; Return from subroutine
Wait:
pushwaitcnt; Save wait register
pushilcnt; Save ilcnt register
pusholcnt; Save olcnt register

Loop:ldiolcnt, 224; load olcnt register
OLoop:ldiilcnt, 237; load ilcnt register
ILoop:decilcnt; decrement ilcnt
brneILoop; Continue Inner Loop
decolcnt;decrement olcnt
brneOLoop; Continue Outer Loop
decwaitcnt; Decrement wait 
brneLoop; Continue Wait loop
popolcnt; Restore olcnt register
popilcnt; Restore ilcnt register
popwaitcnt; Restore wait register
ret; Return from subroutine.include "m128def.inc"; Include definition file
;ROBOT
;***********************************************************
;*Internal Register Definitions and Constants
;***********************************************************
.deffreeze_counter = r23
.defmpr = r16; Multi-Purpose Register
.defaddr_flag = r17; 1 if address matched, 0 otherwise
.def    sent_freeze = r18
.defwaitcnt = r19
.defilcnt = r20
.defolcnt = r21
.defprev_move = r22
.equWTime2 = 200
.equWTime = 100
.equWskrR = 0; Right Whisker Input Bit
.equWskrL = 1; Left Whisker Input Bit
.equEngEnR = 4; Right Engine Enable Bit
.equEngEnL = 7; Left Engine Enable Bit
.equEngDirR = 5; Right Engine Direction Bit
.equEngDirL = 6; Left Engine Direction Bit
.equBotAddress = 0b00000111;smart receiver address
;.equBotAddress = 0b01000111;dummy receiver address
; Macros listed: values to make the TekBot Move.
.equMovFwd =  (1<<EngDirR|1<<EngDirL);0b01100000 Move Forward Action Code
.equMovBck =  $00;0b00000000 Move Backward Action Code
.equTurnR =   (1<<EngDirL);0b01000000 Turn Right Action Code
.equTurnL =   (1<<EngDirR);0b00100000 Turn Left Action Code
.equHalt =    (1<<EngEnR|1<<EngEnL);0b10010000 Halt Action Code
;***********************************************************
;*Start of Code Segment
;***********************************************************
.cseg; Beginning of code segment
;***********************************************************
;*Interrupt Vectors
;***********************************************************
.org$0000; Beginning of IVs
rjmp INIT; Reset interrupt
.org $0002; {IRQ0 => pin0, PORTD}
rcall HitRight        ; Call hit right function
reti                    ; Return from interrupt
.org $0004; {IRQ1 => pin1, PORTD}
rcall HitLeft         ; Call hit left function
reti                   ; Return from interrupt
.org $003C; RXD1 vector => pin2, PORTD
rcall receive
reti
.org$0046; End of Interrupt Vectors
;***********************************************************
;*Program Initialization
;***********************************************************
INIT:
; Initialize Stack Pointer
ldi mpr, high(RAMEND)
out SPH, mpr
ldi mpr, low(RAMEND)
out SPL, mpr
; Configure I/O ports
ldi mpr, 0b11111111
out DDRB, mpr
; Initialize Port D for input
ldi mpr, 0b00000000
out DDRD, mpr ; Set the DDR register for Port D
ldi mpr, (1<<WskrL)|(1<<WskrR)
out PORTD, mpr ; Set the Port D to Input with Hi-Z
; Enable USART1 at double transmission spd
ldi mpr, (1<<U2X1)
sts UCSR1A, mpr
; Baudrate = 2400
ldi mpr, high(832)
sts UBRR1H, mpr
ldi mpr, low(832)
sts UBRR1L, mpr
; Set frame formats: 8 data, 2 stop bits, asynchronous
ldi mpr, (0<<UMSEL1)|(1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
sts UCSR1C, mpr
; Enable both receiver and transmitter, and receive interrupt
ldi mpr, (1<<RXEN1)|(1<<TXEN1)|(1<<RXCIE1)
;ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
; Set the Interrupt Sense Control to falling edge
ldi mpr, (1<<ISC01)|(0<<ISC00 )|(1<<ISC11)|(0<<ISC10)|(1<<ISC21)|(0<<ISC20)
sts EICRA, mpr ; Use sts, EICRA in extended I/O space
; Set the External Interrupt Mask
ldi mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)
out EIMSK, mpr
; Initialize Fwd Movement
ldi mpr, MovFwd
mov prev_move, mpr
out PORTB, mpr
ldi freeze_counter,0
; Turn on interrupts
sei

;***********************************************************
;*Main Program
;***********************************************************
MAIN:
rjmpMAIN
;***********************************************************
;*Functions and Subroutines
;***********************************************************
receive:
push  mpr
;in  prev_move, PINB
lds   mpr, UDR1
sbrc  mpr, 7;if byte is an address, skip
breq  command;if byte is an action, go to command
ldi   addr_flag, 0;clear address flag
cpi   mpr, 0b01010101
breq  Frozen; in incoming signal is a freeze, go to Frozen
cpi   mpr, BotAddress
brne  end_receive;if address doesn't match, go to end receive
ldi   addr_flag, 1;if address does match, set the address flag
jmp   end_receive
command:
tst   addr_flag
breq  end_receive
rcall exec_command
ldi   addr_flag, 0
jmp  end_receive
Frozen:
;disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
inc freeze_counter
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
jmp   Frozen
ldi   mpr, Halt
out   PORTB, mpr
ldi   addr_flag, 0
;call out waiting function to freeze movement
ldi   waitcnt, WTime
rcall wait
ldi   waitcnt, WTime2
rcall wait
ldi   waitcnt, WTime2
rcall wait
cpi freeze_counter, 3
brne im_alive

im_dead:
rjmp im_dead
im_alive:
ldi mpr, (1<<INT0 | 1<<INT1)
out EIFR, mpr
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
jmp  end_receive
end_receive:
out   PORTB, prev_move
pop   mpr
ret
exec_command:
push  mpr
; Check for freeze command
cpimpr, 0b11111000
brneother_command
rcallTx_Freeze
jmpend_exec
other_command:
lsl   mpr
mov   prev_move, mpr
end_exec:
pop   mpr
ret
Tx_Freeze:
pushmpr
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
Transmission_Freeze:
lds   mpr, UCSR1A
; Check if buffer is empty
sbrs  mpr, UDRE1
rjmp  Transmission_Freeze
ldi   mpr, 0b01010101
sts   UDR1, mpr
ldi   sent_freeze, 1
freeze_wait:
lds   mpr, UCSR1A
sbrs  mpr, TXC1 ; Check if buffer is empty
jmp freeze_wait
wait_pause:
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
rjmp  wait_pause
receive_wait:
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore mpr
ret; Return from subroutine
HitRight:
push mpr; Save mpr register
push waitcnt; Save wait register
in mpr, SREG; Save program state
push mpr
;disable incoming interrupts
; Disable receiver and it's interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldi mpr, MovBck; Load Move Backward command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 seconds
rcall Wait; Call wait function
; Turn left for a second
ldi mpr, TurnL; Load Turn Left Command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 second
rcall Wait; Call wait function
; Resume previous movement
out PORTB, prev_move; Send command to port
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore program state
out SREG, mpr
pop waitcnt; Restore wait register
pop mpr; Restore mpr
ret; Return from subroutine
HitLeft:
pushmpr; Save mpr register
pushwaitcnt; Save wait register
inmpr, SREG; Save program state
pushmpr

; Disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldimpr, MovBck; Load Move Backward command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 seconds
rcallWait; Call wait function
; Turn right for a second
ldimpr, TurnR; Load Turn Left Command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 second
rcallWait; Call wait function
; Return to Previous Movement
outPORTB, prev_move ; Send command to port
;enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldimpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
stsUCSR1B, mpr
popmpr; Restore program state
outSREG, mpr
popwaitcnt; Restore wait register
popmpr; Restore mpr
ret; Return from subroutine
Wait:
pushwaitcnt; Save wait register
pushilcnt; Save ilcnt register
pusholcnt; Save olcnt register

Loop:ldiolcnt, 224; load olcnt register
OLoop:ldiilcnt, 237; load ilcnt register
ILoop:decilcnt; decrement ilcnt
brneILoop; Continue Inner Loop
decolcnt;decrement olcnt
brneOLoop; Continue Outer Loop
decwaitcnt; Decrement wait 
brneLoop; Continue Wait loop
popolcnt; Restore olcnt register
popilcnt; Restore ilcnt register
popwaitcnt; Restore wait register
ret; Return from subroutine.include "m128def.inc"; Include definition file
;ROBOT
;***********************************************************
;*Internal Register Definitions and Constants
;***********************************************************
.deffreeze_counter = r23
.defmpr = r16; Multi-Purpose Register
.defaddr_flag = r17; 1 if address matched, 0 otherwise
.def    sent_freeze = r18
.defwaitcnt = r19
.defilcnt = r20
.defolcnt = r21
.defprev_move = r22
.equWTime2 = 200
.equWTime = 100
.equWskrR = 0; Right Whisker Input Bit
.equWskrL = 1; Left Whisker Input Bit
.equEngEnR = 4; Right Engine Enable Bit
.equEngEnL = 7; Left Engine Enable Bit
.equEngDirR = 5; Right Engine Direction Bit
.equEngDirL = 6; Left Engine Direction Bit
.equBotAddress = 0b00000111;smart receiver address
;.equBotAddress = 0b01000111;dummy receiver address
; Macros listed: values to make the TekBot Move.
.equMovFwd =  (1<<EngDirR|1<<EngDirL);0b01100000 Move Forward Action Code
.equMovBck =  $00;0b00000000 Move Backward Action Code
.equTurnR =   (1<<EngDirL);0b01000000 Turn Right Action Code
.equTurnL =   (1<<EngDirR);0b00100000 Turn Left Action Code
.equHalt =    (1<<EngEnR|1<<EngEnL);0b10010000 Halt Action Code
;***********************************************************
;*Start of Code Segment
;***********************************************************
.cseg; Beginning of code segment
;***********************************************************
;*Interrupt Vectors
;***********************************************************
.org$0000; Beginning of IVs
rjmp INIT; Reset interrupt
.org $0002; {IRQ0 => pin0, PORTD}
rcall HitRight        ; Call hit right function
reti                    ; Return from interrupt
.org $0004; {IRQ1 => pin1, PORTD}
rcall HitLeft         ; Call hit left function
reti                   ; Return from interrupt
.org $003C; RXD1 vector => pin2, PORTD
rcall receive
reti
.org$0046; End of Interrupt Vectors
;***********************************************************
;*Program Initialization
;***********************************************************
INIT:
; Initialize Stack Pointer
ldi mpr, high(RAMEND)
out SPH, mpr
ldi mpr, low(RAMEND)
out SPL, mpr
; Configure I/O ports
ldi mpr, 0b11111111
out DDRB, mpr
; Initialize Port D for input
ldi mpr, 0b00000000
out DDRD, mpr ; Set the DDR register for Port D
ldi mpr, (1<<WskrL)|(1<<WskrR)
out PORTD, mpr ; Set the Port D to Input with Hi-Z
; Enable USART1 at double transmission spd
ldi mpr, (1<<U2X1)
sts UCSR1A, mpr
; Baudrate = 2400
ldi mpr, high(832)
sts UBRR1H, mpr
ldi mpr, low(832)
sts UBRR1L, mpr
; Set frame formats: 8 data, 2 stop bits, asynchronous
ldi mpr, (0<<UMSEL1)|(1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
sts UCSR1C, mpr
; Enable both receiver and transmitter, and receive interrupt
ldi mpr, (1<<RXEN1)|(1<<TXEN1)|(1<<RXCIE1)
;ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
; Set the Interrupt Sense Control to falling edge
ldi mpr, (1<<ISC01)|(0<<ISC00 )|(1<<ISC11)|(0<<ISC10)|(1<<ISC21)|(0<<ISC20)
sts EICRA, mpr ; Use sts, EICRA in extended I/O space
; Set the External Interrupt Mask
ldi mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)
out EIMSK, mpr
; Initialize Fwd Movement
ldi mpr, MovFwd
mov prev_move, mpr
out PORTB, mpr
ldi freeze_counter,0
; Turn on interrupts
sei

;***********************************************************
;*Main Program
;***********************************************************
MAIN:
rjmpMAIN
;***********************************************************
;*Functions and Subroutines
;***********************************************************
receive:
push  mpr
;in  prev_move, PINB
lds   mpr, UDR1
sbrc  mpr, 7;if byte is an address, skip
breq  command;if byte is an action, go to command
ldi   addr_flag, 0;clear address flag
cpi   mpr, 0b01010101
breq  Frozen; in incoming signal is a freeze, go to Frozen
cpi   mpr, BotAddress
brne  end_receive;if address doesn't match, go to end receive
ldi   addr_flag, 1;if address does match, set the address flag
jmp   end_receive
command:
tst   addr_flag
breq  end_receive
rcall exec_command
ldi   addr_flag, 0
jmp  end_receive
Frozen:
;disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
inc freeze_counter
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
jmp   Frozen
ldi   mpr, Halt
out   PORTB, mpr
ldi   addr_flag, 0
;call out waiting function to freeze movement
ldi   waitcnt, WTime
rcall wait
ldi   waitcnt, WTime2
rcall wait
ldi   waitcnt, WTime2
rcall wait
cpi freeze_counter, 3
brne im_alive

im_dead:
rjmp im_dead
im_alive:
ldi mpr, (1<<INT0 | 1<<INT1)
out EIFR, mpr
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
jmp  end_receive
end_receive:
out   PORTB, prev_move
pop   mpr
ret
exec_command:
push  mpr
; Check for freeze command
cpimpr, 0b11111000
brneother_command
rcallTx_Freeze
jmpend_exec
other_command:
lsl   mpr
mov   prev_move, mpr
end_exec:
pop   mpr
ret
Tx_Freeze:
pushmpr
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
Transmission_Freeze:
lds   mpr, UCSR1A
; Check if buffer is empty
sbrs  mpr, UDRE1
rjmp  Transmission_Freeze
ldi   mpr, 0b01010101
sts   UDR1, mpr
ldi   sent_freeze, 1
freeze_wait:
lds   mpr, UCSR1A
sbrs  mpr, TXC1 ; Check if buffer is empty
jmp freeze_wait
wait_pause:
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
rjmp  wait_pause
receive_wait:
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore mpr
ret; Return from subroutine
HitRight:
push mpr; Save mpr register
push waitcnt; Save wait register
in mpr, SREG; Save program state
push mpr
;disable incoming interrupts
; Disable receiver and it's interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldi mpr, MovBck; Load Move Backward command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 seconds
rcall Wait; Call wait function
; Turn left for a second
ldi mpr, TurnL; Load Turn Left Command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 second
rcall Wait; Call wait function
; Resume previous movement
out PORTB, prev_move; Send command to port
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore program state
out SREG, mpr
pop waitcnt; Restore wait register
pop mpr; Restore mpr
ret; Return from subroutine
HitLeft:
pushmpr; Save mpr register
pushwaitcnt; Save wait register
inmpr, SREG; Save program state
pushmpr

; Disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldimpr, MovBck; Load Move Backward command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 seconds
rcallWait; Call wait function
; Turn right for a second
ldimpr, TurnR; Load Turn Left Command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 second
rcallWait; Call wait function
; Return to Previous Movement
outPORTB, prev_move ; Send command to port
;enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldimpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
stsUCSR1B, mpr
popmpr; Restore program state
outSREG, mpr
popwaitcnt; Restore wait register
popmpr; Restore mpr
ret; Return from subroutine
Wait:
pushwaitcnt; Save wait register
pushilcnt; Save ilcnt register
pusholcnt; Save olcnt register

Loop:ldiolcnt, 224; load olcnt register
OLoop:ldiilcnt, 237; load ilcnt register
ILoop:decilcnt; decrement ilcnt
brneILoop; Continue Inner Loop
decolcnt;decrement olcnt
brneOLoop; Continue Outer Loop
decwaitcnt; Decrement wait 
brneLoop; Continue Wait loop
popolcnt; Restore olcnt register
popilcnt; Restore ilcnt register
popwaitcnt; Restore wait register
ret; Return from subroutine.include "m128def.inc"; Include definition file
;ROBOT
;***********************************************************
;*Internal Register Definitions and Constants
;***********************************************************
.deffreeze_counter = r23
.defmpr = r16; Multi-Purpose Register
.defaddr_flag = r17; 1 if address matched, 0 otherwise
.def    sent_freeze = r18
.defwaitcnt = r19
.defilcnt = r20
.defolcnt = r21
.defprev_move = r22
.equWTime2 = 200
.equWTime = 100
.equWskrR = 0; Right Whisker Input Bit
.equWskrL = 1; Left Whisker Input Bit
.equEngEnR = 4; Right Engine Enable Bit
.equEngEnL = 7; Left Engine Enable Bit
.equEngDirR = 5; Right Engine Direction Bit
.equEngDirL = 6; Left Engine Direction Bit
.equBotAddress = 0b00000111;smart receiver address
;.equBotAddress = 0b01000111;dummy receiver address
; Macros listed: values to make the TekBot Move.
.equMovFwd =  (1<<EngDirR|1<<EngDirL);0b01100000 Move Forward Action Code
.equMovBck =  $00;0b00000000 Move Backward Action Code
.equTurnR =   (1<<EngDirL);0b01000000 Turn Right Action Code
.equTurnL =   (1<<EngDirR);0b00100000 Turn Left Action Code
.equHalt =    (1<<EngEnR|1<<EngEnL);0b10010000 Halt Action Code
;***********************************************************
;*Start of Code Segment
;***********************************************************
.cseg; Beginning of code segment
;***********************************************************
;*Interrupt Vectors
;***********************************************************
.org$0000; Beginning of IVs
rjmp INIT; Reset interrupt
.org $0002; {IRQ0 => pin0, PORTD}
rcall HitRight        ; Call hit right function
reti                    ; Return from interrupt
.org $0004; {IRQ1 => pin1, PORTD}
rcall HitLeft         ; Call hit left function
reti                   ; Return from interrupt
.org $003C; RXD1 vector => pin2, PORTD
rcall receive
reti
.org$0046; End of Interrupt Vectors
;***********************************************************
;*Program Initialization
;***********************************************************
INIT:
; Initialize Stack Pointer
ldi mpr, high(RAMEND)
out SPH, mpr
ldi mpr, low(RAMEND)
out SPL, mpr
; Configure I/O ports
ldi mpr, 0b11111111
out DDRB, mpr
; Initialize Port D for input
ldi mpr, 0b00000000
out DDRD, mpr ; Set the DDR register for Port D
ldi mpr, (1<<WskrL)|(1<<WskrR)
out PORTD, mpr ; Set the Port D to Input with Hi-Z
; Enable USART1 at double transmission spd
ldi mpr, (1<<U2X1)
sts UCSR1A, mpr
; Baudrate = 2400
ldi mpr, high(832)
sts UBRR1H, mpr
ldi mpr, low(832)
sts UBRR1L, mpr
; Set frame formats: 8 data, 2 stop bits, asynchronous
ldi mpr, (0<<UMSEL1)|(1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
sts UCSR1C, mpr
; Enable both receiver and transmitter, and receive interrupt
ldi mpr, (1<<RXEN1)|(1<<TXEN1)|(1<<RXCIE1)
;ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
; Set the Interrupt Sense Control to falling edge
ldi mpr, (1<<ISC01)|(0<<ISC00 )|(1<<ISC11)|(0<<ISC10)|(1<<ISC21)|(0<<ISC20)
sts EICRA, mpr ; Use sts, EICRA in extended I/O space
; Set the External Interrupt Mask
ldi mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)
out EIMSK, mpr
; Initialize Fwd Movement
ldi mpr, MovFwd
mov prev_move, mpr
out PORTB, mpr
ldi freeze_counter,0
; Turn on interrupts
sei

;***********************************************************
;*Main Program
;***********************************************************
MAIN:
rjmpMAIN
;***********************************************************
;*Functions and Subroutines
;***********************************************************
receive:
push  mpr
;in  prev_move, PINB
lds   mpr, UDR1
sbrc  mpr, 7;if byte is an address, skip
breq  command;if byte is an action, go to command
ldi   addr_flag, 0;clear address flag
cpi   mpr, 0b01010101
breq  Frozen; in incoming signal is a freeze, go to Frozen
cpi   mpr, BotAddress
brne  end_receive;if address doesn't match, go to end receive
ldi   addr_flag, 1;if address does match, set the address flag
jmp   end_receive
command:
tst   addr_flag
breq  end_receive
rcall exec_command
ldi   addr_flag, 0
jmp  end_receive
Frozen:
;disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
inc freeze_counter
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
jmp   Frozen
ldi   mpr, Halt
out   PORTB, mpr
ldi   addr_flag, 0
;call out waiting function to freeze movement
ldi   waitcnt, WTime
rcall wait
ldi   waitcnt, WTime2
rcall wait
ldi   waitcnt, WTime2
rcall wait
cpi freeze_counter, 3
brne im_alive

im_dead:
rjmp im_dead
im_alive:
ldi mpr, (1<<INT0 | 1<<INT1)
out EIFR, mpr
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
jmp  end_receive
end_receive:
out   PORTB, prev_move
pop   mpr
ret
exec_command:
push  mpr
; Check for freeze command
cpimpr, 0b11111000
brneother_command
rcallTx_Freeze
jmpend_exec
other_command:
lsl   mpr
mov   prev_move, mpr
end_exec:
pop   mpr
ret
Tx_Freeze:
pushmpr
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
Transmission_Freeze:
lds   mpr, UCSR1A
; Check if buffer is empty
sbrs  mpr, UDRE1
rjmp  Transmission_Freeze
ldi   mpr, 0b01010101
sts   UDR1, mpr
ldi   sent_freeze, 1
freeze_wait:
lds   mpr, UCSR1A
sbrs  mpr, TXC1 ; Check if buffer is empty
jmp freeze_wait
wait_pause:
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
rjmp  wait_pause
receive_wait:
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore mpr
ret; Return from subroutine
HitRight:
push mpr; Save mpr register
push waitcnt; Save wait register
in mpr, SREG; Save program state
push mpr
;disable incoming interrupts
; Disable receiver and it's interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldi mpr, MovBck; Load Move Backward command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 seconds
rcall Wait; Call wait function
; Turn left for a second
ldi mpr, TurnL; Load Turn Left Command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 second
rcall Wait; Call wait function
; Resume previous movement
out PORTB, prev_move; Send command to port
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore program state
out SREG, mpr
pop waitcnt; Restore wait register
pop mpr; Restore mpr
ret; Return from subroutine
HitLeft:
pushmpr; Save mpr register
pushwaitcnt; Save wait register
inmpr, SREG; Save program state
pushmpr

; Disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldimpr, MovBck; Load Move Backward command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 seconds
rcallWait; Call wait function
; Turn right for a second
ldimpr, TurnR; Load Turn Left Command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 second
rcallWait; Call wait function
; Return to Previous Movement
outPORTB, prev_move ; Send command to port
;enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldimpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
stsUCSR1B, mpr
popmpr; Restore program state
outSREG, mpr
popwaitcnt; Restore wait register
popmpr; Restore mpr
ret; Return from subroutine
Wait:
pushwaitcnt; Save wait register
pushilcnt; Save ilcnt register
pusholcnt; Save olcnt register

Loop:ldiolcnt, 224; load olcnt register
OLoop:ldiilcnt, 237; load ilcnt register
ILoop:decilcnt; decrement ilcnt
brneILoop; Continue Inner Loop
decolcnt;decrement olcnt
brneOLoop; Continue Outer Loop
decwaitcnt; Decrement wait 
brneLoop; Continue Wait loop
popolcnt; Restore olcnt register
popilcnt; Restore ilcnt register
popwaitcnt; Restore wait register
ret; Return from subroutine.include "m128def.inc"; Include definition file
;ROBOT
;***********************************************************
;*Internal Register Definitions and Constants
;***********************************************************
.deffreeze_counter = r23
.defmpr = r16; Multi-Purpose Register
.defaddr_flag = r17; 1 if address matched, 0 otherwise
.def    sent_freeze = r18
.defwaitcnt = r19
.defilcnt = r20
.defolcnt = r21
.defprev_move = r22
.equWTime2 = 200
.equWTime = 100
.equWskrR = 0; Right Whisker Input Bit
.equWskrL = 1; Left Whisker Input Bit
.equEngEnR = 4; Right Engine Enable Bit
.equEngEnL = 7; Left Engine Enable Bit
.equEngDirR = 5; Right Engine Direction Bit
.equEngDirL = 6; Left Engine Direction Bit
.equBotAddress = 0b00000111;smart receiver address
;.equBotAddress = 0b01000111;dummy receiver address
; Macros listed: values to make the TekBot Move.
.equMovFwd =  (1<<EngDirR|1<<EngDirL);0b01100000 Move Forward Action Code
.equMovBck =  $00;0b00000000 Move Backward Action Code
.equTurnR =   (1<<EngDirL);0b01000000 Turn Right Action Code
.equTurnL =   (1<<EngDirR);0b00100000 Turn Left Action Code
.equHalt =    (1<<EngEnR|1<<EngEnL);0b10010000 Halt Action Code
;***********************************************************
;*Start of Code Segment
;***********************************************************
.cseg; Beginning of code segment
;***********************************************************
;*Interrupt Vectors
;***********************************************************
.org$0000; Beginning of IVs
rjmp INIT; Reset interrupt
.org $0002; {IRQ0 => pin0, PORTD}
rcall HitRight        ; Call hit right function
reti                    ; Return from interrupt
.org $0004; {IRQ1 => pin1, PORTD}
rcall HitLeft         ; Call hit left function
reti                   ; Return from interrupt
.org $003C; RXD1 vector => pin2, PORTD
rcall receive
reti
.org$0046; End of Interrupt Vectors
;***********************************************************
;*Program Initialization
;***********************************************************
INIT:
; Initialize Stack Pointer
ldi mpr, high(RAMEND)
out SPH, mpr
ldi mpr, low(RAMEND)
out SPL, mpr
; Configure I/O ports
ldi mpr, 0b11111111
out DDRB, mpr
; Initialize Port D for input
ldi mpr, 0b00000000
out DDRD, mpr ; Set the DDR register for Port D
ldi mpr, (1<<WskrL)|(1<<WskrR)
out PORTD, mpr ; Set the Port D to Input with Hi-Z
; Enable USART1 at double transmission spd
ldi mpr, (1<<U2X1)
sts UCSR1A, mpr
; Baudrate = 2400
ldi mpr, high(832)
sts UBRR1H, mpr
ldi mpr, low(832)
sts UBRR1L, mpr
; Set frame formats: 8 data, 2 stop bits, asynchronous
ldi mpr, (0<<UMSEL1)|(1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
sts UCSR1C, mpr
; Enable both receiver and transmitter, and receive interrupt
ldi mpr, (1<<RXEN1)|(1<<TXEN1)|(1<<RXCIE1)
;ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
; Set the Interrupt Sense Control to falling edge
ldi mpr, (1<<ISC01)|(0<<ISC00 )|(1<<ISC11)|(0<<ISC10)|(1<<ISC21)|(0<<ISC20)
sts EICRA, mpr ; Use sts, EICRA in extended I/O space
; Set the External Interrupt Mask
ldi mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)
out EIMSK, mpr
; Initialize Fwd Movement
ldi mpr, MovFwd
mov prev_move, mpr
out PORTB, mpr
ldi freeze_counter,0
; Turn on interrupts
sei

;***********************************************************
;*Main Program
;***********************************************************
MAIN:
rjmpMAIN
;***********************************************************
;*Functions and Subroutines
;***********************************************************
receive:
push  mpr
;in  prev_move, PINB
lds   mpr, UDR1
sbrc  mpr, 7;if byte is an address, skip
breq  command;if byte is an action, go to command
ldi   addr_flag, 0;clear address flag
cpi   mpr, 0b01010101
breq  Frozen; in incoming signal is a freeze, go to Frozen
cpi   mpr, BotAddress
brne  end_receive;if address doesn't match, go to end receive
ldi   addr_flag, 1;if address does match, set the address flag
jmp   end_receive
command:
tst   addr_flag
breq  end_receive
rcall exec_command
ldi   addr_flag, 0
jmp  end_receive
Frozen:
;disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
inc freeze_counter
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
jmp   Frozen
ldi   mpr, Halt
out   PORTB, mpr
ldi   addr_flag, 0
;call out waiting function to freeze movement
ldi   waitcnt, WTime
rcall wait
ldi   waitcnt, WTime2
rcall wait
ldi   waitcnt, WTime2
rcall wait
cpi freeze_counter, 3
brne im_alive

im_dead:
rjmp im_dead
im_alive:
ldi mpr, (1<<INT0 | 1<<INT1)
out EIFR, mpr
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
jmp  end_receive
end_receive:
out   PORTB, prev_move
pop   mpr
ret
exec_command:
push  mpr
; Check for freeze command
cpimpr, 0b11111000
brneother_command
rcallTx_Freeze
jmpend_exec
other_command:
lsl   mpr
mov   prev_move, mpr
end_exec:
pop   mpr
ret
Tx_Freeze:
pushmpr
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
Transmission_Freeze:
lds   mpr, UCSR1A
; Check if buffer is empty
sbrs  mpr, UDRE1
rjmp  Transmission_Freeze
ldi   mpr, 0b01010101
sts   UDR1, mpr
ldi   sent_freeze, 1
freeze_wait:
lds   mpr, UCSR1A
sbrs  mpr, TXC1 ; Check if buffer is empty
jmp freeze_wait
wait_pause:
lds   mpr, UCSR1A
sbrs  mpr, UDRE1 ; Check if buffer is empty
rjmp  wait_pause
receive_wait:
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore mpr
ret; Return from subroutine
HitRight:
push mpr; Save mpr register
push waitcnt; Save wait register
in mpr, SREG; Save program state
push mpr
;disable incoming interrupts
; Disable receiver and it's interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldi mpr, MovBck; Load Move Backward command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 seconds
rcall Wait; Call wait function
; Turn left for a second
ldi mpr, TurnL; Load Turn Left Command
out PORTB, mpr; Send command to port
ldi waitcnt, WTime; Wait for 1 second
rcall Wait; Call wait function
; Resume previous movement
out PORTB, prev_move; Send command to port
; Enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldi mpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
sts UCSR1B, mpr
pop mpr; Restore program state
out SREG, mpr
pop waitcnt; Restore wait register
pop mpr; Restore mpr
ret; Return from subroutine
HitLeft:
pushmpr; Save mpr register
pushwaitcnt; Save wait register
inmpr, SREG; Save program state
pushmpr

; Disable incoming interrupts
; Disable receiver and its interrupt, enable transmitter
ldi mpr, (0<<RXEN1)|(1<<TXEN1)|(0<<RXCIE1)
sts UCSR1B, mpr
; Move Backwards for 1 seconds
ldimpr, MovBck; Load Move Backward command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 seconds
rcallWait; Call wait function
; Turn right for a second
ldimpr, TurnR; Load Turn Left Command
outPORTB, mpr; Send command to port
ldiwaitcnt, WTime; Wait for 1 second
rcallWait; Call wait function
; Return to Previous Movement
outPORTB, prev_move ; Send command to port
;enable incoming interrupts
; Enable receiver and interrupt, disable transmitter
ldimpr, (1<<RXEN1)|(0<<TXEN1)|(1<<RXCIE1)
stsUCSR1B, mpr
popmpr; Restore program state
outSREG, mpr
popwaitcnt; Restore wait register
popmpr; Restore mpr
ret; Return from subroutine
Wait:
pushwaitcnt; Save wait register
pushilcnt; Save ilcnt register
pusholcnt; Save olcnt register

Loop:ldiolcnt, 224; load olcnt register
OLoop:ldiilcnt, 237; load ilcnt register
ILoop:decilcnt; decrement ilcnt
brneILoop; Continue Inner Loop
decolcnt;decrement olcnt
brneOLoop; Continue Outer Loop
decwaitcnt; Decrement wait 
brneLoop; Continue Wait loop
popolcnt; Restore olcnt register
popilcnt; Restore ilcnt register
popwaitcnt; Restore wait register
ret; Return from subroutine
