module TridiagonalMod

!-----------------------------------------------------------------------
!BOP
!
! !MODULE: TridiagonalMod
!
! !DESCRIPTION:
! Tridiagonal matrix solution
!
! !PUBLIC TYPES:
  implicit none
  save
!
! !PUBLIC MEMBER FUNCTIONS:
  public :: Tridiagonal
!
! !REVISION HISTORY:
! Created by Mariana Vertenstein
!
!EOP
!-----------------------------------------------------------------------

contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: Tridiagonal
!
! !INTERFACE:
  subroutine Tridiagonal (lbc, ubc, lbj, ubj, jtop, numf, filter, &
                          a, b, c, r, u)
!
! !DESCRIPTION:
! Tridiagonal matrix solution
!
! !USES:
    use shr_kind_mod, only: r8 => shr_kind_r8
!
! !ARGUMENTS:
    implicit none
    integer , intent(in)    :: lbc, ubc               ! lbinning and ubing column indices
    integer , intent(in)    :: lbj, ubj               ! lbinning and ubing level indices
    integer , intent(in)    :: jtop(lbc:ubc)          ! top level for each column
    integer , intent(in)    :: numf                   ! filter dimension
    integer , intent(in)    :: filter(1:numf)         ! filter
    real(r8), intent(in)    :: a(lbc:ubc, lbj:ubj)    ! "a" left off diagonal of tridiagonal matrix
    real(r8), intent(in)    :: b(lbc:ubc, lbj:ubj)    ! "b" diagonal column for tridiagonal matrix
    real(r8), intent(in)    :: c(lbc:ubc, lbj:ubj)    ! "c" right off diagonal tridiagonal matrix
    real(r8), intent(in)    :: r(lbc:ubc, lbj:ubj)    ! "r" forcing term of tridiagonal matrix
    real(r8), intent(inout) :: u(lbc:ubc, lbj:ubj)    ! solution
!
! !CALLED FROM:
! subroutine BiogeophysicsLake in module BiogeophysicsLakeMod
! subroutine SoilTemperature in module SoilTemperatureMod
! subroutine SoilWater in module HydrologyMod
!
! !REVISION HISTORY:
! 15 September 1999: Yongjiu Dai; Initial code
! 15 December 1999:  Paul Houser and Jon Radakovich; F90 Revision
!  1 July 2003: Mariana Vertenstein; modified for vectorization
!
!
! !OTHER LOCAL VARIABLES:
!EOP
!
    integer  :: j,ci,fc                   !indices
    real(r8) :: gam(lbc:ubc,lbj:ubj)      !temporary
    real(r8) :: bet(lbc:ubc)              !temporary
!-----------------------------------------------------------------------

    ! Solve the matrix

!dir$ concurrent
!cdir nodep
    do fc = 1,numf
       ci = filter(fc)
       bet(ci) = b(ci,jtop(ci))
    end do

    do j = lbj, ubj
!dir$ concurrent
!cdir nodep
       do fc = 1,numf
          ci = filter(fc)
          if (j >= jtop(ci)) then
             if (j == jtop(ci)) then
                u(ci,j) = r(ci,j) / bet(ci)
             else
                gam(ci,j) = c(ci,j-1) / bet(ci)
                bet(ci) = b(ci,j) - a(ci,j) * gam(ci,j)
                u(ci,j) = (r(ci,j) - a(ci,j)*u(ci,j-1)) / bet(ci)
             end if
          end if
       end do
    end do

    do j = ubj-1,lbj,-1
!dir$ concurrent
!cdir nodep
       do fc = 1,numf
          ci = filter(fc)
          if (j >= jtop(ci)) then
             u(ci,j) = u(ci,j) - gam(ci,j+1) * u(ci,j+1)
          end if
       end do
    end do

  end subroutine Tridiagonal

end module TridiagonalMod
