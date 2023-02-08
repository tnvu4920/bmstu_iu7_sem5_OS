.386p

descr struc     
	lim 		dw 0	
	base_l 	dw 0	
	base_m 	db 0	
	attr_1	db 0	
	attr_2	db 0	
	base_h 	db 0	
descr ENDS

int_descr struc 
	offs_l 	dw 0 	
	sel			dw 0	
	counter db 0  
	attr	db 0  
	offs_h 	dw 0  
int_descr ENDS

; Protected mode
PM_seg	SEGMENT PARA PUBLIC 'DATA' USE32
	                ASSUME	CS:PM_seg

    ; Таблица дескрипторов сегметов GDT
  	GDT		label	byte

  	; нулевой дескриптор
  	gdt_null	descr <>

  	; 32-битный 4-гигабайтный сегмент с базой = 0
  	gdt_flatDS	descr <0FFFFh,0,0,92h,11001111b,0>	; 92h = 10010010b

  	; 16-битный 64-килобайтный сегмент кода с базой RM_seg
  	gdt_16bitCS	descr <RM_seg_size-1,0,0,98h,0,0>	; 98h = 10011010b

  	; 32-битный 4-гигабайтный сегмент кода с базой PM_seg
  	gdt_32bitCS	descr <PM_seg_size-1,0,0,98h,01000000b,0>

  	; 32-битный 4-гигабайтный сегмент данных с базой PM_seg
  	gdt_32bitDS	descr <PM_seg_size-1,0,0,92h,01000000b,0>

  	; 32-битный 4-гигабайтный сегмент данных с базой stack_seg
  	gdt_32bitSS	descr <stack_l-1,0,0, 92h, 01000000b,0>

  	gdt_size = $-GDT ; размер нашей таблицы GDT+1байт (на саму метку)

  	gdtr	df 0

    ; имена для селекторов
    SEL_flatDS     equ   8
    SEL_16bitCS    equ   16
    SEL_32bitCS    equ   24
    SEL_32bitDS    equ   32
    SEL_32bitSS    equ   40

    ; Таблица дескрипторов прерываний IDT
    IDT	label	byte

    ; первые 32 элемента таблицы 
    trap_f int_descr 12 dup (<0, SEL_32bitCS, 0, 8Eh, 0>) 
	trap_13 int_descr <0, SEL_32bitCS, 0, 8Eh, 0>
	trap_s int_descr 19 dup (<0, SEL_32bitCS, 0, 8Eh, 0>)
    
    ; дескриптор прерывания от таймера
    int08 int_descr <0, SEL_32bitCS,0, 8Eh, 0>

    ; дескриптор прерывания от клавиатуры
    int09 int_descr	<0, SEL_32bitCS,0, 8Eh, 0>
    
    

    idt_size = $-IDT ; размер нашей таблицы IDT+1байт (на саму метку)

    idtr	df 0 ; переменная размера 6 байт как Регистр таблицы дескрипторов прерываний IDTR

    idtr_real dw	3FFh,0,0 ; содержимое регистра IDTR в реальном режиме

    master		db 0			; маска прерываний ведущего контроллера
    slave		db 0			; ведомого

    EScape		db 0			; флаг - в реальный режим, если ==1
    time_08		dd 0			; счетчик прошедших тиков таймера

		msg1 db 'IN ReAL Mode.$'
		msg2 db 13, 10, 'To Move to Protected Mode press any key...'
		     db 13, 10, 'To break the loop press Space...$'
		msg3 db 13, 10, 'IN Protected Mode'
		     db 13, 10, 'To break the loop press Enter...$'

		; Таблица символов ASCII для перевода из скан кода в код ASCII.
		; Номер скан кода = номеру соответствующего элемента в таблице:
	ASCII_table	db 0, 0, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 0, 0
			db 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 0, 0, 65, 83
			db 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67
			db 86, 66, 78, 77, 44, 46, 47
	OUT_position	dd 1E0h ; Позиция печати вводимого текста




print_str macro str
		MOV AH,9
		MOV DX, str
		INT  21h
endm

create_number macro
		local number1
			CMP  DL, 10
			JL number1
			ADD DL, 'A' - '0' - 10
		number1:
			ADD DL, '0'
endm

