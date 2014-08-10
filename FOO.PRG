Program EX4;
{
  Same as EX3, but re-written to use a for loop
}
var
  a,b : integer;
begin
  for a := 65 to 90 do
  begin
    b := a / 3;
    Write(A,' ',B);                { Write the value }
    Emit(32,32,32,32,A,13,10);     { Write "   ", the character, then CR/LF }
  end;
  emit(13,10);
end.

.
