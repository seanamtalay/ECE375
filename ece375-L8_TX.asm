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
.equ 	BotAddress = 0b11111111
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	SpeedUp = ($80|1<<(EngDirL))					;0b11000000 Speed Up Action Code
.equ	SpeedDown = (1<<(EngDirR-1)|1<<(EngDirL-1))		;0b00110000 Speed Down Action Code
.equ 	SpeedMax = ($80|1<<(EngDirL-1))					;0b10100000 Speed Max Action Code
.equ 	SpeedMin = (1<<(EngDirR-1)|1<<(EngDirL))		;0b01010000 Speed Min Action Code

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
		sts 	UBRR1H, mpr 	; UBRR1H in extended I/O space 
		ldi 	mpr, low(416) 	; Load low byte of 0x0340 
		sts 	UBRR1L, mpr 	

		;Enable receiver and enable receive interrupts
		ldi 	mpr, (1<<TXEN1 | 1<<RXEN1) 
		sts 	UCSR1B, mpr 		

		;Set frame format: 8 data bits, 2 stop bits
		ldi 	mpr, (1<<UCSZ10)|(1<<UCSZ11)|(1<<USBS1)|(1<<UPM01) 
		sts 	UCSR1C, mpr 		; UCSR0C in extended I/O space
	
	;External Interrupts
		;Set the External Interrupt Mask
		ldi		mpr, (1<<INT0) | (1<<INT1)
		out		EIMSK, mpr

	clr mpr
	out PORTB, mpr


;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		in    mpr, PIND
		
		sbrs  mpr, 7				;Check if each button/bit is cleared
		rjmp  TRANSMIT_R			;Then go to respective functions to transmit Bot Address and Action Code
		sbrs  mpr, 6		
		rjmp  TRANSMIT_L
		sbrs  mpr, 5		
		rjmp  TRANSMIT_FWD
		sbrs  mpr, 4		
		rjmp  TRANSMIT_BCK
		sbrs  mpr, 3
		rjmp  TRANSMIT_SPD_MAX
		sbrs  mpr, 2
		rjmp  TRANSMIT_SPD_MIN
		sbrs  mpr, 1
		rjmp  TRANSMIT_SPD_UP
		sbrs  mpr, 0
		rjmp  TRANSMIT_SPD_DOWN
		
		ldi		mpr, (1<<INT0 | 1<<INT1)	;Clean Queue
		out		EIFR, mpr

		rjmp 	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

TRANSMIT_R:							;Transmit Bot Address using UDR1 to be checked for Transmit Right Function
		ldi		mpr2, (1<<7)		;if transmitter and receiver have the same address
		out 	PORTB, mpr2
		ldi 	mpr, BotAddress		
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait
		
TRANSMIT_R_LOOP1:					;Transmit Bot address and check if USART Data Register Empty is cleared
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rcall 	TRANSMIT_R_LOOP1
		
		ldi 	mpr, TurnR
		sts 	UDR1, mpr
		ldi		waitcnt, 250
		rcall	Wait
		
TRANSMIT_R_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_R_LOOP2
		
		rjmp 	MAIN

;************************************************************

TRANSMIT_L:							;Transmit Bot Address using UDR1 to be checked for Transmit Left Function
		ldi		mpr2, (1<<6)		;if transmitter and receiver have the same address
		out 	PORTB, mpr2		
		ldi 	mpr, BotAddress		
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait

TRANSMIT_L_LOOP1:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_L_LOOP1
		
		ldi 	mpr, TurnL
		sts 	UDR1, mpr
		ldi		waitcnt, 250
		rcall	Wait
TRANSMIT_L_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_L_LOOP2
		
		rjmp 	MAIN

;************************************************************

TRANSMIT_FWD:						;Transmit Bot Address using UDR1 to be checked for Transmit Forward Function
		ldi		mpr2, (1<<5)		;if transmitter and receiver have the same address
		out 	PORTB, mpr2
		ldi 	mpr, BotAddress		
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait
		
