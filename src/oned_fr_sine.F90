!********************************************************************************
! Authors: Rob Watson andd Will Trojak
!********************************************************************************
module points

   implicit none
 
   integer*4, parameter :: ncell = 40
   integer*4, parameter :: nstep = 4

   integer*4, parameter :: order = 3
   integer*4, parameter :: ndim  = 1
   integer*4, parameter :: nsoln = order**ndim
   integer*4, parameter :: nface = order**(ndim-1)
   integer*4, parameter :: nflux = 2*ndim*nface
   integer*4, parameter :: npdes = 1

   real*8, parameter :: wave = 10d0

   real*8, parameter :: gamma = 1.1d0
   real*8, parameter :: pi = 4d0*atan(1d0)
   real*8, parameter :: L = 2d0*pi 
   real*8, parameter :: a = 1d0

   real*8 :: m1(nsoln,nflux)
   real*8 :: m2(nsoln,nsoln)
   real*8 :: m3(nsoln,nflux)
   real*8 :: m4(nflux,nsoln)

   !real*8, parameter, dimension(nsoln) :: xse = (/ -0.9062d0, -0.5385d0, 0d0, 0.5385d0, 0.9062d0/)
   real*8, parameter, dimension(nsoln) :: xse = (/-0.7745966692414834d0, 0d0, 0.7745966692414834d0 /) 
   real*8, parameter, dimension(nflux) :: xfe = (/-1.0d0, 1.0d0/)

   type :: element
     real*8 :: x(1,2)

     real*8 :: xts(ndim,nsoln)
     real*8 :: xtf(ndim,nflux)

     real*8 :: qts(npdes,nsoln)
     real*8 :: qtf(npdes,nflux)
     real*8 :: qos(npdes,nsoln)

     real*8 :: fhf(npdes,nflux)
     real*8 :: fhs(npdes,nsoln)

     real*8 :: dfhs(npdes,nsoln)
     real*8 :: dfhf(npdes,nflux)
     real*8 :: cfhs(npdes,nsoln)
     real*8 :: cfhf(npdes,nflux)

     real*8 :: det(1,nsoln)

     real*8 :: cfl,khat

     integer*4 :: left, rite
   end type element

