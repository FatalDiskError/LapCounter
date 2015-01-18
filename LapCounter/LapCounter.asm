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

	ldi r16, 0xFF
	out DDRB, r16

	ldi r16, 0x00
	out DDRD, r16

loop:
	in r16, PIND
	;lsr r16		;lsl/r logical shift left/right
	;lsr r16
	;com r16		;invert
	out PORTB, r16
	;cbi PORTB, 7
	;cbi PORTB, 0	;clear bit i [0-7]
	rjmp loop