TRANSMIT_FWD_LOOP1:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_FWD_LOOP1
		
		ldi 	mpr, MovFwd
		sts 	UDR1, mpr
		ldi		waitcnt, 250
		rcall	Wait
TRANSMIT_FWD_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_FWD_LOOP2
		
		rjmp 	MAIN

;************************************************************

TRANSMIT_BCK:						;Transmit Bot Address using UDR1 to be checked for Transmit Backward Function
		ldi		mpr2, (1<<4)		;if transmitter and receiver have the same address
		out 	PORTB, mpr2
		ldi 	mpr, BotAddress		
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait
		
TRANSMIT_BCK_LOOP1:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_BCK_LOOP1
		
		ldi 	mpr, MovBck
		sts 	UDR1, mpr
		ldi		waitcnt, 250
		rcall	Wait
TRANSMIT_BCK_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_BCK_LOOP2
		
		rjmp 	MAIN

;************************************************************

TRANSMIT_SPD_UP:					;Transmit Bot Address using UDR1 to be checked for Transmit Speed Up Function
		ldi		mpr2, (1<<1)		;if transmitter and receiver have the same address
		out 	PORTB, mpr2
		ldi 	mpr, BotAddress		
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait		
		
TRANSMIT_SPD_UP_LOOP1:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rcall 	TRANSMIT_SPD_UP_LOOP1
		
		ldi 	mpr, SpeedUp
		sts 	UDR1, mpr

		ldi		waitcnt, 250
		rcall	Wait
		
TRANSMIT_SPD_UP_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_SPD_UP_LOOP2
		
		rjmp 	MAIN

;************************************************************

TRANSMIT_SPD_DOWN:					;Transmit Bot Address using UDR1 to be checked for Transmit Speed Down Function
		ldi		mpr2, (1<<0)		;if transmitter and receiver have the same address
		out 	PORTB, mpr2
		ldi 	mpr, BotAddress		
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait		
		
TRANSMIT_SPD_DOWN_LOOP1:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rcall 	TRANSMIT_SPD_DOWN_LOOP1
		
		ldi 	mpr, SpeedDown
		sts 	UDR1, mpr
		ldi		waitcnt, 250
		rcall	Wait
		
TRANSMIT_SPD_DOWN_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_SPD_DOWN_LOOP2
		
		rjmp 	MAIN

;************************************************************

TRANSMIT_SPD_MAX:					;Transmit Bot Address using UDR1 to be checked for Transmit Speed Max Function
		ldi 	mpr, BotAddress		;if transmitter and receiver have the same address
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait		
		
TRANSMIT_SPD_MAX_LOOP1:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rcall 	TRANSMIT_SPD_MAX_LOOP1
		
		ldi 	mpr, SpeedMax
		sts 	UDR1, mpr
		ldi		mpr2, (1<<3)
		out 	PORTB, mpr2
		ldi		waitcnt, 250
		rcall	Wait
		
TRANSMIT_SPD_MAX_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_SPD_MAX_LOOP2
		
		rjmp 	MAIN

;************************************************************

TRANSMIT_SPD_MIN:					;Transmit Bot Address using UDR1 to be checked for Transmit Speed Min Function
		ldi		mpr2, (1<<2)		;if transmitter and receiver have the same address
		out 	PORTB, mpr2
		ldi 	mpr, BotAddress		
		sts 	UDR1, mpr
		ldi 	waitcnt, 55
		rcall 	Wait		
		
TRANSMIT_SPD_MIN_LOOP1:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rcall 	TRANSMIT_SPD_MIN_LOOP1
		
		ldi 	mpr, SpeedMin
		sts 	UDR1, mpr
		ldi		waitcnt, 250
		rcall	Wait
		
TRANSMIT_SPD_MIN_LOOP2:
		lds 	mpr, UCSR1A
		sbrs 	mpr, UDRE1
		rjmp 	TRANSMIT_SPD_MIN_LOOP2
		
		rjmp 	MAIN
;************************************************************
;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt			; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt			; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret					; Return from subroutine

