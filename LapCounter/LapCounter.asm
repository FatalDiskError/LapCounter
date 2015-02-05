/*
 * LapCounter.asm
 *
 *  Created: 16.01.2015 21:46:21
 *   Author: FatalDiskError
 */ 

.include "m8def.inc"

.def zero = r1
.def temp = r16
.def digitToPrint = r17
.def digitByte = r18
.def controller_input = r19
.def lab_counter0_ones = r20
.def lab_counter0_tens = r21
.def lab_counter1_ones = r22
.def lab_counter1_tens = r23
.def flag = r24

.equ PIN_OG		= PB1
.equ PIN_R_CLK	= PB2
.equ PIN_S_CLK	= PB5
.equ PIN_SER	= PB3

.org 0x000
	rjmp reset_handler
/*
.org INT0addr
	rjmp int0_handler
.org INT1addr
	rjmp int1_handler
*/

reset_handler:
	// -------------------------------------
	; init stack pointer
	ldi temp, LOW(RAMEND)
	out SPL, temp
	ldi temp, HIGH(RAMEND)
	out SPH, temp

	ldi flag, 0

	// -------------------------------------
	; set B as output
	; set OG, R_CLK, S_CLK, SER as output
	; set PB4 as input
	ldi temp, 0xFF
	//cbr temp, PB4 ; (1<<PB4) // does not work somehow
	out DDRB, temp

	// -------------------------------------
	; set SPI
	; no int, MSB first, master
	; CPOL = 0
	; CPHA = 0
	; SCK clock = 1/2 XTAL
	ldi temp, (1<<SPE) | (1<<MSTR)
	out SPCR, temp

	ldi temp, (1<<SPI2X)
	; double speed
	out SPSR, temp
	; send dummy-data to set SPIF
	out SPDR, temp

	// -------------------------------------
	; set C as input
	ldi temp, 0x00
	out DDRC, temp

/*
	// -------------------------------------
	; set D as input
	ldi temp, 0x00
*/
	ldi temp, 0xff
	out DDRD, temp

	// -------------------------------------
	; reset counter
	rcall resetCounter

/*
	// -------------------------------------
	; configure interrupt
	; set int0/1 to falling flak
	ldi temp, (1<<ISC01) | (1<<ISC11)
	out MCUCR, temp
	; activate int0/1
	ldi temp, (1<<INT0) | (1<<INT1)
	out GICR, temp
	sei
*/

	// -------------------------------------
	; all segments & dot on
	ldi digitToPrint, 0
	rcall printDigit

loop:
	// -------------------------------------
	; ATmega8 has only 6 input pins for port c
	; if (controller_input == 0b00111111) => Z=1 => branch to loop
	in controller_input, PINC
	cpi controller_input, 0b00111111
	breq loop

	// -------------------------------------
	; increase lap counts
	sbrs controller_input, PC0
	rcall incLabCouter0

	sbrs controller_input, PC1
	rcall incLabCouter1

	sbrs controller_input, PC2
	nop

	sbrs controller_input, PC3
	rjmp resetAndSkipOutput

	rcall output
	rjmp loop

resetAndSkipOutput:
	rcall resetCounter
	rjmp loop

incLabCouter0:
	; increase ones
	inc lab_counter0_ones
	cpi lab_counter0_ones, 10

	; if counter != 10
	brne exitIncLabCouter0
	; else
	ldi lab_counter0_ones, 0

	; increase tens
	inc lab_counter0_tens
	cpi lab_counter0_tens, 10

	; if counter != 10
	brne exitIncLabCouter0
	; else
	ldi lab_counter0_tens, 0

exitIncLabCouter0:
	ret

incLabCouter1:
	; increase ones
	inc lab_counter1_ones
	cpi lab_counter1_ones, 10

	; if counter != 10
	brne exitIncLabCouter1
	; else
	ldi lab_counter1_ones, 0

	; increase tens
	inc lab_counter1_tens
	cpi lab_counter1_tens, 10

	; if counter != 10
	brne exitIncLabCouter1
	; else
	ldi lab_counter1_tens, 0

