               EXTRN   DOS32EXIT:NEAR
               EXTRN   DOS32WRITE:NEAR


_EXIT:         PUSHD   1
               CALL    DOS32EXIT


PutC:          push    eax         ; Store character on stack
               mov     eax,1
               push    eax         ; put the length below it
               mov     edx,esp     ; EDX points at this
               call    WriteStr
               add     esp,8
               ret



WriteEAX:      pushad
               lea     edx,NumBuffer
               call    Int_Str
               call    WriteStr
               popad
               ret

DoCr:          lea     edx,CrLfStr       ; Write a CR/LF pair
               call    WriteStr
               xor     eax,eax
               mov     OutPos,eax
               ret

WriteStr:                           ; writes string at [EDX]
               pushad
               xor     eax,eax      ; used as "actual count" storage
               push    eax
               mov     eax,esp      ; push the address of the previous push
               push    eax
               mov     eax,[edx]    ; push the string length

               add     OutPos,eax   ; update output position

               push    eax
               add     edx,4        ; push the string address
               push    edx
               pushd   stdout       ; push the handle to write to
               call    Dos32Write   ; do the write.
               add     esp,20       ; set the stack back to semi-normal
               popad
               ret


Int_Str:       pushad               ; No length required...
               mov     ebx,0
               jmp     Int_Str0

Int_StrLen:    pushad
Int_Str0:                           ; eax-value to print
                                    ; ebx-number of digits..
                                    ; edx-address of buffer to put it in.....
               pushd   0            ;
               mov     edi,ebx      ; edi now has count
               mov     ebx,edx      ; buffer address now in ebx
               mov     ecx,number_base
               lea     esi,table
Int_Str1:
               mov     edx,0
               div     ecx
               mov     edx,[edx+esi]
               push    edx
               dec     edi          ; bump counter
               and     eax,eax
               jnz     Int_Str1
               mov     edx,ebx      ; ebx --> count
               add     edx,4        ; edx --> string data
               mov     ecx,0        ; ecx = counter
Int_Str1a:
               or      edi,edi
               jle     Int_Str2
               xor     eax,eax
               mov     al,Number_Fill
               push    eax
               dec     edi
               jmp     Int_Str1a
Int_Str2:
               pop     eax
               or      al,al
               jz      Int_Str3
               mov     [edx],al
               inc     edx
               inc     ecx
               jmp     Int_Str2
Int_Str3:
               mov     [ebx],ecx
               popad
               ret


               .stack  8192
               .DATA

;---------------- I/O DOS Calls Only---------------
stdin          equ     0
stdout         equ     1
stderr         equ     2

;---------------- Useful ---------------
cr             equ     0dh
lf             equ     0ah
BEL            equ     07h
NULL           equ     0000h

Number_Base    DD      10
numbuffer      db      104h dup(?)   ; for number strings for debugging

number_fill    db      30h           ; '0'
table          db      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'

CrLfStr        dd      2
               db      0dh,0ah

OutPos         dd      0

