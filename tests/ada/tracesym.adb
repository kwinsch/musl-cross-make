--  Exception propagation + GNAT.Traceback.Symbolic: must LINK without the
--  glibc-internal _r_debug (the s-tsmona stub, patches/gcc-16.2.0/0018),
--  survive a raise/handle round-trip, and actually SYMBOLIZE: the traceback
--  must resolve to this file (needs the executable load address — static-PIE
--  printed "??? at ???" before patches/gcc-16.2.0/0020). Built with -g
--  (tracesym.flags). Call_Chain avoids needing the binder's -E switch.
--  Output is kept length-free: traceback depth varies by arch/optimization.
with Ada.Text_IO;            use Ada.Text_IO;
with Ada.Strings.Fixed;
with GNAT.Traceback;
with GNAT.Traceback.Symbolic;
procedure Tracesym is
   function Symbolized return String is
      TB  : GNAT.Traceback.Tracebacks_Array (1 .. 32);
      Len : Natural;
   begin
      GNAT.Traceback.Call_Chain (TB, Len);
      return GNAT.Traceback.Symbolic.Symbolic_Traceback (TB (1 .. Len));
   end Symbolized;

   procedure Boom is
   begin
      raise Constraint_Error with "intentional";
   end Boom;
begin
   Boom;
   Put_Line ("ada traceback: FAIL (no exception)");
exception
   when Constraint_Error =>
      declare
         S : constant String := Symbolized;
      begin
         if Ada.Strings.Fixed.Index (S, "tracesym.adb:") > 0 then
            Put_Line ("ada traceback: ok");
         else
            Put_Line ("ada traceback: FAIL (unsymbolized)");
            Put_Line (S);
         end if;
      end;
end Tracesym;
