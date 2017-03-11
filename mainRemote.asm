.include "m128def.inc"				; Include definition file
;REMOTE
;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def    toSend = r17           		; Next command to send
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit
; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)					;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))			;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))			;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ    Freeze =  0b11111000
.equ    TestFreeze = 0b01010101

;.equ	BotAddress = 0b00000111	;smart address
.equ	BotAddress = 0b01000111	;dummy address

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg						; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp   INIT			    ; Reset interrupt

.org	$0046					 ; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi   mpr, high(RAMEND)
		out   SPH, mpr
		ldi   mpr, low(RAMEND)
		out   SPL, mpr
	;I/O Ports
		; TESTING Initialize Port B for output
		ldi   mpr, 0b11111111
		out   DDRb, mpr
		; Initialize Port D for input
		ldi   mpr, 0b00000000
; Set the DDR register for Port D
		out   DDRD, mpr       
		ldi   mpr, 0b00000000
		out   PORTD, mpr
		;USART1
		ldi   mpr, (1<<U2X1)
		sts   UCSR1A, mpr
		;Set baudrate at 2400bps
		ldi   mpr, high(832)
		sts   UBRR1H, mpr
		ldi   mpr, low(832)
		sts   UBRR1L, mpr
		;Enable transmitter
		ldi   mpr, (1<<TXEN1)
		sts   UCSR1B, mpr
		;Set frame format: 8 data bits, 2 stop bits
		ldi   mpr, (0<<UMSEL1 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10)
		sts   UCSR1B, mpr;
;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		in    mpr, PIND
		ldi   toSend, 0
		; Check for pushed buttons
		sbrs  mpr, 0
		ldi   toSend, TurnR
		sbrs  mpr, 1
		ldi   toSend, TurnL
		sbrs  mpr, 5
		ldi   toSend, MovFwd
		sbrs  mpr, 6
		ldi   toSend, MovBck
		sbrs  mpr, 7
		ldi   toSend, Halt
		sbrs  mpr, 4
		ldi   toSend, Freeze
		tst   toSend
		breq  MAIN
		cpi   toSend, TestFreeze
		breq  USART_Command

USART_Address:
		lds   mpr, UCSR1A
; Check if buffer is empty
		sbrs  mpr, UDRE1
		jmp  USART_Address
		ldi   mpr, BotAddress
		sts   UDR1, mpr
USART_Command:
		lds   mpr, UCSR1A
; Check if buffer is empty
		sbrs  mpr, UDRE1
		jmp  USART_Command
		sts   UDR1, toSend
		; Output last send command to LEDS
		out   PORTB, toSend 
		jmp  MAIN