exitIncLabCouter1:
	ret

resetCounter:
	; set lab counters to 0
	ldi lab_counter0_ones, 1
	ldi lab_counter0_tens, 2
	ldi lab_counter1_ones, 3
	ldi lab_counter1_tens, 4

	sbr flag, 1
	rcall output
	ret

output:
	mov digitToPrint, lab_counter1_tens
	rcall printDigit
	sbrs flag, 0
	rcall wait

	mov digitToPrint, lab_counter1_ones
	rcall printDigit
	sbrs flag, 0
	rcall wait

	mov digitToPrint, lab_counter0_tens
	rcall printDigit
	sbrs flag, 0
	rcall wait

	mov digitToPrint, lab_counter0_ones
	rcall printDigit
	sbrs flag, 0
	rcall wait

	cbr flag, 1
	ret

printDigit:
	// -------------------------------------
	; set z-pointer to beginning of digit-table
	; word-based, therefor byte-adress "digits" is multiplied by 2
	ldi ZL, LOW(digits * 2)
	ldi ZH, HIGH(digits * 2)

	mov temp, digitToPrint      ; die wortweise Adressierung der Tabelle
	add temp, digitToPrint      ; berücksichtigen

	add ZL, temp         ; und ausgehend vom Tabellenanfang
	adc ZH, zero          ; die Adresse des Code Bytes berechnen

	lpm                       ; dieses Code Byte in das Register r0 laden
	mov digitByte, r0

	rcall transmitToShiftReg
	rcall outputToShiftReg

	ret

transmitToShiftReg:
	; check if prev transmission is done
	sbis SPSR, SPIF
	rjmp transmitToShiftReg

	; write data to shift reg
	out SPDR, digitByte

	ret

outputToShiftReg:
	; check if prev transmission is done
	sbis SPSR, SPIF
	rjmp outputToShiftReg

	sbi PORTB, PIN_R_CLK
	cbi PORTB, PIN_R_CLK

	ret

// brne: branch if z==0
// breq: branch if z==1
wait:
	ldi r25, 100
waitInner1:
	ldi r26, 100
waitInner2:
	ldi r27, 100
waitInner3:
	dec r27
	brne waitInner3
	dec r26
	brne waitInner2
	dec r25
	brne waitInner1
	ret

/*
int0_handler:
	ldi flag, 0xff
	inc lab_counter0
	reti

int1_handler:
	ldi flag, 0xff
	inc lab_counter1
	reti
*/

digits:
	/*
		  (1)         (2)
		|--a--|     |--a--|
		f     b     f     b
		|--g--|     |--g--|
		e     c     e     c
		|--d--|  h  |--d--|  h

		         1 2
		 o o o o + + 0 0 0
		###################
		#  (1)  ###  (2)  #
		###################
		 o o o o 0 0 0 0 0
		
		7 6 5 4 3 2 1 0
		e d g c h f a b

		0 = on
		1 = off

		0: ed_c_fab : 0b00101000
		1: ___c___b : 0b11101110
		2: edg___ab : 0b00011100
		3: _dgc__ab : 0b10001100
		4: __gc_f_b : 0b11001010
		5: _dgc_fa_ : 0b10001001
		6: edgc_fa_ : 0b00001001
		7: ___c__ab : 0b11101100
		8: edgc_fab : 0b00001000
		9: _dgc_fab : 0b10001000
		.: ____h___ : 0b11110111
	*/
	.db 0b00101000 // 0
	.db 0b11101110 // 1
	.db 0b00011100 // 2
	.db 0b10001100 // 3
	.db 0b11001010 // 4
	.db 0b10001001 // 5
	.db 0b00001001 // 6
	.db 0b11101100 // 7
	.db 0b00001000 // 8
	.db 0b10001000 // 9
	.db 0b11110111 // .
