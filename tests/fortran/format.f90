program fmt
  ! libgfortran beyond a bare print: formatted numeric edit descriptors,
  ! internal-unit write, array intrinsics and an implied-do.
  implicit none
  integer :: i
  real(8) :: a(3) = [1.5d0, 2.25d0, 3.75d0]
  character(len=16) :: buf

  write (buf, '(f8.3)') sum(a)
  print '(a)', 'sum=' // trim(adjustl(buf))
  print '(a,i0)', 'fact=', product([(i, i = 1, 5)])
  print '(a,es10.3)', 'exp=', exp(1.0d0)
end program fmt
