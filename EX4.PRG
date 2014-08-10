Program EX4;
{
  Same as EX3, but re-written to use a for loop
}
var
  a : byte;
begin
  for a := 65 to 90 do
  begin
    Write(A);                      { Write the value }
    Emit(32,32,32,32,A,13,10);     { Write "   ", the character, then CR/LF }
  end;
  emit(13,10);
end.

.
