;
; lab7.asm
;
; Created: 2/27/2017 7:10:44 PM
; Author : sea_s
;


;***********************************************************
;*
;*	lab7
;*
;*	its lab7
;*
;*	This is the skeleton file for Lab 7 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Namtalay Laorattanavech
;*	   Date: 2/27/2017
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
;for wait function
.def	wait_time = r16			;
.def	ilcnt = r17				;
.def	olcnt = r18				;

.def	mpr = r19				; Multipurpose register
.def	speed = r20				; speed
.def	speed_level = r21		; level of speed xd


.equ	EngEnR = 4				; right Engine Enable Bit
.equ	EngEnL = 7				; left Engine Enable Bit
.equ	EngDirR = 5				; right Engine Direction Bit
.equ	EngDirL = 6				; left Engine Direction Bit


;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed

.org	$0046					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi		mpr, high(RAMEND);
		out		SPH, mpr		;
		ldi		mpr, low(RAMEND);
		out		SPL, mpr		;


		; Configure I/O ports
		; Initialize Port B for output
		ldi		mpr, $FF		; 
		out		DDRB, mpr		;
		ldi		mpr, $00		;
		out		PORTB, mpr		;

		; Initialize Port D for input
		ldi		mpr, $00		;
		out		DDRD, mpr		;
		ldi		mpr, $FF		; 
		out		PORTD, mpr		;

		; Configure External Interrupts, if needed

		; Configure 8-bit Timer/Counters
		ldi		mpr, 0b01111001	; Fast PWM w/ toggle
		out		TCCR0, mpr		;
		ldi		mpr, 0b01111001
		out		TCCR2, mpr		;
		

								; no prescaling

		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL)

		; Set initial speed, display on Port B pins 3:0

		; Enable global interrupts (if any are used)

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		;default state
		ldi		speed_level, 0		;
		out		OCR0, speed_level		;
		out		OCR2, speed_level		;

		ldi		speed, 0		; 
		andi	mpr, $F0		;
		or		mpr, speed		;
		out		PORTB, mpr		;

		
		; move forward
		ldi		mpr, (1<<EngDirL|1<<EngDirR)	;
		out		PORTB, mpr		;
		; poll Port D pushbuttons (if needed)

INPUT0:;min speed
		rcall	UPLOAD			;
		in		mpr, PIND		;
		andi	mpr, (1<<0|1<<1|1<<2|1<<3);

		cpi		mpr, (1<<1|1<<2|1<<3)	; 
		brne	INPUT1			;

		ldi		wait_time, 30	;
		rcall	Wait			;

		ldi		speed_level, 0		;Set speed and speed level to 0 
		ldi		speed, 0

		out		OCR0, speed_level;
		out		OCR2, speed_level;
		rjmp	INPUT0			;	

INPUT1:;max speed 
		cpi		mpr, (1<<0|1<<2|1<<3)	;	
		brne	INPUT2			;

		ldi		wait_time, 30	;
		rcall	Wait			;

		ldi		speed_level, 15	;
		ldi		speed, 255		;

		out		OCR0, speed_level;
		out		OCR2, speed_level;
		rjmp	INPUT0			;

INPUT2:;-speed
		cpi		mpr, (1<<0|1<<1|1<<3);
		brne	INPUT3			;

		ldi		wait_time, 30	;
		rcall	Wait			;

		cpi		speed_level,0	; check if speed already at min
		breq	INPUT0			;

		ldi		mpr, 17			;
		sub		speed, mpr 		;
		dec		speed_level		;

		out		OCR0, speed_level;
		out		OCR2, speed_level;
		rjmp	INPUT0			;

INPUT3:;+speed
		cpi		mpr,(1<<0|1<<1|1<<2)	;
		brne	INPUT0			;

		ldi		wait_time, 30	;
		rcall	Wait			;

		cpi		speed_level,15	;
		breq	INPUT0			;

		ldi		mpr, 17			;
		add		speed, mpr 		;
		inc		speed_level		;

		out		OCR0, speed_level;
		out		OCR2, speed_level;
		rjmp	INPUT0			;

;######################
UPLOAD: 
		in		mpr, PORTB		;
		andi	mpr, $F0		;
		or		mpr, speed		;
		out		PORTB, mpr		;
		ret
									
;----------------------------------------------------------------
; Sub:	Wait 
; Source: ECE375 Lab2's example code
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * wait_time + 13 + call
;----------------------------------------------------------------
Wait:
		push	wait_time			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		wait_time	; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		wait_time		; Restore wait register
		ret				; Return from subroutine

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	Template function header
; Desc:	Cut and paste this and fill in the info at the 
;		beginning of your functions
;-----------------------------------------------------------
FUNC:	; Begin a function with a label

		; If needed, save variables by pushing to the stack

		; Execute the function here
		
		; Restore any saved variables by popping from stack

		ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************
		; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
		; There are no additional file includes for this program
