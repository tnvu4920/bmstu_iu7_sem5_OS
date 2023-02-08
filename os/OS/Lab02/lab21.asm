.386P

desct struc ; структура описания дескрипторов сегментов
        limit     dw 0        ; граница (биты 0..15)
        base_l    dw 0        ; база (биты 0..15)
        base_m    db 0        ; база (биты 16..23)
        attr_1    db 0        ; атрибуты 1
        attr_2    db 0        ; граница (биты 16..19) и атрибуты 2
        base_h    db 0        ; база (биты 24..32)
desct ends

data segment
;  Таблица глобальных дескрипторов GDT 
        gdt_null   desct <0,0,0,0,0,0>                ; Селектор 0, нулевой дескриптор
        gdt_data   desct <data_size-1,0,0,92h>        ; Селектор 8, сегмент данных
        gdt_code   desct <code_size-1,,,98h>          ; Селектор 16, сегмент команд 
        gdt_stack  desct <255,0,0,92h>                ; Селектор 24, сегмент стека 
        gdt_screen desct <4095,8000h,0Bh,92h>         ; Селектор 32, видеопамять
        gdt_size = $-gdt_null                         ; размер GDT
        
        pdescr    df 0                                                ; псевдодескриптор для команды ldgt
        attr      db 1Eh                                              ; атрибут для вывода символа в видеопамять
        msg1      db 'Process working in real mode!',13,10,'$'        ; сообщение о переходе в реальный режим
        msg2      db 'Process working in protected mode!',13,10,'$'   ; сообщение о переходе в защищенный режим
        msg_null  db 13,10,'$'                                        ; переход на новую строку
        data_size=$-gdt_null                                          ; размер сегмента данных
data ends

codeseg segment 'code' use16
        assume CS:codeseg,DS:data
