.386p

descr struc         ; Структура для описания декскриптора сегмента в таблице глобальных дескрипторов GDT
	lim 	dw 0	; Граница (биты 0..15)  - размер сегмента в байтах
	base_l 	dw 0	; Младшие 16 битов адресной базы. - базовый адрес задаётся в виртуальном адресном пространстве
	base_m 	db 0	; Следующие 8 битов адресной базы.
	attr_1	db 0	; Флаги/атрибуты доступа, определяющие в каком кольце защиты
	attr_2	db 0	; можно использовать этот сегмент.
	base_h 	db 0	; Последние 8 битов адресной базы.
descr ends

int_descr struc     ; структура для описания декскриптора прерывания
	offs_l 	dw 0 	; Младшие 16 битов адреса, куда происходит переход в случае возникновения прерывания.
	sel		dw 0	; Селектор сегмента с кодом прерывания/Переключатель сегмента ядра
	counter db 0    ; 
	attr	db 0    ; Атрибуты
	offs_h 	dw 0    ; Старшие 16 битов адреса, куда происходит переход.
int_descr ends

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
  	gdt_32bitCS	descr <PM_seg_size-1,0,0,98h,01000000b, 0>

  	; 32-битный 4-гигабайтный сегмент данных с базой PM_seg
  	gdt_32bitDS	descr <PM_seg_size-1,0,0,92h,01000000b, 0>

  	; 32-битный 4-гигабайтный сегмент данных с базой stack_seg
  	gdt_32bitSS	descr <stack_l-1,0,0, 92h, 01000000b, 0>

  	gdt_size = $-GDT ; размер нашей таблицы GDT+1байт (на саму метку)

  	gdtr df 0	; переменная размера 6 байт как Регистр глобальной таблицы дескрипторов GDTR

    ; имена для селекторов
    SEL_flatDS     equ   8
    SEL_16bitCS    equ   16
    SEL_32bitCS    equ   24
    SEL_32bitDS    equ   32
    SEL_32bitSS    equ   40

    ; Таблица дескрипторов прерываний IDT
    IDT	label	byte

    ; первые 32 элемента таблицы (в программе не используются)
    int_descr 32 dup (<0, SEL_32bitCS,0, 8Eh, 0>)

    ; дескриптор прерывания от таймера
    int08 int_descr <0, SEL_32bitCS,0, 8Eh, 0>

    ; дескриптор прерывания от клавиатуры
    int09 int_descr	<0, SEL_32bitCS,0, 8Eh, 0>

    idt_size = $-IDT ; размер нашей таблицы IDT+1байт (на саму метку)

    idtr	    df 0            ; переменная размера 6 байт как Регистр таблицы дескрипторов прерываний IDTR
    idtr_real   dw	3FFh,0,0    ; содержимое регистра IDTR в реальном режиме
    master		db 0			; маска прерываний ведущего контроллера
    slave		db 0			; ведомого
    escape		db 0			; флаг - в реальный режим, если ==1
    time_08		dd 0			; счетчик прошедших тиков таймера

	msg1 db 'In Real Mode.$'
	msg2 db 13, 10, 'To move to Protected Mode press any key...'
		 db 13, 10, 'To break the loop press Space...$'
	msg3 db 13, 10, 'In Protected Mode'
		 db 13, 10, 'To break the loop press Enter...$'

		; Таблица символов ASCII для перевода из скан кода в код ASCII.
		; Номер скан кода = номеру соответствующего элемента в таблице:
	ASCII_table	db 0, 0, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 0, 0
			db 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 0, 0, 65, 83
			db 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67
			db 86, 66, 78, 77, 44, 46, 47
	out_position	dd 1E0h ; Позиция печати вводимого текста

print_str macro str
		mov ah,9
		mov dx, str
		int 21h
endm

create_number macro
		local number1
			cmp dl,10
			jl number1
			add dl,'A' - '0' - 10
		number1:
			add dl,'0'
endm

