--  Tasking out of static musl: task creation, rendezvous-free contention on
--  a protected object (libgnarl locks — the pthread weak-ref territory where
--  glibc-only symbols like pthread_mutexattr_setprioceiling used to break
--  static links; see patches/gcc-16.2.0/0017 + 0019).
with Ada.Text_IO; use Ada.Text_IO;
procedure Tasks_RW is
   protected Counter is
      procedure Bump;
      function Value return Natural;
   private
      N : Natural := 0;
   end Counter;
   protected body Counter is
      procedure Bump is begin N := N + 1; end Bump;
      function Value return Natural is (N);
   end Counter;

   task type Worker;
   task body Worker is
   begin
      for I in 1 .. 1000 loop
         Counter.Bump;
      end loop;
   end Worker;
begin
   declare
      Pool : array (1 .. 8) of Worker;
      pragma Unreferenced (Pool);
   begin
      null;
   end;
   if Counter.Value = 8000 then
      Put_Line ("ada tasking: ok");
   else
      Put_Line ("ada tasking: FAIL" & Natural'Image (Counter.Value));
   end if;
end Tasks_RW;
