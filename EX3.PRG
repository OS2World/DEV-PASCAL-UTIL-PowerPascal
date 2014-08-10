Program EX3;
var
  a : byte;
begin
  A := 65;
  While (A <= 90) do
  begin
    Write(A);
    Emit(32,32,32,32,A,13,10);
    A := A + 1;
  end;
  emit(13,10);
end.

.
