;***********************************************************
;* 
;*	Lab 8 RX
;*
;*	Enter the description of the program here
;*
;*	This is the RECEIVE skeleton file for Lab 8 of ECE 375
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
.def	speed = r21	
.def	speed_level = r22

.equ	WTime = 100				; Time to wait in wait loop
.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	BotAddress = 0b11111111

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

;Should have Interrupt vectors for:
;- Left whisker
;- Right whisker
;- USART receive

.org 	$0002
		rcall HitRight
		reti 
		
.org 	$0004
		rcall HitLeft
		reti
	
.org 	$0003C
		rcall USART_Receive
		reti
	
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
		ldi 	mpr, (1<<U2X1)
		sts 	UCSR1A, mpr
		;Set baudrate at 2400bps
		ldi 	mpr, high(416) 	; Load high byte of 0x0340 
		sts 	UBRR1H, mpr 	; UBRR0H in extended I/O space 
		ldi 	mpr, low(416) 	; Load low byte of 0x0340 
		sts 	UBRR1L, mpr 	

		;Enable receiver and enable receive interrupts
		ldi 	mpr, (1<<RXEN1 | 1<<TXEN1 | 1<<RXCIE1) 
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
	
	; Configure 8-bit Timer/Counters
		ldi		mpr, 0b01010000	; Fast PWM w/ toggle
		out		TCCR0, mpr		;
		ldi		mpr, 0b01010000
		out		TCCR2, mpr		;
		
		;default state
		ldi		speed_level, 0			;Initialize Speed level and clock
		out		OCR0, speed_level		
		out		OCR2, speed_level		

		ldi		speed, 0		;Initialize Speed
		andi	mpr, $F0		;
		or		mpr, speed		;
		out		PORTB, mpr		;

	; Initialize Fwd Movement
		ldi 	mpr, MovFwd
		out 	PORTB, mpr		
		
		sei
	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		rjmp MAIN


;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;----------------------------------------------------------------
; Sub:	USART_Receive
; Desc:	Receive USART Command from Transmitter 
;----------------------------------------------------------------
USART_Receive:
		lds  	mpr, UDR1			;Read Bot Address and compare
		ldi		mpr2, BotAddress	;if Bot Address is incorrect, then return interrupt
		cpse   	mpr, mpr2			;aka do nothing, else continue
		ret
		ldi		waitcnt, 55
		rcall	Wait

		
		lds		mpr, UDR1			;Read Action Code and Print it
		out 	PORTB, mpr			;Print Action Code

		ldi 	waitcnt, WTime
		rcall 	Wait

		cpi		mpr, (1<<6|1<<4)			;Check Speed Min, Speed Max, Speed Down, Speed Up bits
		breq	INPUT0
		cpi		mpr, ($80|1<<(EngDirL-1))				
		breq	INPUT1
		cpi		mpr, (1<<(EngDirR-1)|1<<(EngDirL-1))	
		breq	INPUT2
		cpi		mpr,($80|1<<(EngDirL))					
		breq	INPUT3

		rcall UPLOAD						;Update Leds			

		ldi		mpr, (1<<INT0 | 1<<INT1)	;Clean Queue
		out		EIFR, mpr
		
		ldi		waitcnt, 155
		rcall	Wait

		ret

;SPEED UP, SPEED DOWN, SPEED MIN, SPEED MAX FUNCTIONS FROM LAB 7
INPUT0:;min speed
		ldi		speed_level, 0		;Min Speed
		ldi		speed, 0

		out		OCR0, speed_level
		out		OCR2, speed_level
		rcall	UPLOAD			
		ret

INPUT1:;max speed 
		ldi		speed_level, 15		;Max Speed
		ldi		speed, $F		

		out		OCR0, speed_level
		out		OCR2, speed_level
		rcall   UPLOAD
		ret

INPUT2:;-speed
		cpi		speed_level,0		;Check if Min speed, else dec speed and speed level
		breq	INPUT0			

		dec		speed
		dec		speed_level		

		out		OCR0, speed_level
		out		OCR2, speed_level
		rcall	UPLOAD			
		ret

INPUT3:;+speed
		cpi		speed_level,15		;Check if Max Speed, else inc speed and speed level
		breq	INPUT1			

		ldi		mpr, 1			
		inc 	speed
		inc		speed_level		

		out		OCR0, speed_level
		out		OCR2, speed_level
		rcall	UPLOAD
		ret
;######################
UPLOAD: 
		ldi		mpr, Halt			;Update Leds
		or		mpr, speed		
		out		PORTB, mpr		
		ret
	
;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
HitRight:
		push	mpr			; Save mpr register
		push	waitcnt		; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		; Move Backwards for a second
		ldi		mpr, MovBck			; Load Move Backward command
		out		PORTB, mpr			; Send command to port
		ldi		waitcnt, WTime		; Wait for 1 second
		rcall	Wait				; Call wait function
		
		; Turn left for a second
		ldi		mpr, TurnL			; Load Turn Left Command
		out		PORTB, mpr			; Send command to port
		ldi		waitcnt, WTime		; Wait for 1 second
		rcall	Wait				; Call wait function
		
		ldi 	mpr,(1<<INT0 | 1<<INT1)	; clean the queue
		out 	EIFR,mpr
		
		
		; Move Forward again	
		ldi		mpr, MovFwd					; Load Move Forward command
		out		PORTB, mpr					; Send command to port
		ldi		mpr, (1<<INT0 | 1<<INT1)	;Clean Queue
		out		EIFR, mpr
		
		pop		mpr							; Restore program state
		out		SREG, mpr	
		pop		waitcnt						; Restore wait register
		pop		mpr							; Restore mpr
		ret									; Return from subroutine

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the left whisker
;		is triggered.
;----------------------------------------------------------------
HitLeft:
		push	mpr				; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG		; Save program state
		push	mpr				;

		; Move Backwards for a second
		ldi		mpr, MovBck		; Load Move Backward command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR		; Load Turn Left Command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		ldi 	mpr,(1<<INT0 | 1<<INT1)	; clean the queue
		out 	EIFR,mpr
		

		; Move Forward again	
		ldi		mpr, MovFwd					; Load Move Forward command
		out		PORTB, mpr					; Send command to port
		ldi		mpr, (1<<INT0 | 1<<INT1)	;Clean Queue
		out		EIFR, mpr
		
		pop		mpr							; Restore program state
		out		SREG, mpr					;
		pop		waitcnt						; Restore wait register	
		pop		mpr							; Restore mpr
		ret									; Return from subroutine

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