my_print_eax macro
		local prcyc1 				
			push ecx 					
			push dx

			mov ecx, 8					
			add ebp, 0B8010h 	; сейчас в EBP должно лежать положение первого символа на экране
								; 0B8000h - смещение видеобуффера относительно начала сегмента.
								; Ещё 10h - добавляем 8 символов, поскольку число печатается справа-налево
		prcyc1:
			mov dl,al			; кладём в DL текущее значение AL (самый младший байт ЕАХ)
			and dl,0Fh			; оставляем от него одно 16ричное число (последняя цифра)
			create_number 0		; превращаем это число в символ
			mov es:[ebp],dl		; запихиваем его в видеобуфер
			ror eax, 4			; циклически двигаем биты в ЕАХ - таким образом, после всех перестановок,
								; ЕАХ окажется тем же что и в начале, нет необходимости на PUSH; POP
			sub ebp, 2			; смещаемся на один символ влево (предыдущая цифра в ЕАХ)
			loop prcyc1			; повторяемся 8 раз
			sub ebp,0B8010h		
			pop dx
			pop ecx
endm


; точка входа в 32-битный защищенный режим
PM_entry:
		mov	ax,SEL_32bitDS
		mov	ds,ax
		mov	ax,SEL_flatDS
		mov	es,ax
		mov	ax,SEL_32bitSS
		mov	ebx,stack_l
		mov	ss,ax
		mov	esp,ebx

		; разрешить прерывания, запрещенные ранее ещё в реальном режиме
		sti

		call	compute_memory

work:
		test	escape, 1
		jz	work

goback:
		cli
		
		db	0EAh 
		dd	offset RM_return
		dw	SEL_16bitCS

new_int08:
		push eax
		push ebp
		push ecx
		push dx
		mov  eax,time_08

		push ebp
		mov ebp, 0					
		my_print_eax 0			
		pop ebp							

		inc eax
		mov time_08,eax

		pop dx
		pop ecx
		pop ebp

		mov	al,20h
		out	20h,al
		pop eax

		iretd

new_int09:
		push eax
		push ebx
		push ebp
		push edx

		in	al,60h 		 ; Получаем скан-код нажатой клавиши из порта клавиатуры

		cmp	al,1Ch 	     ; Сравниваем с кодом энтера
		jne	not_leave 	 
		mov escape,1     
		jmp leav
not_leave:
		cmp al,80h 	 
		ja leav 	 
		xor ah,ah	 
		mov bp,ax
		mov dl,ASCII_table[ebp] 
		mov ebp,0B8000h
		mov ebx,out_position   
		mov es:[ebp+ebx],dl

		add ebx,2			   
		mov out_position,ebx
leav:
		; Разрешаем обрабатывать клавиатуру дальше:
		in	al,61h
		or	al,80h
		out	61h,al

		; Посылаем сигнал EOI:
		mov	al,20h
		out	20h,al

		pop edx
		pop ebp
		pop ebx
		pop	eax

		; Выходим из прерывания:
		iretd

compute_memory	proc

		push	ds         
		mov	ax, SEL_flatDS	
		mov	ds, ax					
		mov	ebx, 100001h		; пропускаем первый мегабайт оного сегмента
		mov	dl,	10101010b	

		mov	ecx, 0FFEFFFFEh	
check:
		mov	dh, ds:[ebx]		
		mov	ds:[ebx], dl		
		cmp	ds:[ebx], dl		
		jnz	end_of_memory		
		mov	ds:[ebx], dh		
		inc	ebx							
							
		loop	check
end_of_memory:
		pop	ds						
		xor	edx, edx
		mov	eax, ebx		; в EBX лежит посчитанная память в байтах;
		mov	ebx, 100000h		; делим на 1 Мб
		div	ebx

		push ebp
		mov ebp,20					
		my_print_eax 0			
		pop ebp							
		ret
	compute_memory	endp


	PM_seg_size = $-GDT
PM_seg	ENDS

stack_seg	SEGMENT  PARA STACK 'STACK'
	stack_start	db	100h dup(?)
	stack_l = $-stack_start							
stack_seg 	ENDS

RM_seg	SEGMENT PARA PUBLIC 'CODE' USE16		
	ASSUME CS:RM_seg, DS:PM_seg, SS:stack_seg

