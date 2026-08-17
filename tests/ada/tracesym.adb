--  Exception propagation + System.Traceback.Symbolic: must LINK without the
--  glibc-internal _r_debug (the s-tsmona stub, patches/gcc-16.2.0/0018) and
--  survive a raise/handle/symbolize round-trip. Output is kept length-free:
--  traceback depth varies by arch/optimization.
with Ada.Text_IO;            use Ada.Text_IO;
with Ada.Exceptions;         use Ada.Exceptions;
with GNAT.Traceback.Symbolic;
procedure Tracesym is
   procedure Boom is
   begin
      raise Constraint_Error with "intentional";
   end Boom;
begin
   Boom;
   Put_Line ("ada traceback: FAIL (no exception)");
exception
   when E : others =>
      declare
         S : constant String :=
           GNAT.Traceback.Symbolic.Symbolic_Traceback (E);
         pragma Unreferenced (S);
      begin
         Put_Line ("ada traceback: ok");
      end;
end Tracesym;
