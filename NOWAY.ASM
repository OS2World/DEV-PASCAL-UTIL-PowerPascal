      Title   _TEST

      .model  compact
      .code

WarningMsg    db       'This program requires OS/2 2.0 and P3+',0dh,0ah,24h

MAIN: mov     dx,Offset [WarningMsg]
      push    cs
      pop     ds
      mov     ah,9
      int     21h
      mov     ax,4c00h
      int     21h


      .stack  256
      .data


      end     Main
