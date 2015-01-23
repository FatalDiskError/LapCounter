/*
 * LapCounter.asm
 *
 *  Created: 16.01.2015 21:46:21
 *   Author: FatalDiskError
 */ 

/*
start:
	nop
	ldi R16, 0xff
	sts PORTE_DIR, r16

	ldi r17, 0x80
output:
	sts PORTE_OUT, r17
	rol r17

	ldi r16, 0x00
delay:
	ldi r18, 0x00
delay1:
	inc r18
	brne delay1
	inc r16
	brne delay
	break
	rjmp output
*/

.include "m8def.inc"

.def temp = r16
.def flag = r17
.def track_counter0 = r18
.def track_counter1 = r19

.org 0x000
	rjmp reset_handler
.org INT0addr
	rjmp int0_handler
.org INT1addr
	rjmp int1_handler

reset_handler:
	; init stack pointer
	ldi temp, LOW(RAMEND)
	out SPL, temp
	ldi temp, HIGH(RAMEND)
	out SPH, temp

	; set B as output
	ldi temp, 0xFF
	out DDRB, temp

	; set D as input
	ldi temp, 0x00
	out DDRD, temp

	; set track counters to 0
	ldi track0counter, 0x00
	ldi track1counter, 0x00

	; configure interrupt
	; set int0/1 to falling flak
	ldi temp, (1<<ISC01) | (1<<ISC11)
	out MCUCR, temp
	; activate int0/1
	ldi temp, (1<<INT0) | (1<<INT1)
	out GICR, temp

	sei

loop:
	;;in r16, PIND
	;lsr r16		;lsl/r logical shift left/right
	;lsr r16
	;com r16		;invert
	;;out PORTB, r16
	;cbi PORTB, 7
	;cbi PORTB, 0	;clear bit i [0-7]

	; check if flag == 0xff => Z=1 => branch to equal
	cpi flag, 0xff
	breq output

	rjmp loop

output:
	ldi flag, 0x00
	rjmp loop

int0_handler:
	ldi flag, 0xff
	inc track_counter0
	reti

int1_handler:
	ldi flag, 0xff
	inc track_counter1
	reti