print_EAX macro
		local prcyc1 				
			PUSH ECX 					
			PUSH DX

			MOV ECX,8					
			ADD EBP,0B8010h 	
								
								
		prcyc1:
			MOV DL, AL			
			AND DL, 0Fh			
			create_number 0		
			MOV ES:[EBP],DL		
			ROR EAX,4			
								
			SUB EBP,2			
			LOOP prcyc1			

			SUB EBP,0B8010h		
			POP DX
			POP ECX
endm


	; точка входа в 32-битный защищенный режим
PM_entry:
		MOV	AX,SEL_32bitDS
		MOV	DS,AX
		MOV	AX,SEL_flatDS
		MOV	ES,AX
		MOV	AX,SEL_32bitSS
		MOV	EBX,stack_l
		MOV	SS,AX
		MOV	ESp,EBX

		; разрешить прерывания, запрещенные ранее ещё в реальном режиме
		STI

		CALL	compute_memory

work:
		TEST	EScape, 1
		JZ	work

goback:
		CLI
		
		db	0EAh 
		dd	offset RM_return
		dw	SEL_16bitCS

new_INT08:
		PUSH EAX
		PUSH EBP
		PUSH ECX
		PUSH DX
		MOV  EAX,time_08

		PUSH EBP
		MOV EBP, 0					
		print_EAX 0			
		POP EBP							

		INC EAX
		MOV time_08,EAX

		POP DX
		POP ECX
		POP EBP

		MOV	AL,20h
		OUT	20h,AL
		POP EAX

		IRETD

new_INT09:
		PUSH EAX
		PUSH EBX
		PUSH EBP
		PUSH EDX

		IN	AL,60h 		 ; Получаем скан-код нажатой клавиши из порта клавиатуры

		CMP AL,1Ch 	     ; Сравниваем с кодом Enter
		JNE not_leave 	 
		MOV EScape,1     
		JMP leav
not_leave:
		CMP  AL,80h 	 
		JA leav 	 
		XOR AH,ah	 
		MOV BP,AX
		MOV DL, ASCII_table[EBP] 
		MOV EBP,0B8000h
		MOV EBX,OUT_position   
		MOV ES:[EBP+EBX],DL

		ADD EBX,2			   
		MOV OUT_position,EBX
leav:
		
		IN	AL,61h
		OR	AL,80h
		OUT	61h,AL

		; Посылаем сигнал EOI:
		MOV	AL,20h
		OUT	20h,AL

		POP EDX
		POP EBP
		POP EBX
		POP	EAX

		; Выходим из прерывания:
		IRET

compute_memory	proc

		push	DS         
		MOV	AX, SEL_flatDS	
		MOV	DS, AX					
		MOV	EBX, 100001h		
		MOV	DL, 	10101010b	

		MOV	ECX, 0FFEFFFFEh	
check:
		MOV	DH, DS:[EBX]		
		MOV	DS:[EBX], DL		
		CMP DS:[EBX], DL		
		jnz	end_of_memory		
		MOV	DS:[EBX], DH		
		INC	EBX							

		LOOP	check
end_of_memory:
		POP	DS						
		xor	EDX, EDX
		MOV	EAX, EBX		
		MOV	EBX, 100000h		
		div	EBX

		PUSH EBP
		MOV EBP,20					
		print_EAX 0			
		POP EBP							
		RET
compute_memory	ENDP
   
except_1 proc
			iret
except_1 endp

except_13 proc
	pop eax
	iret
except_13 endp


	PM_seg_size = $-GDT
PM_seg	ENDS

stack_seg	SEGMENT  PARA STACK 'STACK' use32
	stack_start	db	100h dup(?)
	stack_l = $-stack_start							
stack_seg 	ENDS

RM_seg	SEGMENT PARA PUBLIC 'CODE' USE16		
	ASSUME CS:RM_seg, DS:PM_seg, SS:stack_seg

