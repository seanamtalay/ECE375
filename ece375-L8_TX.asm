;***********************************************************
;*
;*	Lab 8 TX
;*
;*	Enter the description of the program here
;*
;*	This is the TRANSMIT skeleton file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Enter your name
;*	   Date: Enter Date
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def 	mpr2 = r17
.def	waitcnt = r18			; Wait Loop Counter 
.def	ilcnt = r19				; Inner Loop Counter 
.def	olcnt = r20				; Outer Loop Counter 

.equ	WTime = 100				; Time to wait in wait loop
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit
; Use these action codes between the remote and robot
; MSB = 1 thus:
.equ 	BotAddress = 0b00001001
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi 	mpr, high(RAMEND)
	out 	SPH, mpr
	ldi 	mpr, low(RAMEND)
	out 	SPL, mpr
	;I/O Ports
	ldi		mpr, $FF		;Set Port B Data Direction Regisiter
	out		DDRB, mpr
	ldi		mpr, $00		;Initialize Port B Data Register
	out		PORTB, mpr

	ldi		mpr, $00		;Set Port D Data Direction Register
	out		DDRD, mpr
	ldi		mpr, $FF		;Initialize Port D Data Register
	out		PORTD, mpr
	;USART1
		ldi 	mpr, (1<<U2X1)		;Set double data rate
		sts 	UCSR1A, mpr
		;Set baudrate at 2400bps
		ldi 	mpr, high(416) 	; Load high byte of 0x0340 
		sts 	UBRR1H, mpr 	; UBRR0H in extended I/O space 
		ldi 	mpr, low(416) 	; Load low byte of 0x0340 
		sts 	UBRR1L, mpr 	

		;Enable receiver and enable receive interrupts
		ldi 	mpr, (1<<TXEN1) 
		sts 	UCSR1B, mpr 		

		;Set frame format: 8 data bits, 2 stop bits
		ldi 	mpr, (0<<UMSEL1 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10) 
		sts 	UCSR1C, mpr 		; UCSR0C in extended I/O space

	
	;External Interrupts
		;Set the External Interrupt Mask
		ldi		mpr, (1<<INT0) | (1<<INT1)
		out		EIMSK, mpr
		;Set the Interrupt Sense Control to falling edge detection
		ldi		mpr, (1<<ISC01) | (0<<ISC00) | (1<<ISC11) | (0<<ISC10)
		sts		EICRA, mpr		;Use sts, EICRA in extended I/O space
		
		sei
	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		in    mpr, PIND
		;ldi   toSend, 0
		; Check for pushed buttons
		sbrs  mpr, 0
		;ldi   toSend, TurnR
		rjmp  TRANSMIT_R
		
		sbrs  mpr, 1
		;ldi   toSend, TurnL
		rjmp  TRANSMIT_L
		
		sbrs  mpr, 5
		;ldi   toSend, MovFwd
		rjmp  TRANSMIT_FWD
		
		sbrs  mpr, 6
		;ldi   toSend, MovBck
		rjmp  TRANSMIT_BCK
		
		;sbrs  mpr, 7
		;ldi   toSend, Halt
		;sbrs  mpr, 4
		;ldi   toSend, Freeze
		;tst   toSend
		
		;breq  MAIN
		;cpi   toSend, TestFreeze
		;breq  USART_Command
		jmp  MAIN

;USART_Address:
;		lds   mpr, UCSR1A
; Check if buffer is empty
;		sbrs  mpr, UDRE1
;		jmp  USART_Address
;		ldi   mpr, BotAddress
;		sts   UDR1, mpr
;USART_Command:
;		lds   mpr, UCSR1A
; Check if buffer is empty
;		sbrs  mpr, UDRE1
;		jmp  USART_Command
;		sts   UDR1, toSend
		; Output last send command to LEDS
;		out   PORTB, toSend 
;		jmp  MAIN
		
;***********************************************************
;*	Functions and Subroutines
;***********************************************************

TRANSMIT_FWD:
		lds   	mpr, UCSR1A
; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_FWD
		ldi   	mpr, BotAddress
		sts   	UDR1, mpr
TRANSMIT_FWD_COMMAND:
		lds   	mpr, UCSR1A
; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_FWD_COMMAND
		ldi 	mpr2, MovFwd
		sts   	UDR1, mpr2
		; Output last send command to LEDS
		out   	PORTB, mpr2 
		jmp  	MAIN

;************************************************************

TRANSMIT_BCK:
		lds   	mpr, UCSR1A
		; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_BCK
		ldi   	mpr, BotAddress
		sts   	UDR1, mpr

TRANSMIT_BCK_COMMAND:
		lds   	mpr, UCSR1A
		; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_BCK_COMMAND
		ldi 	mpr2, MovBck
		sts   	UDR1, mpr2
		; Output last send command to LEDS
		out   	PORTB, mpr2 
		jmp  	MAIN

;************************************************************

TRANSMIT_R:
		lds   	mpr, UCSR1A
		; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_R
		ldi   	mpr, BotAddress
		sts   	UDR1, mpr
		
TRANSMIT_R_COMMAND:
		lds   	mpr, UCSR1A
		; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_R_COMMAND
		ldi 	mpr2, TurnR
		sts   	UDR1, mpr2
		; Output last send command to LEDS
		out   	PORTB, mpr2 
		jmp  	MAIN

;************************************************************

TRANSMIT_L:
		lds   	mpr, UCSR1A
		; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_L
		ldi   	mpr, BotAddress
		sts   	UDR1, mpr
		
TRANSMIT_L_COMMAND:
		lds   	mpr, UCSR1A
		; Check if buffer is empty
		sbrs  	mpr, UDRE1
		jmp  	TRANSMIT_L_COMMAND
		ldi 	mpr2, TurnL
		sts   	UDR1, mpr2
		; Output last send command to LEDS
		out   	PORTB, mpr2 
		jmp  	MAIN

;************************************************************