start:

		mov   ax,PM_seg
		mov   ds,ax

		mov ah, 09h
		mov edx, offset msg1
		int 21h

		mov ah, 09h
		mov edx, offset msg2
		int 21h

		;ожидаем ввода клавиатуры
		push eax
		mov ah,10h
		int 16h

		cmp al, 20h
		je exit 
		pop eax

		; очистить экран
		mov	ax,3
		int	10h

		push PM_seg
		pop ds

		xor	eax,eax
		mov	ax,RM_seg
		shl	eax,4		; сегменты объявлены как PARA, нужно сдвинуть на 4 бита для выравнивания по границе параграфа
		mov	word ptr gdt_16bitCS.base_l,ax
		shr	eax,16
		mov	byte ptr gdt_16bitCS.base_m,al
		mov	ax,PM_seg
		shl	eax,4
		push eax		; для вычисления адреса idt
		push eax		; для вычисления адреса gdt
		mov	word ptr GDT_32bitCS.base_l,ax
		mov	word ptr GDT_32bitSS.base_l,ax
		mov	word ptr GDT_32bitDS.base_l,ax
		shr	eax,16
		mov	byte ptr GDT_32bitCS.base_m,al
		mov	byte ptr GDT_32bitSS.base_m,al
		mov	byte ptr GDT_32bitDS.base_m,al

		; вычислим линейный адрес GDT
		pop eax
		add	eax,offset GDT 				; в eax будет полный линейный адрес GDT (адрес сегмента + смещение GDT относительно него)
		mov	dword ptr gdtr+2,eax			
		mov word ptr gdtr, gdt_size-1	; в старшие 2 байта заносим размер gdt, из-за определения gdt_size (через $) настоящий размер на 1 байт меньше
		lgdt	fword ptr gdtr

		; вычислим линейный адрес IDT
		pop	eax
		add	eax,offset IDT
		mov	dword ptr idtr+2,eax
		mov word ptr idtr, idt_size-1

		; Заполним смещение в дескрипторах прерываний
		mov	eax, offset new_int08 
		mov	int08.offs_l, ax
		shr	eax, 16
		mov	int08.offs_h, ax
		mov	eax, offset new_int09
		mov	int09.offs_l, ax
		shr	eax, 16
		mov	int09.offs_h, ax

		; сохраним маски прерываний контроллеров
		in	al, 21h							
		mov	master, al					
		in	al, 0A1h						
		mov	slave, al
		mov	al, 11h							
		out	20h, al							
		mov	AL, 20h							
		out	21h, al							
		mov	al, 4								
							
		out	21h, al
		mov	al, 1							  
		out	21h, al

		mov ah, 09h
		mov edx, offset msg3
		int 21h

		; Запретим все прерывания в ведущем контроллере, кроме IRQ0 и IRQ1
		mov	al, 0FCh
		out	21h, al

		mov	al, 0FFh
		out	0A1h, al

		; загрузим IDT
		lidt	fword ptr idtr

		; если мы собираемся работать с 32-битной памятью, стоит открыть A20
		; А20 - линия ("шина"), через которую осуществляется доступ ко всей памяти за пределами первого мегабайта
		in	al,92h						
		or	al,2							
		out	92h,al						

		cli
		
		in	al,70h
		or	al,80h
		out	70h,al

		mov	eax,cr0
		or	al,1
		mov	cr0,eax

		db	66h
		db	0EAh
		dd	offset PM_entry
		dw	SEL_32bitCS

RM_return:
		mov	eax,cr0
		and	al,0FEh 				
		mov	cr0,eax

		db	0EAh						
		dw	$+4							
		dw	RM_seg

		mov	ax,PM_seg				
		mov	ds,ax
		mov	es,ax
		mov	ax,stack_seg
		mov	bx,stack_l
		mov	ss,ax
		mov	sp,bx

		;перепрограммируем ведущий контроллер обратно на вектор 8
		mov	al, 11h					
		out	20h, al
		mov	al, 8						
		out	21h, al
		mov	al, 4						
		out	21h, al
		mov	al, 1
		out	21h, al

		mov	al, master
		out	21h, al
		mov	al, slave
		out	0A1h, al

		lidt fword ptr idtr_real

		in	al,70h
		and	al,07FH
		out	70h,al

		sti

		mov	ax,3
		int	10h

		jmp start

		mov ah, 09h
		mov edx, offset msg1
		int 21h
exit:
		mov	ah,4Ch
		int	21h

RM_seg_size = $-start 
RM_seg	ENDS
END start