start:

		MOV   AX,PM_seg
		MOV   DS,AX

		MOV AH, 09h
		MOV EDX, offset msg1
		INT  21h

		MOV AH, 09h
		MOV EDX, offset msg2
		INT  21h

		;ожидаем ввода клавиатуры
		PUSH EAX
		MOV AH,10h
		INT  16h

		CMP  AL, 20h
		JE exit 
		POP EAX

		; очистить экран
		MOV	AX,3
		INT 	10h

		PUSH PM_seg
		POP DS

		xor	EAX,EAX
		MOV	AX,RM_seg
		shl	EAX,4		
		MOV	word ptr gdt_16bitCS.base_l,AX
		shr	EAX,16
		MOV	byte ptr gdt_16bitCS.base_m,AL
		MOV	AX,PM_seg
		shl	EAX,4
		PUSH EAX		; для вычисления адреса idt
		PUSH EAX		; для вычисления адреса gdt
		MOV	word ptr GDT_32bitCS.base_l,AX
		MOV	word ptr GDT_32bitSS.base_l,AX
		MOV	word ptr GDT_32bitDS.base_l,AX
		shr	EAX,16
		MOV	byte ptr GDT_32bitCS.base_m,AL
		MOV	byte ptr GDT_32bitSS.base_m,AL
		MOV	byte ptr GDT_32bitDS.base_m,AL

		; вычислим линейный адрес GDT
		POP EAX
		ADD	EAX,offset GDT
		MOV	dword ptr gdtr+2,EAX			
		MOV word ptr gdtr, gdt_size-1
		LGDT fword ptr gdtr

		; вычислим линейный адрес IDT
		POP	EAX
		ADD	EAX,offset IDT
		MOV	dword ptr idtr+2,EAX
		MOV word ptr idtr, idt_size-1

		; Заполним смещение в дескрипторах прерываний
		MOV	EAX, offset new_INT08 
		MOV	int08.offs_l, AX
		SHR	EAX, 16
		MOV	int08.offs_h, AX
		MOV	EAX, offset new_INT09
		MOV	int09.offs_l, AX
		SHR	EAX, 16
		MOV	int09.offs_h, AX
        
        MOV	EAX, offset except_1 
        MOV	trap_f.offs_l, AX
        SHR	EAX, 16
        MOV	trap_f.offs_h, AX

        MOV	EAX, offset except_1 
        MOV	trap_s.offs_l, AX
        SHR	EAX, 16
        MOV	trap_s.offs_h, AX

        MOV	EAX, offset except_13 
        MOV	trap_13.offs_l, AX
        SHR	EAX, 16
        MOV	trap_13.offs_h, AX

		; сохраним маски прерываний контроллеров
		IN	AL, 21h							
		MOV	master, AL					
		IN	AL, 0A1h						
		MOV	slave, AL
		MOV	AL, 11h							
		OUT	20h, AL							
		MOV	AL, 20h							
		OUT	21h, AL							
		MOV	AL, 4								
							
		OUT	21h, AL
		MOV	AL, 1							  
		OUT	21h, AL

		MOV AH, 09h
		MOV EDX, offset msg3
		INT  21h

		; Запретим все прерывания в ведущем контроллере, кроме IRQ0 и IRQ1
		MOV	AL, 0FCh
		OUT	21h, AL

		MOV	AL, 0FFh
		OUT	0A1h, AL

		; загрузим IDT
		LIDT	fword ptr idtr


		; если мы собираемся работать с 32-битной памятью, стоит открыть A20
		; А20 - линия ("шина"), через которую осуществляется доступ ко всей 
		IN	AL,92h						
		OR	AL,2							
		OUT	92h,AL						

		CLI
		
		IN	AL,70h
		OR	AL,80h
		OUT	70h,AL

		MOV	EAX,cr0
		OR	AL,1
		MOV	cr0,EAX

		db	66h
		db	0EAh
		dd	offset PM_entry
		dw	SEL_32bitCS

RM_return:
		MOV	EAX,cr0
		AND	AL,0FEh 				
		MOV	cr0,EAX

		db	0EAh						
		dw	$+4							
		dw	RM_seg

		MOV	AX,PM_seg				
		MOV	DS,AX
		MOV	ES,AX
		MOV	AX,stack_seg
		MOV	BX,stack_l
		MOV	SS,AX
		MOV	sp,BX

		;перепрограммируем ведущий контроллер обратно на вектор 8
		MOV	AL, 11h					
		OUT	20h, AL
		MOV	AL, 8						
		OUT	21h, AL
		MOV	AL, 4						
		OUT	21h, AL
		MOV	AL, 1
		OUT	21h, AL

		MOV	AL, master
		OUT	21h, AL
		MOV	AL, slave
		OUT	0A1h, AL

		LIDT fword ptr idtr_real

		IN	AL,70h
		AND	AL,07FH
		OUT	70h,AL

		STI

		MOV	AX,3
		INT 10h

		JMP start

		MOV AH, 09h
		MOV EDX, offset msg1
		INT  21h
exit:
		MOV	AH,4Ch
		INT 21h

RM_seg_size = $-start 
RM_seg	ENDS
END start