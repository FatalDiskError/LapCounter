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
.def temp_in = r20

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

	// -------------------------------------
	; set B as output
	; set OG, R_CLK, S_CLK, SER as output
	; set PB4 as input
	ldi temp, 0xFF
	//cbr temp, PB4 ; (1<<PB4)
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
	; set track counters to 0
	ldi track_counter0, 0x00
	ldi track_counter1, 0x00

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

	; all segments & dot on
	ldi temp, 0b11111111
	rcall transmitToShiftReg
	rcall outputToShiftReg

loop:
	/*
	; check if flag == 0xff => Z=1 => branch to equal
	cpi flag, 0xff
	breq output
	*/

	in temp_in, PINC
	cpi temp_in, 0b00111111
	breq loop

	/*
		  (2)
		|--b--|  0 = on
		c     a  1 = off
		|--f--|
		h     e
		|--g--|  d

		    12
		oooo++000
		#########
		# 1 # 2 #
		#########
		oooo00000
		
		7 6 5 4 3 2 1 0
		h g f e d c b a

		0: hg_e_cba : 0b00101000
		1: ___e___a : 0b11101110
		2: hgf___ba : 0b00011100
		3: _gfe__ba : 0b10001100
		4: __fe_c_a : 0b11001010
		5: _gfe_cb_ : 0b10001001
		6: hgfe_cb_ : 0b00001001
		7: ___e__ba : 0b11101100
		8: hgfe_cba : 0b00001000
		9: _gfe_cba : 0b10001000
		.: ____d___ : 0b11110111

	/** /
	sbrs temp_in, PC0
	ldi temp, 0b00101000 // 0
	sbrs temp_in, PC1
	ldi temp, 0b11101110 // 1
	sbrs temp_in, PC2
	ldi temp, 0b00011100 // 2
	sbrs temp_in, PC3
	ldi temp, 0b10001100 // 3
	sbrs temp_in, PC4
	ldi temp, 0b11001010 // 4
	sbrs temp_in, PC5
	ldi temp, 0b10001001 // 5
	/**/

	/** /
	sbrs temp_in, PC0
	ldi temp, 0b00001001 // 6
	sbrs temp_in, PC1
	ldi temp, 0b11101100 // 7
	sbrs temp_in, PC2
	ldi temp, 0b00001000 // 8
	sbrs temp_in, PC3
	ldi temp, 0b10001000 // 9
	sbrs temp_in, PC4
	ldi temp, 0b11110111 // .
	sbrs temp_in, PC5
	ldi temp, 0b00000000 // all
	/**/

	/*
	sbrs temp_in, PC6
	ldi temp, 0b10101010
	sbrc temp_in, PC7
	ldi temp, 0b10101010
	*/

	rcall transmitToShiftReg
	rcall outputToShiftReg

	rjmp loop

transmitToShiftReg:
	; check if prev transmission is done
	sbis SPSR, SPIF
	rjmp transmitToShiftReg

	; write data to shift reg
	out SPDR, temp

	ret

outputToShiftReg:
	; check if prev transmission is done
	sbis SPSR, SPIF
	rjmp outputToShiftReg

	sbi PORTB, PIN_R_CLK
	cbi PORTB, PIN_R_CLK

	ret

/*
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
*/