end module points
!********************************************************************************
!********************************************************************************
program main
   use points
   implicit none

   type(element), allocatable :: cells(:)
   integer*4 :: in,jn,ir,it
   real*8, parameter :: dt = 1d-2!4d-3
   real*8 :: ox,dx,dq,t,end_time,data_start,rk,ntime = 0d0,dtime = 0d0,dxmin
   
   !Allocate some memory
   allocate(cells(ncell)) 

   ! Step Up a Geometrically Stretched Mesh
   cells(1)%x(1,1) = 0d0
   cells(1)%x(1,2) = 1d0
   do in=2,ncell
      cells(in)%x(1,1) = cells(in-1)%x(1,2)
      cells(in)%x(1,2) = cells(in)%x(1,1) + gamma*(cells(in-1)%x(1,2)-cells(in-1)%x(1,1))
   enddo

   do in=1,ncell
      cells(in)%x(1,1) = L * cells(in)%x(1,1) / cells(ncell)%x(1,2)
      cells(in)%x(1,2) = L * cells(in)%x(1,2) / cells(ncell)%x(1,2)
   end do
   dxmin = min((cells(1)%x(1,2)-cells(1)%x(1,1)),(cells(ncell)%x(1,2)-cells(ncell)%x(1,1)))
   write(6,*) "dx",dxmin

   !Set points
   do in=1,ncell
      do jn=1,nsoln
         dx = 0.5d0*(cells(in)%x(1,2) - cells(in)%x(1,1))
         ox = 0.5d0*(cells(in)%x(1,1) + cells(in)%x(1,2))
         cells(in)%xts(1,jn) = ox + dx*xse(jn)
      end do
      do jn=1,nflux
         dx = 0.5d0*(cells(in)%x(1,2) - cells(in)%x(1,1))
         ox = 0.5d0*(cells(in)%x(1,1) + cells(in)%x(1,2))
         cells(in)%xtf(1,jn) = ox + dx*xfe(jn)
      end do     
   end do

   !Initialise flow
   do in=1,ncell
      cells(in)%qts = 0d0
   end do

   !Set up connectivity
   do in=1,ncell
      cells(in)%left = modulo(in-2,ncell)+1
      cells(in)%rite = modulo(in  ,ncell)+1
   end do

   !Set up the flow determinants
   do in=1,ncell
      do jn=1,nsoln
         cells(in)%det(1,jn) = (xse(nsoln) - xse(1))/(cells(in)%xts(1,nsoln) - cells(in)%xts(1,1))
      end do
   end do

   !Set up the matrices
   call get_m1()
   call get_m2()
   call get_m3()
   call get_m4()
 
   
   do in=1,ncell
      cells(in)%cfl = a*dt/(cells(in)%x(1,2)-cells(in)%x(1,1))
      cells(in)%khat = wave*(cells(in)%x(1,2)-cells(in)%x(1,1))/(2d0*pi*order)
   enddo
   write(6,*) "dt",dt
   write(6,*) "CFL",a*dt/dxmin
   t = 0d0
   end_time = L/a + 10d0*pi
   data_start = L/a + 0d0

   open(unit=12,file="qt.dat",action="write")
  
   do while(t .le. end_time)
 
      t = t + dt
 
      !Store original for RK
      do in=1,ncell
         cells(in)%qos = cells(in)%qts
      enddo
      
      do ir=1,nstep
 
         rk = 1d0 / float(nstep + 1 - ir)
 
         !Compute fluxes at solution points
         do in=1,ncell
            do jn=1,nsoln
               cells(in)%fhs(1,jn) = cells(in)%qts(1,jn)*a
            end do
         enddo
         
         !Find primitives at flux points
         do in=1,ncell
            cells(in)%qtf = matmul(cells(in)%qts,m1)
         enddo
         
         !Compute common interface fluxes at flux points
         do in=1,ncell
            cells(in)%cfhf(1,1) = cells(cells(in)%left)%qtf(1,2)*1d0 
            cells(in)%cfhf(1,2) = cells(in)%qtf(1,2)*a
         end do
         
         !Apply the boundary conditions
         cells(1)%cfhf(1,1) = sin(wave*(cells(1)%xtf(1,1) - t))
         
         !Project fluxes to flux points
         do in=1,ncell
            cells(in)%fhf = matmul(cells(in)%fhs,m3)
         enddo
         
         !Find difference between fluxes
         do in=1,ncell
            cells(in)%dfhf = cells(in)%cfhf - cells(in)%fhf
         end do
         
         !Find derivatives of fluxes at solution points
         do in=1,ncell
            cells(in)%dfhs = matmul(cells(in)%fhs,m2)
         enddo
         
         !Find the correction to the derivatives of the fluxes at the solution points
         do in=1,ncell
            cells(in)%cfhs = matmul(cells(in)%dfhf,m4)
         enddo
         
         !Update the solution
         do in=1,ncell
            do jn=1,nsoln
               dq = (cells(in)%dfhs(1,jn) + cells(in)%cfhs(1,jn))*cells(in)%det(1,jn)
               cells(in)%qts(1,jn) = cells(in)%qos(1,jn) - dq*dt*rk
            end do
         end do
         
      enddo
      
      !Write out at end point
      if(t - data_start .gt. 0d0)then
         cells(ncell)%qtf = matmul(cells(ncell)%qts,m1)
         write(12,*) (t-data_start), cells(ncell)%qtf(1,nflux)
      end if
      
      ! Give User Some Progress Information
      if(t - ntime .gt. 0.1d0)then
         if(isnan(cells(ncell)%qts(1,nsoln)))then
            write(6,*) "NaN Fail"
            stop
         endif
         ntime = t
      endif

      if(t - dtime .gt. 1d0)then
         dtime = t
         write(6,*) t,end_time
      endif

   enddo

   close(12)

   open(unit=13,file="qx.dat",action="write")
   do in=1,ncell
      do jn=1,nsoln
         write(13,*) cells(in)%xts(1,jn),cells(in)%qts(1,jn),cells(in)%cfl,cells(in)%khat
      enddo
   enddo
   close(13)
   write(6,*) "CFL",a*dt/dxmin

   stop   
end program main
!************************************************************************
subroutine invert(n,a,b)

   implicit none
 
   integer*4 :: n,ipiv(n),info,in,jn
   real*8    :: a(n,n),b(n,n),c(n,n),work(n) 
 
   do in=1,n
      do jn=1,n
         b(in,jn) = a(in,jn)
      enddo
    enddo
   
   call dgetrf(n,n,a,n,ipiv,info)
   call dgetri(n,a,n,ipiv,work,n,info)
 
   do in=1,n
      do jn=1,n
         c(in,jn) = b(in,jn)
      enddo
   enddo
   do in=1,n
      do jn=1,n
         b(in,jn) = a(in,jn)
      enddo
   enddo
   do in=1,n
      do jn=1,n
         a(in,jn) = c(in,jn)
      enddo
   enddo
   
   return
