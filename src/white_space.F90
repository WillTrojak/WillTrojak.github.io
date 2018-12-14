!**************************************************************************
module precision
   use, intrinsic :: iso_fortran_env
   implicit none

   private

   integer, parameter :: int1  = int32
   integer, parameter :: int2  = int64
   integer, parameter :: real1 = real32 
   integer, parameter :: real2 = real64
   integer, parameter :: comp1 = 2*real1 
   integer, parameter :: comp2 = 2*real2

   public :: int1,int2,real1,real2,comp1,comp2

!contains
   !**********************************************************************

   !**********************************************************************
end module precision
!*************************************************************************
program whitespace
   use precision
   implicit none

   character(len=64) :: filename

   call getarg(1,filename)

   call trailing_ws(trim(adjustl(filename)))

   return
!*************************************************************************
contains
   !**********************************************************************
   subroutine trailing_ws(filename)
      use precision
      implicit none

      character(*), intent(in) :: filename

      integer(kind=int1) :: nl
      
      character(len=128), allocatable :: lines(:)
      
      nl = line_number(filename)
      allocate(lines(nl))

      call read_lines(filename,nl,lines)
      call remove_trailing(filename,nl,lines)
      
      return
   end subroutine trailing_ws
   !**********************************************************************
   function line_number(filename) result(nl)
      use precision
      implicit none
      
      character(*), intent(in) :: filename

      integer(kind=int1) :: nl

      integer(kind=int1) :: srcfile,il,ierr
      character(len=128) :: line

      open(newunit=srcfile,file=filename,recl=128)
      
      il = 0
      do while(.true.)
         read(srcfile,"(A128)",iostat=ierr) line
         if(ierr .ne. 0) exit
         il = il + 1
      enddo
      nl = il

      close(srcfile)

      return
   end function line_number
   !**********************************************************************
   subroutine read_lines(filename,nl,lines)
      use precision
      implicit none

      character(*), intent(in) :: filename

      integer(kind=int1), intent(in) :: nl
      
      character(len=128), intent(out) :: lines(nl)

      integer(kind=int1) :: srcfile,il,ierr

      open(newunit=srcfile,file=filename,recl=128)

      do il=1,nl
         read(srcfile,"(A128)",iostat=ierr) lines(il)
      enddo

      close(srcfile)

      return
   end subroutine read_lines
   !**********************************************************************
   subroutine remove_trailing(filename,nl,lines)
      use precision
      implicit none

      character(*), intent(in) :: filename

      integer(kind=int1), intent(in) :: nl
      
      character(len=128), intent(out) :: lines(nl)

      integer(kind=int1) :: srcfile,il,ierr,l

      character(len=128) :: line
      character(len=3) :: lstr

      open(newunit=srcfile,file=filename,recl=128)
      do il=1,nl
         line = lines(il)
         l = len(trim(line))
         write(lstr,"(I3)") l
         write(srcfile,"(A"//trim(adjustl(lstr))//")") trim(line)
      enddo

      close(srcfile)

      return
   end subroutine remove_trailing
   !**********************************************************************
end program whitespace