main proc
        xor     EAX, EAX
        mov     AX,  data                        ; загрузка сегметного адреса
        mov     DS,  AX                          ; сегмента данных в DS
        
        push    eax
        mov     ax, 3                            ; очистка экрана
        int     10h
        
        mov     AH, 09h                          ; печать сообщения
        mov     DX, offset msg1
        int     21h
        pop     eax

        ; вычисление линейных адресов сегментов
        shl     EAX, 4                     ; сдвигаем влево AX на 4 байта
        mov     EBP, EAX                   ; загружаем в АХ сегментный адрес сегмента данных            
        mov     BX, offset gdt_data        ; загружаем в BX смещение дескриптора 
        mov     [BX].base_l, AX            ; загружаем младшую часть базы
        rol     EAX, 16                    ; переносим старшую половину EAX и AX
        mov     [BX].base_m, AL            ; загружаем среднюю часть базы

        xor     EAX, EAX
        mov     AX, CS                     ; загружаем в АХ сегментный адрес сегмента кода
        shl     EAX, 4                     ; сдвигаем влево AX на 4 байта    
        mov     BX, offset gdt_code        ; загружаем в BX смещение дескриптора 
        mov     [BX].base_l, AX            ; загружаем младшую часть базы
        rol     EAX, 16                    ; переносим старшую половину EAX и AX
        mov     [BX].base_m, AL            ; загружаем среднюю часть базы

        xor     EAX, EAX
        mov     AX, SS                     ; загружаем в АХ сегментный адрес сегмента стека
        shl     EAX, 4                     ; сдвигаем влево AX на 4 байта
        mov     BX, offset gdt_stack       ; загружаем в BX смещение дескриптора 
        mov     [BX].base_l, AX            ; загружаем младшую часть базы
        rol     EAX, 16                    ; переносим старшую половину EAX и AX
        mov     [BX].base_m, AL            ; загружаем среднюю часть базы

        ; подготовка псевдодескриnтора pdescr и загрузка регистра GDTR 
        mov     dword ptr pdescr+2, EBP        ; загружаем базу GDT    
        mov     word ptr pdescr, gdt_size-1    ; загружаем границу GDT
        lgdt    pdescr                         ; загружаем псевдодескриптор в регистр GDTR 
        
        cli                                    ; запрет аппаратных прерываний
        mov     AL, 80h                        ; запрет маскируемых прерываний
        out     70h, AL

        mov     EAX, CR0                       ; получаем содержимое регистра CR0
        or      EAX, 1                         ; устанавливаем бит PE
        mov     CR0, EAX                

        ; -------------------------------------------
        ; Процессор работает в защищенном режиме
        ; -------------------------------------------
        ; Загрузка селектора в CS с помощью дальнего перехода
        db      0EAh                    ; код команды far jmp
        dw      offset continue         ; смещение
        dw      16                      ; селектор сегмента команд
    
    continue:
        ; сделаем адресуемыми данные
        mov     AX, 8                   ; селектор сегмента данных
        mov     DS, AX
        ; сделаем адресуемым стек
        mov     AX, 24                  ; селектор сегмента стека
        mov     SS, AX
        ; инициализируем видеобуфер
        mov     AX, 32                  ; селектор сегмента видеобуфера
        mov     ES, AX

        ; вывод сообщения в видеобуфер
        mov     BX, 170                 ; начальная позиция вывода в видеобуфере
        mov     CX, 34                  ; длина строки
        mov     SI, 0
        mov     AL, msg2[SI]            ; загружаем в AL символ строки
        mov     AH, attr                ; загружаем в AH атрибут символа
    
    screen: 
        mov     ES:[BX], AX             ; выводим символ в видеобуфер
        add     BX, 2
        add     SI,1
        mov     AL, msg2[SI]
        loop    screen

        mov     gdt_data.limit,   0FFFFh        ; загружаем границу сегмента данных
        mov     gdt_code.limit,   0FFFFh        ; загружаем границу сегмента кода
        mov     gdt_stack.limit,  0FFFFh        ; загружаем границу сегмента стека
        mov     gdt_screen.limit, 0FFFFh        ; загружаем границу доп. сегмента
        
        ; загрузка селекторов в сегментные регистры (перезапись содержимого теневых регистров)
        mov     AX, 8
        mov     DS, AX        ; загрузка теневого регистра сегмента данных
        mov     AX, 24
        mov     SS, AX        ; загрузка теневого регистра сегмента стека
        mov     AX, 32    
        mov     ES, AX        ; загрузка теневого регистра доп. сегмента 
        
        ; Загружаем в CS селектор с помощью дальнего перехода (загрузка
        ; теневого регистра сегмента кода)
        db      0EAh        
        dw      offset go
        dw      16

    go:    
        mov     EAX, CR0            ; получим содержимое регистра CR0
        and     EAX, 0FFFFFFFEh     ; сбросим бит PE
        mov     CR0, EAX            ; запишем назад в CR0

        ; Загружаем в CS сегментный адрес сегмента кода с помощью дальнего
        ; перехода (загрузка теневого регистра сегмента кода)
        db      0EAh
        dw      offset return
        dw      codeseg

        ; -------------------------------------------
        ; Процессор работает в реальном режиме
        ; -------------------------------------------

    return: 
        mov     AX, data           ; сделаем адресуемыми данные
        mov     DS, AX
        mov     AX, stk            ; сделаем адресуемым стек
        mov     SS, AX
        sti                        ; разрешаем аппаратные прерывания
        mov     AL, 0              ; разрешаем маскируемые прерывания
        out     70h, AL

        mov     AH, 09h                    ; переход на новую строку
        mov     DX, offset msg_null
        int     21h
        mov     AH, 09h                    ; печать сообщения
        mov     DX, offset msg1
        int     21h

        mov     AX, 4C00h        ; завершение программы
        int     21h
main endp

code_size=$-main                 ; размер сегмента кода
codeseg ends

stk     segment stack 'stack'
        db      256 dup ('^')
stk     ends

end main