end subroutine invert
!************************************************************************
double precision function otrgs(in,x)
  
  implicit none
  
  integer*4, intent(in) :: in
  real*8, intent(in) :: x

  real*8 :: fac
  
  fac = float(in-1)
  
  otrgs = x**fac
  
end function otrgs
!************************************************************************
double precision function dtrgs(in,x)

   implicit none   
 
   integer*4, intent(in) :: in
   real*8, intent(in) :: x 
   
   real*8 :: fac,fc1
  
   fac = float(in-1)
   fc1 = max(in-2,0)
   
   dtrgs = fac*x**fc1
   
end function dtrgs
!************************************************************************
subroutine get_m1()
  
   use points
   implicit none
   
   integer*4 :: count,in,jn,kn,pp,py,px
   
   real*8 :: xsm(nsoln,nsoln),xfm(nsoln,nflux),xsi(nsoln,nsoln),otrgs
   
   do kn=1,nsoln
      count = 0
      do jn=1,nsoln
         count = count + 1
         xsm(count,kn) = otrgs(jn,xse(kn))
      enddo
   enddo
   
   do kn=1,nflux
      count = 0
      do jn=1,nsoln
         count = count + 1
         
         xfm(count,kn) = otrgs(jn,xfe(kn))
      enddo
   enddo
   
   call invert(nsoln,xsm,xsi)
   
   m1 = matmul(xsi,xfm)
   
   return
end subroutine get_m1
!*********************************************************************
subroutine get_m2()
   use points
   implicit none
   
   integer*4 :: count,in,jn,kn
   
   real*8 :: xsm(nsoln,nsoln),xsi(nsoln,nsoln),xdm(nsoln,nsoln),mx(nsoln,nsoln), &
             otrgs,dtrgs
   
   do kn=1,nsoln
      count = 0
      do jn=1,nsoln
         count = count + 1
         xsm(count,kn) = otrgs(jn,xse(kn))
      enddo
   enddo
   
   call invert(nsoln,xsm,xsi)
   
   do kn=1,nsoln
      count = 0
      do jn=1,nsoln
         count = count + 1
         xdm(count,kn) = dtrgs(jn,xse(kn))
      enddo
   enddo
   m2 = matmul(xsi,xdm)
   
   return
end subroutine get_m2
!**********************************************************************
subroutine get_m3()
   use points
   implicit none 
   
   integer*4 :: count,in,jn,kn 
   
   real*8 :: xsm(nsoln,nsoln),xfm(nsoln,nflux),xsi(nsoln,nsoln),otrgs
   
   do kn=1,nsoln
      count = 0
      do jn=1,nsoln
         count = count + 1
         xsm(count,kn) = otrgs(jn,xse(kn))
      enddo
   enddo
   
   do kn=1,nflux
      count = 0
      do jn=1,nsoln
         count = count + 1
         xfm(count,kn) = otrgs(jn,xfe(kn))
      enddo
   enddo
   
   call invert(nsoln,xsm,xsi)
   
   m3 = matmul(xsi,xfm)
   
   return
 end subroutine get_m3
 !**********************************************************************
 subroutine get_m4()
   use points
   implicit none
   
   integer*4 :: in,jn,kn,ncorr
   real*8 :: dtrgs
   real*8, allocatable :: lc(:,:)
   
   if(order .eq. 3)then
      allocate(lc(2,order+1))
      lc(1,1) = -0.250d0
      lc(1,2) =  0d0
      lc(1,3) =  0.750d0
      lc(1,4) = -0.500d0  
   elseif(order .eq. 4)then
      allocate(lc(2,order+1))
      lc(1,1) = -6.250d-2
      lc(1,2) =  0.750d0
      lc(1,3) = -0.375d0
      lc(1,4) = -1.250d0
      lc(1,5) =  0.93750d0
   elseif(order .eq. 5)then
      allocate(lc(2,order+1))
      lc(1,1) =  0.18750d0
      lc(1,2) =  0d0
      lc(1,3) = -1.875d0
      lc(1,4) =  1.250d0
      lc(1,5) =  2.1875d0
      lc(1,6) = -1.750d0
   endif
   
   ncorr = nsoln + 1
   
   do in=1,nsoln
      do jn=1,nflux
         m4(jn,in) = 0d0
      enddo
   enddo
   
   do in=1,ncorr
      do jn=1,nsoln
         do kn=1,nflux
            m4(kn,jn) = m4(kn,jn) + lc(kn,in)*dtrgs(in,xse(jn))
         enddo
      enddo
   enddo
   
   return
end subroutine get_m4
!**********************************************************************
