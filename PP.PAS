Program PowerPascal;
{$X+}
{
  Who:  Michael Warot
  When: November 12,1989 (my 26'th Birthday!)
  What: The beginnings of a language compiler, takes source from
        STDIN, and generates Assembler Source for STDOUT

  Based on the article "The Nuts & Bolts of Compiler Construction"
                        By Jack W. Crenshaw
                        Computer Language
                        Volume 6, Number 3  (March 1989)

  KISS.PAS is pretty much the same as that given in the article, with
  the appropriate modifications for the MS-DOS environment.

  All further versions are based on my assumptions of what should be
  happening inside a compiler. You learn many interesting things when
  you write your own compiler.

  Triva: _ is a valid variable name!

  Output to assembler file is to eliminate the need for handling
  variable allocation, symbol table handling, and linking.
  This does, however make optimization more difficult.

/-Version Number
|
|  Additions & Modifications from previous version....
V ----------------------------------------------------------------------------

2 GetName returns a multi-character name
2 GetNum  returns a multi-digit number

3 SkipSpace procedure added, handles tabs, cr, lf, and spaces
3 Match handles a string (for ':=')
3 Match, GetName, and GetNum all call SkipSpace after doing thier work

4 Statement procedure added to allow for other than assignments
4 NewLabel  returns a label for jumps, etc
4 PutLabel  anchors a jump to a particular address
4 JumpTo    generates code for a jump
4 IfJumpTo  generates "Jump if <> 0"
4 IfNotJumpTo generates "Jump if = 0"
4 While_Loop generates proper code for: while..expression..do..statement
4 BlockStatement handles begin..statement..[;..statement]..end
4 Repeat_Loop handles repeat..[statement..;]..until
4 _Program handles whole program generation
4 ProgramExit generates DOS exit code

6 Procedure GetToken added
  Handles brace comments
  Handles $12FaC hex constants
  Handles 1243 decimal constants
  Handles 'string constants' and checks for un-terminated string constant
6 Procedure Match modified to expect a token.
  All routines now use GetToken properly

7 Added simple symbol table
  Added routines to put variables after the end of the code
7 Added routines to generate prefix and suffix code
7 Added EMIT to generate some output, for testing, etc.

8 Add FOR x := y TO z DO
  Add WriteLn
  Fix gettoken, so that writeln matches writeln, not write!
  Add Inc_Const, for better code output...

9 Eliminate spurious comments in generated listing
  Put all code generation in GenCode

10 Add variable support, instead of adding variables on the fly.
   Add type support, instead of default to integer

12 Fix bug in FOR, didn't allocate variable for limit correctly...

13 Move input and output from stdin and stdout to file I/O.

14 Add line number to error message, to make life a little easier.
   Fix missing DUP in storage declarations to MASM causeing misallocation

   Add support for string expressions....   (NIY)
   Add support for variable types           (NIY)
   Add automatic casting...                 (NIY)
   Fix bug in gettoken that handled '' as a string constant improperly
   Add code to handle (* *) comments

04/22/93 - Power Pascal Version 0.001 (Or do you say Pascal/2?)
15 Modify to generate OS/2 Full Screen 32 Bit code!

04/23/93 - Version 0.002
   Revise code, add VOID type, IsVar flag in symbol table
   Use code from \GENERIC\CONFIG for '' handling, fixes problems with ''''
   and such.
   Start adding support code for procedures, etc.
}
Uses
  Swap;
Const
  CR  = ^M;
  LF  = ^J;
  Tab = ^I;
  HexCode   = '0123456789ABCDEF';

  MASM      = 'C:\MASM\MASM.EXE';
  LINK      = 'C:\OS2\LINK386.EXE';

Type
  Str32     = String[32];
  Token     = (_Unknown,_string_constant,_numeric_Constant,_name,
               _program,_Var,_Begin,_While,_do,_repeat,_Until,
               _Emit,_Write,_WriteLn,
               _period,_comma,
               _plus,_minus,_mul,_div,_lparen,_rparen,_separator,
               _assign,_equal,_greater,_less,_less_eq,_greater_eq,_not_eq,
               _colon,
               _if,_then,_else,_for,_to,
               _procedure,_function,
               _end);

  ObjCode   = (_Call,_Return,_Clear,_LoadConst,_LoadVar,_Push,_PopAdd,_PopSub,
               _PopMul,_PopDiv,_Store,_Inc_Const,_PutLabel,
               _JumpTo,_IfJumpTo,_IfNotJumpTo,
               _ProgramInit,_ProgramExit,
               _Logical,_Logical_Not,
               Greater,Less,_PutC,_PutWord,_PutCrLf,_PutString);
Const
  MaxToken  = Ord(_end);
  TokenName : Array[0..MaxToken] of Str32 =
              ('','','','',
               'PROGRAM','VAR','BEGIN','WHILE','DO','REPEAT','UNTIL',
               'EMIT','WRITE','WRITELN',
               '.',',',
               '+','-','*','/','(',')',';',
               ':=','=','>','<','<=','>=','<>',':',
               'IF','THEN','ELSE','FOR','TO',
               'PROCEDURE','FUNCTION',
               'END');

Type
  NameStr   = String;
  LabelStr  = String;
Var
  Look           : Char;
  Current_String : String;
  Current_Token  : Token;
  Current_Number : Longint;

  Source,Dest    : Text;
  Name           : String;
  LineCount      : Longint;

function  numb(i : integer):string;
var
  s : string;
begin
  str(i,s);
  numb := s;
end;

Procedure Abort(S : String); Forward;

Procedure GetChar;
begin
  if Not Eof(Source) then Read(Source,Look)
                     else Look := '.';
  {                      Abort('Unexpected end of file'); }
  If Look = #13 then Inc(LineCount);
end;

procedure SkipSpace;
begin
  While (look in [Cr,Lf,Tab,' ']) AND (Not Eof(Source)) do
    GetChar;
end;

Procedure GetToken;
label
  restart,
  done;
var
  i,j : word;
  x   : boolean;
  last: char;
begin
RESTART:
  Current_String := '';
  Current_Token  := _Unknown;
  Current_Number := 0;
  SkipSpace;
  Case Look of
    '{'  : begin
             repeat
               GetChar;
             until Look = '}';
             GetChar;
             Goto Restart;
           end;

    '('  : begin
             getchar;
             if look = '*' then
             begin
               getchar;
               repeat
                 last := look;
                 getchar;
               until (last = '*') and (look = ')');
               getchar;

               Goto Restart;
             end
             else
               current_token := _lparen;
           end;

    '''' : begin
             getchar;
             current_string := '';
             x := false;
             repeat
               case look of
                 cr    : abort('String exceeds line');
                 ''''  : begin
                           getchar;
                           if look <> '''' then
                             x := true
                           else
                           begin
                             current_string := current_string + look;
                             getchar;
                           end;
                         end;
               else
                 current_string := current_string + look;
                 getchar;
               end;
             until x;
             current_token := _string_constant;
           end;

    '$'  : begin
             GetChar;
             While (UpCase(Look) in ['0'..'9','A'..'F']) do
             begin
               Current_Number := Current_Number SHL 4 +
                                 Pos(UpCase(Look),HexCode)-1;
               GetChar;
             end;
             Current_Token := _numeric_constant;
           end;
    '0'..'9' : begin
                 while look in ['0'..'9'] do
                 begin
                   Current_Number := Current_Number * 10 +
                                     Pos(Look,HexCode)-1;
                   GetChar;
                 end;
                 current_token := _numeric_constant;
               end;
    '_','A'..'Z',
        'a'..'z'   : begin
                       While UpCase(Look) in ['_','0'..'9',
                                                  'A'..'Z',
                                                  'a'..'z' ] do
                       begin
                         Current_String := Current_String + UpCase(Look);
                         GetChar;
                         for i := 0 to MaxToken do
                           if Current_String = TokenName[i] then
                           begin
                             Current_Token := Token(i);
                          {   goto done; }
                           end;
                       end;
                       If Current_Token = _Unknown then
                         Current_Token := _name;
                     end;
  else
    Current_String := UpCase(Look); GetChar;
    Repeat
      J := 0;
      For i := 0 to MaxToken do
        if (Current_string+UpCase(Look)) = TokenName[i] then
          J := i;
      If J <> 0 then
      begin
        Current_String := Current_String + UpCase(Look);
        GetChar;
      end;
    Until J = 0;

    For i := 0 to MaxToken do
      if Current_String = TokenName[i] then
        J := i;
    Current_Token := Token(j);
  end; { Case Look }

{ If we get here, we have a string that makes no sense! }

DONE:
end;

(*********************
    Error Reporting
 *********************)

procedure Error(s : string);
begin
  WriteLn;
  WriteLn(^G,'(',LineCount+1,') Error: ',s,'.');
end;

procedure Abort(S : String);
begin
  Error(S);
  Halt;
end;

procedure Expected(s : string);
begin
  Abort(s + ' Expected');
end;

(*************************
     Symbol Table Stuff
 *************************)
Const
  _Integer = 0;
  _Byte    = 1;
  _Long    = 2;
  _Void    = 3;
Type
  TType    = Record
               Name  : String[32];
               Size  : Word;
             End;

  Symbol   = Record
               Name  : String[32];
               Kind  : Integer;
               IsVar : Boolean;
             End;

Const
  TypeInteger  : TType = (Name : '_INTEGER'; Size :2);
  TypeByte     : TType = (Name : '_BYTE';    Size :1);
  TypeLong     : TType = (Name : '_LONG';    Size :4);
  TypeVoid     : TType = (Name : '_VOID';    Size :0);
Var
  SymbolTable  : Array[0..512] of Symbol;
  SymbolCount  : Integer;

  TypeTable    : Array[0..512] of TType;
  TypeCount    : Integer;

  StringConst  : Array[0..63]  of String;
  StringCount  : Integer;

function ToUpper(S : String):String;
begin
  asm
    cld
    lea    si,S
    les    di,@Result
    SEGSS  lodsb
    stosb
    xor    ah,ah
    xchg   ax,cx
    jcxz   @3
  @1:
    SEGSS  lodsb
    cmp    al,'a'
    ja     @2
    cmp    al,'z'
    jb     @2
    sub    al,20H
  @2:
    stosb
    loop   @1
  @3:
  end;
end;

function GetName:String;
begin
  If Current_Token = _Name then
    GetName := '_' + ToUpper(Current_String)
  else
    Expected('Name');
  GetToken;
end;

function GetNumber:Integer;
begin
  GetNumber := Current_Number;
  GetToken;
end;

Procedure AddSymbol(_Name : String; _Kind : Integer; _IsVar : Boolean);
Begin
  SymbolTable[SymbolCount].Name  := _Name;
  SymbolTable[SymbolCount].Kind  := _Kind;
  SymbolTable[SymbolCount].IsVar := _IsVar;
  Inc(SymbolCount);
End; { AddSymbol }

Function LookSymbol(_Name : String):Integer;
{ True if _NAME is in table }
Var
  q,r : Integer;
Begin
  r := -1;
  For q := 0 to SymbolCount-1 do
    If SymbolTable[q].Name = _Name then
      r := q;
  If r <> -1 then
    LookSymbol := SymbolTable[r].Kind
  else
    LookSymbol := -1;
End;

Function CheckSymbol(_Name : String): Integer;
Var
  tmp : integer;
Begin
  tmp := LookSymbol(_Name);
  if tmp = -1 then
    Expected('identifier');
  CheckSymbol := tmp;
End;

Procedure DumpSymbols;
var
  i : integer;
Begin
  WriteLn(Dest,'; Variable Area');
  for i := 0 to SymbolCount - 1 do
    If SymbolTable[i].IsVar then
      WriteLn(Dest,SymbolTable[i].Name,TAB,
                   'DB',TAB,
                   TypeTable[SymbolTable[i].Kind].Size,TAB,
                   'DUP (?)');
End;

Function LookType(    _Name : String):Integer;
{ True if _NAME is in table }
Var
  q,r : Integer;
Begin
  r := -1;
  For q := 0 to TypeCount-1 do
    If TypeTable[q].Name = _Name then
      r := q;
  LookType := r;
End;

Procedure CheckType(_Name : String);
Begin
  If (LookType(_Name) = -1) then
    Expected('type');
End;

Function DoStringConst(S : String):String;
Begin
  StringConst[StringCount] := S;
  DoStringConst := '_STR'+Numb(StringCount);
  Inc(StringCount);
End;


Procedure DumpStrings;
Var
  i : integer;
  j : byte;
  s : string;
Begin
  WriteLn(Dest,'; String constants');
  for i := 0 to StringCount-1 do
  begin
    s := StringConst[i];
    WriteLn(Dest,'_STR'+Numb(i),TAB,
                 'DD',TAB,
                 Numb(Length(S)));
    Write(Dest,TAB,'DB',TAB,'''');
    For j := 1 to length(s) do
      If S[j] <> '''' then
        Write(Dest,S[j])
      else
        Write(Dest,'''''');
    WriteLn(Dest,'''');
  end;
End;


(*************************
      Code Generator
 *************************)
Var
  LabelCount : Word;

procedure Emit(s : string);
begin
  Write(Dest,'      ', s);
end;

procedure EmitLn(s : string);
begin
  Emit(s);
  WriteLn(Dest);
end;

function  NewLabel:LabelStr;
var
  tmp : string;
begin
  Str(LabelCount,tmp); Inc(LabelCount);
  tmp := 'L'+tmp;
  NewLabel := tmp;
end;

Function GenCode(c : ObjCode;
                   n : integer;
                   s : string) : integer;
Var
 Tmp : String;
 x,y : integer;
Begin
  Case c of
    _Call       : EmitLn('CALL  '+S);
    _Return     : EmitLn('RET');
    _Clear      : EmitLn('XOR   EAX,EAX');
    _LoadConst  : EmitLn('MOV   EAX,'+Numb(N));
    _LoadVar    : begin
                    x := CheckSymbol(s);
                    y := TypeTable[x].Size;
                    Case Y of
                      1 : begin
                            EmitLn('XOR   EAX,EAX');
                            EmitLn('MOV   AL,BYTE PTR['+S+']');
                          end;
                      2 : begin
                            EmitLn('XOR   EAX,EAX');
                            EmitLn('MOV   AX,WORD PTR['+S+']')
                          end;
                      4 : EmitLn('MOV   EAX,DWORD PTR['+S+']');
                    else
                        Abort('Illegal variable size');
                    end;
                  end;

    _Push       : EmitLn('PUSH  EAX');
    _PopAdd     : begin
                    EmitLn('POP   EBX');
                    EmitLn('ADD   EAX,EBX');
                  end;
    _PopSub     : begin
                    EmitLn('POP   EBX');
                    EmitLn('SUB   EBX,EAX');
                    EmitLn('MOV   EAX,EBX');
                  end;
    _PopMul     : begin
                    EmitLn('POP   EBX');
                    EmitLn('MUL   EBX');
                  end;
    _PopDiv     : begin
                    EmitLn('MOV   EBX,EAX');
                    EmitLn('XOR   EDX,EDX');
                    EmitLn('POP   EAX');
                    EmitLn('DIV   EBX');
                  end;
    _Store      : begin
                    x := CheckSymbol(s);
                    y := TypeTable[x].Size;
                    Case Y of
                      1 : EmitLn('MOV   BYTE  PTR['+S+'],AL ');
                      2 : EmitLn('MOV   WORD  PTR['+S+'],AX ');
                      4 : EmitLn('MOV   DWORD PTR['+S+'],EAX');
                    else
                      Abort('Illegal variable size');
                    end;
                  end;
    _Inc_Const  : begin
                    if N = 1 then
                      EmitLn('INC   ['+S+']')
                    else
                      EmitLn('ADD   ['+S+'],'+numb(N) );
                  end;
    _PutLabel   : WriteLn(Dest,S+':');
    _JumpTo     : EmitLn('JMP   '+S);
    _IfJumpTo   : Begin
                    Tmp := NewLabel;
                    EmitLn('OR    EAX,EAX');
                    EmitLn('JNZ   '+S);
                  End;

    _IfNotJumpTo: Begin
                    Tmp := NewLabel;
                    EmitLn('OR    EAX,EAX');   { Avoid 128 byte jump bounds }
                    EmitLn('JZ    '+S);
                  End;

    _ProgramInit: Begin
                    WriteLn(Dest,'      .386                        ');
                    WriteLn(Dest,'      .model   flat,syscall,os_os2');
                    WriteLn(Dest,'      .code                       ');
                  End;

    _ProgramExit: Begin
                    EmitLn('CALL  _EXIT');
                  End;

    _Logical    : Begin
                    EmitLn('NEG   EAX');         { AX <> 0 ---> Carry  }
                    EmitLn('MOV   EAX,0');       {       0 ---> AX     }
                    EmitLn('SBC   EAX,EAX');     { Carry  ----> ALL AX }
                  End;

    _Logical_Not: Begin
                    EmitLn('NEG   EAX');         { AX <> 0 ---> Carry  }
                    EmitLn('MOV   EAX,-1');      {      -1 ---> AX     }
                    EmitLn('ADC   EAX,0');       { Not Carry -> ALL AX }
                  End;

    Greater     : Begin
                    EmitLn('POP   EBX');
                    EmitLn('SUB   EAX,EBX');
                    EmitLn('MOV   EAX,0' );
                    EmitLn('SBB   EAX,0' );
                  end;

    Less        : Begin
                    EmitLn('POP   EBX');
                    EmitLn('SUB   EBX,EAX');
                    EmitLn('MOV   EAX,0' );
                    EmitLn('SBB   EAX,0' );
                  end;

    _PutC       : EmitLn('CALL  PUTC');

    _PutWord    : EmitLn('CALL  WriteEAX');

    _PutCrLf    : EmitLn('CALL  DoCR');

    _PutString  : Begin
                    EmitLn('LEA   EDX,'+S);
                    EmitLn('CALL  WriteStr');
                  End;

  else
    Abort('Unknown ObjCode');
  end;
End;

(**********************
    Parsing Routines
 **********************)

function IsCompareOp(x : token): boolean;
begin
  IsCompareOp := x in [_equal.._not_eq];
end;

function IsAddOp(x : token): boolean;
begin
  IsAddOp := x in [_plus,_minus];
end;

function IsMulOp(x : token): boolean;
begin
  IsMulOp := x in [_mul,_div];
end;

procedure Match(x : Token);
begin
  If Current_Token <> X then
  begin
    If Ord(X) <= MaxToken then
      Expected(TokenName[ord(x)])
    else
      Abort('Unknown Token expected, compiler error!');
  end
  else
    GetToken;
end;

(*************************
    Expression Parser
 *************************)

function  Expression:integer; Forward;
function  Value:integer;
var
  kind : integer;
begin
  kind := -1;
  If Current_Token = _lparen then
  begin
    Match(_lparen);
    kind := Expression;
    Match(_rparen);
  end
  else
  begin
    If Current_Token = _name then
      Kind := GenCode(_LoadVar,0,GetName)
    else
      If Current_Token = _numeric_constant then
        Kind := GenCode(_LoadConst,GetNumber,'')
      else
        Error('Error in expression');
  end;
end;

procedure Factor;
var
  tmp : token;
  kind : integer;
begin
  kind := Value;
  while IsCompareOp(Current_Token) do
  begin
    GenCode(_Push,kind,'');
    tmp := Current_Token;
    Match(tmp);
    Value;

    case tmp of
      _equal       : begin
                       GenCode(_PopSub,     kind,'');
                       GenCode(_Logical,    kind,'');
                     end;
      _not_eq      : begin
                       GenCode(_PopSub,     kind,'');
                       GenCode(_Logical_Not,kind,'');
                     end;
      _greater     : GenCode(Greater,     kind,'');
      _less        : GenCode(Less,        kind,'');
      _greater_eq  : begin
                       GenCode(Less,        kind,'');
                       GenCode(_Logical_Not,kind,'');
                     end;
      _less_eq     : begin
                       GenCode(Greater,     kind,'');
                       GenCode(_Logical_Not,kind,'');
                     end;
    end;
  end;
end;

procedure Multiply;
begin
  Match(_mul);
  Factor;
  GenCode(_PopMul,0,'');
end;

procedure Divide;
begin
  Match(_div);
  Factor;
  GenCode(_PopDiv,0,'');
end;

procedure Term;
begin
  Factor;
  while IsMulOp(Current_Token) do
  begin
    GenCode(_Push,0,'');
    case Current_Token of
      _mul : Multiply;
      _div : Divide;
    end;
  end;
end;

procedure Add;
begin
  Match(_plus);
  Term;
  GenCode(_PopAdd,0,'');
end;

procedure Subtract;
begin
  Match(_minus);
  Term;
  GenCode(_PopSub,0,'');
end;

function Expression : integer;     { returns expression type }
var
  kind : integer;
begin
  kind := -1;
  If IsAddOp(Current_Token) then GenCode(_Clear,0,'')
                            else Term;
  while IsAddOp(Current_Token) do
  begin
    GenCode(_Push,0,'');
    case Current_Token of
      _plus   : Add;
      _minus  : Subtract;
    end;
  end;
  Expression := kind;
end;

(*************************
     Statement Parser
 *************************)

procedure Statement; Forward;

procedure Assignment;
var
  tmp : string;
begin
  Tmp := GetName;

  If LookSymbol(Tmp) = _Void then
  begin
    GenCode(_Call,0,Tmp);
  end
  else
  begin
    Match(_assign);
    Expression;
    GenCode(_Store,0,Tmp);
  end;
end;

procedure While_Loop;
var
  TestLabel,
  DoneLabel : LabelStr;
begin
  Match(_While);

  TestLabel := NewLabel;
  DoneLabel := NewLabel;

  GenCode(_PutLabel,0,TestLabel);
  Expression;
  GenCode(_IfNotJumpTo,0,DoneLabel);
  Match(_do);

  Statement;
  GenCode(_JumpTo,0,TestLabel);

  GenCode(_PutLabel,0,DoneLabel);
end;

procedure For_Loop;
var
  DoneLabel,
  TestLabel   : LabelStr;
  Index,Limit : String;
begin
  Match(_For);
  TestLabel  := NewLabel;
  DoneLabel  := NewLabel;

  Index := GetName;
  Limit := 'Lim'+Index;
  AddSymbol(Limit,_Long,True);
  Match(_assign);
  Expression;  GenCode(_Store,0,Index);
  Match(_to);
  Expression;  GenCode(_Store,0,Limit);

  GenCode(_PutLabel,0,TestLabel);
  Match(_do);
  GenCode(_LoadVar,0,Index);
  GenCode(_Push,0,'');
  GenCode(_LoadVar,0,Limit);
  GenCode(Greater,0,'');
  GenCode(_IfJumpTo,0,DoneLabel);

  Statement;
  GenCode(_Inc_Const,1,Index);
  GenCode(_JumpTo,0,TestLabel);

  GenCode(_PutLabel,0,DoneLabel);
end;

procedure If_Then_Else;
var
  ElseLabel,
  DoneLabel  : LabelStr;
begin
  Match(_If);

  ElseLabel := NewLabel;
  DoneLabel := NewLabel;

  Expression;
  Match(_then);
  GenCode(_IfNotJumpTo,0,ElseLabel);

  Statement;

  If Current_Token = _Separator then
    GenCode(_PutLabel,0,ElseLabel)
  else
  begin
    Match(_else);
    GenCode(_JumpTo,0,DoneLabel);
    GenCode(_PutLabel,0,ElseLabel);
    Statement;
  end;

  GenCode(_PutLabel,0,DoneLabel);
end;

procedure BlockStatement;
var
  tmp : NameStr;
begin
  Match(_Begin);

  while Current_Token <> _End do
  begin
    If Current_Token = _Separator then
      GetToken
    else
      Statement;
  end;
  Match(_End);
end;

procedure VarStatement(var kind : integer);
var
  Name : NameStr;
begin
  Name := GetName;
  If (Current_Token = _Comma) then
  begin
    Match(_Comma);
    VarStatement(kind);
  end
  else
  begin
    Match(_Colon);
    kind := LookType(GetName);
    If Kind = -1 then Expected('TYPE');
  end;
  AddSymbol(Name,kind,True);
end;

procedure VarBlock;
var
  tmp  : NameStr;
  kind : integer;
begin
  Match(_Var);
  while (Current_Token = _Name) do
  begin
    VarStatement(kind);
    Match(_separator);
  end;
end;

procedure Repeat_Loop;
var
  tmp   : NameStr;
  Start : LabelStr;
begin
  Match(_Repeat);

  Start := NewLabel;
  GenCode(_PutLabel,0,Start);

  repeat
    If Current_Token <> _Until then
    begin
      Statement;
      Match(_separator);
    end;
  until Current_Token = _Until;

  Match(_Until);

  Expression;
  GenCode(_IfNotJumpTo,0,Start);
end;

Procedure Write_Work;
Var
  sx : string;
Begin
  If Current_Token = _Lparen then      { Fix for WriteLn; (No Operands) }
  begin
    Match(_lparen);
    Repeat
      if Current_Token = _String_Constant then
      begin
        sx := DoStringConst(Current_String);
        Match(_String_Constant);
        GenCode(_PutString,0,sx);
      end
      else
      begin
        Expression;
        GenCode(_PutWord,0,'');
      end;
      If Current_Token <> _Rparen then
        Match(_comma);
    Until Current_Token = _Rparen;
    Match(_Rparen);
  end;
End;

Procedure DoProcedure;
Var
  ProcName : NameStr;
Begin
  Match(_Procedure);
  ProcName := GetName;
  Match(_Separator);
  GenCode(_PutLabel,0,ProcName);
  AddSymbol(ProcName,_Void,False);
  BlockStatement;
  GenCode(_Return,0,'');
End;

procedure Statement;
begin
  Case Current_Token of
    _while  : while_Loop;
    _repeat : repeat_loop;
    _for    : for_loop;
    _if     : if_then_else;
    _begin  : BlockStatement;
    _emit   : begin
                Match(_emit);
                Match(_lparen);
                Repeat
                  Expression;
                  GenCode(_PutC,0,'');
                  If Current_Token <> _Rparen then
                    Match(_comma);
                Until Current_Token = _Rparen;
                Match(_Rparen);
              end;
    _Write  : begin
                Match(_Write);
                Write_Work;
              end;
    _WriteLn: begin
                Match(_WriteLn);
                Write_Work;
                GenCode(_PutCrLf,0,'');
              end;
  else
    Assignment;
  end;
end;

(****************************
         Program Parser
 ****************************)
var
  ProgramName : NameStr;

procedure _Program_;
var
  tmp : NameStr;
  lib : text;
  buf : string;
  done : boolean;
begin
  If Current_Token = _Program then
  begin
    Match(_Program);
    ProgramName := GetName;
    Match(_separator);
  end;

  GenCode(_ProgramInit,0,ProgramName);

  Done := False;
  Repeat
    Case Current_Token of
      _Var       : VarBlock;
      _Procedure : DoProcedure;
      _Separator : Match(_Separator);
    else
      Done := True;
    End;
  Until Done;

  GenCode(_PutLabel,0,'MAIN');
  AddSymbol('Main',_Void,False);
  BlockStatement;
  GenCode(_ProgramExit,0,'');

  WriteLn(Dest,'; ***** Library Code ***** ');

  Assign(Lib,'LIB.ASM');
{$I-}  Reset(Lib); {$I+}
  If IOresult = 0 then
  begin
    while not eof(lib) do
    begin
      readln(lib,buf);
      writeln(Dest,buf);
    end;
    close(lib);
  end;

  WriteLn(Dest,'; ***** Library Ends *****');
  DumpSymbols;
  DumpStrings;
  EmitLn('db      100 dup(0)');
  EmitLn('end     main   ');
end;

(**************************
        Main Program
 **************************)

procedure Init;
begin
  LineCount   := 0;
  LabelCount  := 0;
  SymbolCount := 0;
  StringCount := 0;

  TypeTable[0] := TypeInteger;
  TypeTable[1] := TypeByte;
  TypeTable[2] := TypeLong;
  TypeTable[3] := TypeVoid;
  TypeCount    := 4;

  ProgramName := 'NONAME';
  GetChar;
  GetToken;
end;

procedure usage;
begin
  WriteLn('Power Pascal -- Copyright(C) 1993, Blue Star Systems, all rights reserved');
  WriteLn;
  WriteLn('Usage : PP filename  (.PRG assumed) ');
  Halt(0);
end;

Var
  Err : Byte;
  F   : file;
Begin
  If ParamCount = 0 then usage;
  Name := ParamStr(1);
  If Pos('?',name) <> 0 then Usage;

  Assign(Source,Name+'.PRG');
{$I-} Reset(Source); {$I+}
  If IOresult <> 0 then
  begin
    WriteLn('Error opening input file ',Name,'.prg');
    Halt(1);
  end;

  Assign(Dest,Name+'.ASM');
{$I-} ReWrite(Dest); {$I+}
  If IOresult <> 0 then
  begin
    WriteLn('Error opening output file, ',Name,'.asm');
    Halt(2);
  end;

  Init;
  _Program_;

  Close(Source);
  Close(Dest);
  WriteLn('Total of ',LineCount,' Lines processed');

  Swap.SetMemTop(HeapPtr);
                  Err := ExecPrg(MASM+' '+Name+';');
  If Err = 0 then Err := ExecPrg(LINK+' '+Name+','+Name+',NUL,C:\OS2\DOSCALLS,PP');

  Swap.SetMemTop(HeapEnd);

  if err = 0 then
  begin
    assign(f,Name+'.OBJ');
    {$I-} reset(f,1); {$I+}
    if ioresult = 0 then
    begin
      close(f);
      erase(f);
    end;
  end;
End.