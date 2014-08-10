Program Example2;
{ This is a sample program for the SIMPLE+ compiler
  Requires version 0.12 or later

  Comments go inside braces...
}
VAR                   { variable definitions                          }
  a,b,c : integer;    { all variables are assumed integer (for now)   }
Begin                 { begin..end  - block statement                 }
  a := 1;
  b := 99;
  for c := a to b do
    WriteLn(c);       { write value of a, followed by CR/LF           }
end.                  { period ends program                           }
