Program Test;
{ This is a sample program for the SIMPLE+ compiler
  Requires version 0.12 or later

  Comments go inside braces...
}
VAR                   { variable definitions                          }
  a : integer;        { all variables are assumed integer (for now)   }
begin                 { begin..end  - block statement                 }
  a := 1;             { assignment                                    }
  WriteLn(A);         { write value of a, followed by CR/LF           }
end.                  { period ends program                           }
