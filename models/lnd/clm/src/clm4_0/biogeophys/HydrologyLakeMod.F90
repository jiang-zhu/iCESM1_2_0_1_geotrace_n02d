module HydrologyLakeMod

!-----------------------------------------------------------------------
!BOP
!
! !MODULE: HydrologyLakeMod
!
! !DESCRIPTION:
! Calculate lake hydrology
!
! !PUBLIC TYPES:
  implicit none
  save
!
! !PUBLIC MEMBER FUNCTIONS:
  public :: HydrologyLake
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
! !IROUTINE: HydrologyLake
!
! !INTERFACE:
  subroutine HydrologyLake(lbp, ubp, num_lakep, filter_lakep)
!
! !DESCRIPTION:
! Calculate lake hydrology
!
! WARNING: This subroutine assumes lake columns have one and only one pft.
!
! !USES:
    use shr_kind_mod, only: r8 => shr_kind_r8
    use clmtype
    use clm_atmlnd  , only : clm_a2l
    use clm_time_manager, only : get_step_size
    use clm_varcon      , only : hfus, tfrz, spval
    use HydrologyTracer , only : pwtrc, get_wratio, ixbase, h2otiny, qflxtiny, &
                                 cdbg, pdbg, mdbg
!
! !ARGUMENTS:
    implicit none
    integer, intent(in) :: lbp, ubp                ! pft-index bounds
    integer, intent(in) :: num_lakep               ! number of pft non-lake points in pft filter
    integer, intent(in) :: filter_lakep(ubp-lbp+1) ! pft filter for non-lake points
!
! !CALLED FROM:
! subroutine clm_driver1
!
! !REVISION HISTORY:
! Author: Gordon Bonan
! 15 September 1999: Yongjiu Dai; Initial code
! 15 December 1999:  Paul Houser and Jon Radakovich; F90 Revision
! 3/4/02: Peter Thornton; Migrated to new data structures.
!
! !LOCAL VARIABLES:
!
! local pointers to implicit in arrays
!
    integer , pointer :: pcolumn(:)         !pft's column index
    integer , pointer :: pgridcell(:)       !pft's gridcell index
    real(r8), pointer :: begwb(:)         !water mass begining of the time step
    real(r8), pointer :: wtr_begwb(:,:)   !water mass begining of the time step
    real(r8), pointer :: forc_snow(:)     !snow rate [mm/s]
    real(r8), pointer :: forc_rain(:)     !rain rate [mm/s]
    real(r8), pointer :: forc_wtr_snow(:,:)!tracer snow rate [mm/s]
    real(r8), pointer :: forc_wtr_rain(:,:)!tracer rain rate [mm/s]
    logical , pointer :: do_capsnow(:)    !true => do snow capping
    real(r8), pointer :: t_grnd(:)        !ground temperature (Kelvin)
    real(r8), pointer :: qmelt(:)         !snow melt [mm/s]
    real(r8), pointer :: qflx_evap_soi(:) !soil evaporation (mm H2O/s) (+ = to atm)
    real(r8), pointer :: qflx_evap_tot(:) !qflx_evap_soi + qflx_evap_can + qflx_tran_veg
    real(r8), pointer :: wtr_qmelt(:,:)         !tracer snow melt [mm/s]
    real(r8), pointer :: wtr_qflx_evap_soi(:,:) !tracer soil evaporation (mm H2O/s) (+ = to atm)
    real(r8), pointer :: wtr_qflx_evap_tot(:,:) !tracer qflx_evap_soi + qflx_evap_veg + qflx_tran_veg
!
! local pointers to implicit inout arrays
!
    real(r8), pointer :: h2osno(:)        !snow water (mm H2O)
    real(r8), pointer :: wtr_h2osno(:,:)  !tracer snow water (mm H2O)
!
! local pointers to implicit out arrays
!
!rtm_flood
    real(r8), pointer :: qflx_floodg(:)   ! gridcell flux of flood water from RTM
    real(r8), pointer :: qflx_floodc(:)   ! column flux of flood water from RTM

    real(r8), pointer :: wtr_qflx_floodg(:,:)! tracer gridcell flux of flood water from RTM
    real(r8), pointer :: wtr_qflx_floodc(:,:)! tracer column flux of flood water from RTM
!rtm_flood
    real(r8), pointer :: endwb(:)         !water mass end of the time step
    real(r8), pointer :: wtr_endwb(:,:)   !water mass end of the time step
    real(r8), pointer :: snowdp(:)        !snow height (m)
    real(r8), pointer :: snowice(:)       !average snow ice lens
    real(r8), pointer :: snowliq(:)       !average snow liquid water
    real(r8), pointer :: qflx_rain_grnd(:)!rain on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: qflx_rain_grnd_col(:)!rain on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: qflx_snow_grnd(:)!snow on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: qflx_snow_grnd_col(:)!snow on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: eflx_snomelt(:)  !snow melt heat flux (W/m**2)
    real(r8), pointer :: qflx_infl(:)     !infiltration (mm H2O /s)
    real(r8), pointer :: qflx_snomelt(:)  !snow melt (mm H2O /s)
    real(r8), pointer :: qflx_surf(:)     !surface runoff (mm H2O /s)
    real(r8), pointer :: qflx_drain(:)    !sub-surface runoff (mm H2O /s)
    real(r8), pointer :: qflx_irrig(:)    !irrigation flux (mm H2O /s)
    real(r8), pointer :: qflx_qrgwl(:)    !qflx_surf at glaciers, wetlands, lakes
    real(r8), pointer :: qflx_runoff(:)   !total runoff (qflx_drain+qflx_surf+qflx_qrgwl) (mm H2O /s)
    real(r8), pointer :: qflx_snwcp_ice(:)!excess snowfall due to snow capping (mm H2O /s) [+]`
    real(r8), pointer :: qflx_snwcp_ice_col(:)!excess snowfall due to snow capping (mm H2O /s) [+]`
    real(r8), pointer :: qflx_evap_tot_col(:) !pft quantity averaged to the column (assuming one pft)
    real(r8), pointer :: qflx_evap_grnd(:)! ground surface evaporation rate (mm H2O/s) [+]
    real(r8), pointer :: qflx_evap_grnd_col(:)! ground surface evaporation rate (mm H2O/s) [+]
    real(r8), pointer :: qflx_sub_snow(:) ! sublimation rate from snow pack (mm H2O /s) [+]
    real(r8), pointer :: qflx_sub_snow_col(:) ! sublimation rate from snow pack (mm H2O /s) [+]
    real(r8), pointer :: qflx_dew_snow(:) ! surface dew added to snow pack (mm H2O /s) [+]
    real(r8), pointer :: qflx_dew_snow_col(:) ! surface dew added to snow pack (mm H2O /s) [+]
    real(r8), pointer :: qflx_dew_grnd(:) ! ground surface dew formation (mm H2O /s) [+]
    real(r8), pointer :: qflx_dew_grnd_col(:) ! ground surface dew formation (mm H2O /s) [+]
    real(r8) ,pointer :: soilalpha(:)     !factor that reduces ground saturated specific humidity (-)
    real(r8), pointer :: zwt(:)           !water table depth
    real(r8), pointer :: fcov(:)          !fractional impermeable area
    real(r8), pointer :: fsat(:)          !fractional area with water table at surface
    real(r8), pointer :: qcharge(:)       !aquifer recharge rate (mm/s)
    real(r8), pointer :: qflx_top_soil(:)      ! net water input into soil from top (mm/s)
    real(r8), pointer :: qflx_prec_grnd(:)     ! water onto ground including canopy runoff [kg/(m2 s)]
    real(r8), pointer :: qflx_prec_grnd_col(:) ! water onto ground including canopy runoff [kg/(m2 s)]

    real(r8), pointer :: wtr_qflx_rain_grnd(:,:)!tracer rain on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: wtr_qflx_rain_grnd_col(:,:)!tracer rain on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: wtr_qflx_snow_grnd(:,:)!tracer snow on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: wtr_qflx_snow_grnd_col(:,:)!tracer snow on ground after interception (mm H2O/s) [+]
    real(r8), pointer :: wtr_snowice(:,:) !tracer average snow ice lens
    real(r8), pointer :: wtr_snowliq(:,:) !tracer average snow liquid water
    real(r8), pointer :: wtr_qflx_infl(:,:)     !tracer infiltration (mm H2O /s)
    real(r8), pointer :: wtr_qflx_snomelt(:,:)  !tracer snow melt (mm H2O /s)
    real(r8), pointer :: wtr_qflx_surf(:,:)     !tracer surface runoff (mm H2O /s)
    real(r8), pointer :: wtr_qflx_drain(:,:)    !tracer sub-surface runoff (mm H2O /s)
    real(r8), pointer :: wtr_qflx_irrig(:,:)    !tracer irrigation flux (mm H2O /s)
    real(r8), pointer :: wtr_qflx_qrgwl(:,:)    !tracer qflx_surf at glaciers, wetlands, lakes
    real(r8), pointer :: wtr_qflx_runoff(:,:)   !tracer total runoff (qflx_drain+qflx_surf+qflx_qrgwl) (mm H2O /s)
    real(r8), pointer :: wtr_qflx_evap_tot_col(:,:) !tracer pft quantity averaged to the column (assuming one pft)
    real(r8), pointer :: wtr_qflx_snwcp_ice(:,:)!excess snowfall due to snow capping (mm H2O /s) [+]`
    real(r8), pointer :: wtr_qflx_snwcp_ice_col(:,:)!excess snowfall due to snow capping (mm H2O /s) [+]`
    real(r8), pointer :: wtr_qflx_evap_grnd(:,:)!tracer ground surface evaporation rate (mm H2O/s) [+]
    real(r8), pointer :: wtr_qflx_evap_grnd_col(:,:)!tracer ground surface evaporation rate (mm H2O/s) [+]
    real(r8), pointer :: wtr_qflx_sub_snow(:,:) !tracer sublimation rate from snow pack (mm H2O /s) [+]
    real(r8), pointer :: wtr_qflx_sub_snow_col(:,:) !tracer sublimation rate from snow pack (mm H2O /s) [+]
    real(r8), pointer :: wtr_qflx_dew_snow(:,:) !tracer surface dew added to snow pack (mm H2O /s) [+]
    real(r8), pointer :: wtr_qflx_dew_snow_col(:,:) !tracer surface dew added to snow pack (mm H2O /s) [+]
    real(r8), pointer :: wtr_qflx_dew_grnd(:,:) !tracer ground surface dew formation (mm H2O /s) [+]
    real(r8), pointer :: wtr_qflx_dew_grnd_col(:,:) !tracer ground surface dew formation (mm H2O /s) [+]
    real(r8), pointer :: wtr_qflx_top_soil(:,:)      !tracer net water input into soil from top (mm/s)
    real(r8), pointer :: wtr_qflx_prec_grnd(:,:)!tracer water onto ground including canopy runoff [kg/(m2 s)]
    real(r8), pointer :: wtr_qflx_prec_grnd_col(:,:)!tracer water onto ground including canopy runoff [kg/(m2 s)]
!
! local pointers to implicit out multi-level arrays
!
    real(r8), pointer :: rootr_column(:,:) !effective fraction of roots in each soil layer
    real(r8), pointer :: h2osoi_vol(:,:)   !volumetric soil water (0<=h2osoi_vol<=watsat) [m3/m3]
    real(r8), pointer :: h2osoi_ice(:,:)   !ice lens (kg/m2)
    real(r8), pointer :: h2osoi_liq(:,:)   !liquid water (kg/m2)
    real(r8), pointer :: qflx_snofrz_col(:)!column-integrated snow freezing rate (kg m-2 s-1) [+]

    real(r8), pointer :: wtr_h2osoi_vol(:,:,:)   !tracer volumetric soil water (0<=h2osoi_vol<=watsat) [m3/m3]
    real(r8), pointer :: wtr_h2osoi_ice(:,:,:)   !tracer ice lens (kg/m2)
    real(r8), pointer :: wtr_h2osoi_liq(:,:,:)   !tracer liquid water (kg/m2)
    real(r8), pointer :: wtr_qflx_snofrz_col(:,:)!tracer column-integrated snow freezing rate (kg m-2 s-1) [+]
!
!
! !OTHER LOCAL VARIABLES:
!EOP
    real(r8), parameter :: snow_bd = 250._r8  !constant snow bulk density
    integer  :: fp,p,c,g       ! indices
    integer  :: m              ! tracer index
    real(r8) :: dtime          ! land model time step (sec)
    real(r8) :: RFlux(pwtrc)              ! isotopic ratio of water flux
    real(r8) :: RSnow(pwtrc)              ! isotopic ratio of snow
    logical :: ldbg=.false.
!    if(lbp<=pdbg .and. pdbg<=ubp) ldbg=.true.
!-----------------------------------------------------------------------

    ! Assign local pointers to derived type gridcell members

    forc_snow    => clm_a2l%forc_snow
    forc_rain    => clm_a2l%forc_rain
    forc_wtr_snow    => clm_a2l%forc_wtr_snow
    forc_wtr_rain    => clm_a2l%forc_wtr_rain

    ! Assign local pointers to derived type column members

!rtm_flood: add flooding terms
    qflx_floodg      => clm_a2l%forc_flood
    qflx_floodc      => cwf%qflx_floodc

    wtr_qflx_floodg  => clm_a2l%forc_wtr_flood
    wtr_qflx_floodc  => cwf%wtr_qflx_floodc
!rtm_flood
    begwb          => cwbal%begwb
    endwb          => cwbal%endwb
    do_capsnow     => cps%do_capsnow
    snowdp         => cps%snowdp
    t_grnd         => ces%t_grnd
    h2osno         => cws%h2osno
    snowice        => cws%snowice
    snowliq        => cws%snowliq
    eflx_snomelt   => cef%eflx_snomelt
    qmelt          => cwf%qmelt
    qflx_snomelt   => cwf%qflx_snomelt
    qflx_surf      => cwf%qflx_surf
    qflx_qrgwl     => cwf%qflx_qrgwl
    qflx_runoff    => cwf%qflx_runoff
    qflx_snwcp_ice_col => pwf_a%qflx_snwcp_ice
    qflx_drain     => cwf%qflx_drain
    qflx_irrig     => cwf%qflx_irrig
    qflx_infl      => cwf%qflx_infl
    rootr_column   => cps%rootr_column
    h2osoi_vol     => cws%h2osoi_vol
    h2osoi_ice     => cws%h2osoi_ice
    h2osoi_liq     => cws%h2osoi_liq
    qflx_evap_tot_col => pwf_a%qflx_evap_tot
    soilalpha      => cws%soilalpha
    zwt            => cws%zwt
    fcov           => cws%fcov
    fsat           => cws%fsat
    qcharge        => cws%qcharge
    qflx_snofrz_col => cwf%qflx_snofrz_col
    qflx_top_soil  => cwf%qflx_top_soil
    qflx_prec_grnd_col => pwf_a%qflx_prec_grnd
    qflx_evap_grnd_col => pwf_a%qflx_evap_grnd
    qflx_dew_grnd_col  => pwf_a%qflx_dew_grnd
    qflx_dew_snow_col  => pwf_a%qflx_dew_snow
    qflx_sub_snow_col  => pwf_a%qflx_sub_snow
    qflx_rain_grnd_col => pwf_a%qflx_rain_grnd
    qflx_snow_grnd_col => pwf_a%qflx_snow_grnd

    wtr_begwb      => cwbal%wtr_begwb
    wtr_endwb      => cwbal%wtr_endwb
    wtr_h2osno     => cws%wtr_h2osno
    wtr_snowice    => cws%wtr_snowice
    wtr_snowliq    => cws%wtr_snowliq
    wtr_qmelt      => cwf%wtr_qmelt
    wtr_qflx_snomelt => cwf%wtr_qflx_snomelt
    wtr_qflx_surf  => cwf%wtr_qflx_surf
    wtr_qflx_qrgwl => cwf%wtr_qflx_qrgwl
    wtr_qflx_runoff=> cwf%wtr_qflx_runoff
    wtr_qflx_drain => cwf%wtr_qflx_drain
    wtr_qflx_irrig     => cwf%wtr_qflx_irrig
    wtr_qflx_infl  => cwf%wtr_qflx_infl
    wtr_qflx_top_soil  => cwf%wtr_qflx_top_soil
    wtr_h2osoi_vol     => cws%wtr_h2osoi_vol
    wtr_h2osoi_ice     => cws%wtr_h2osoi_ice
    wtr_h2osoi_liq     => cws%wtr_h2osoi_liq
    wtr_qflx_evap_tot_col => pwf_a%wtr_qflx_evap_tot
    wtr_qflx_snofrz_col => cwf%wtr_qflx_snofrz_col
    wtr_qflx_rain_grnd_col => pwf_a%wtr_qflx_rain_grnd
    wtr_qflx_snow_grnd_col => pwf_a%wtr_qflx_snow_grnd

    ! Assign local pointers to derived type pft members

    pcolumn       => pft%column
    pgridcell     => pft%gridcell
    qflx_evap_soi => pwf%qflx_evap_soi
    qflx_evap_tot => pwf%qflx_evap_tot
    qflx_evap_grnd => pwf%qflx_evap_grnd
    qflx_sub_snow  => pwf%qflx_sub_snow
    qflx_dew_snow  => pwf%qflx_dew_snow
    qflx_dew_grnd  => pwf%qflx_dew_grnd
    qflx_rain_grnd => pwf%qflx_rain_grnd
    qflx_snow_grnd => pwf%qflx_snow_grnd
    qflx_prec_grnd => pwf%qflx_prec_grnd
    qflx_snwcp_ice => pwf%qflx_snwcp_ice

    wtr_qflx_evap_soi => pwf%wtr_qflx_evap_soi
    wtr_qflx_evap_tot => pwf%wtr_qflx_evap_tot
    wtr_qflx_evap_grnd => pwf%wtr_qflx_evap_grnd
    wtr_qflx_sub_snow  => pwf%wtr_qflx_sub_snow
    wtr_qflx_dew_snow  => pwf%wtr_qflx_dew_snow
    wtr_qflx_dew_grnd  => pwf%wtr_qflx_dew_grnd
    wtr_qflx_rain_grnd => pwf%wtr_qflx_rain_grnd
    wtr_qflx_snow_grnd => pwf%wtr_qflx_snow_grnd
    wtr_qflx_prec_grnd => pwf%wtr_qflx_prec_grnd
    wtr_qflx_snwcp_ice => pwf%wtr_qflx_snwcp_ice
    wtr_qflx_evap_grnd_col => pwf_a%wtr_qflx_evap_grnd
    wtr_qflx_sub_snow_col  => pwf_a%wtr_qflx_sub_snow
    wtr_qflx_dew_snow_col  => pwf_a%wtr_qflx_dew_snow
    wtr_qflx_dew_grnd_col  => pwf_a%wtr_qflx_dew_grnd
    wtr_qflx_prec_grnd_col => pwf_a%wtr_qflx_prec_grnd
    wtr_qflx_snwcp_ice_col => pwf_a%wtr_qflx_snwcp_ice

    ! Determine step size

    dtime = get_step_size()

    do fp = 1, num_lakep
       p = filter_lakep(fp)
       c = pcolumn(p)
       g = pgridcell(p)

       ! Snow on the lake ice
	   !In old version (4_0_14) these were local variables.
	   !Need to make sure they're done consistently in new version
	   !(4_0_71) as pointers.

       qflx_evap_grnd(p) = 0._r8
       qflx_sub_snow(p) = 0._r8
       qflx_dew_snow(p) = 0._r8
       qflx_dew_grnd(p) = 0._r8
       do m = 1, pwtrc
         wtr_qflx_evap_grnd(p,m) = 0._r8
         wtr_qflx_sub_snow(p,m) = 0._r8
         wtr_qflx_dew_snow(p,m) = 0._r8
         wtr_qflx_dew_grnd(p,m) = 0._r8
       end do

       if (qflx_evap_soi(p) >= 0._r8) then

          ! Sublimation: do not allow for more sublimation than there is snow
          ! after melt.  Remaining surface evaporation used for infiltration.

          ! Tracer sublimate with the snow ratio, and we preserve the ratio for bare ground fraction.
          do m = 1, pwtrc
            RSnow(m) = get_wratio(wtr_h2osno(c,m), wtr_h2osno(c,ixbase),h2otiny)
          end do
          qflx_sub_snow(p) = min(qflx_evap_soi(p), h2osno(c)/dtime-qmelt(c))
          ! Liquid water evaporation from snow or "ground" is implicitly treated as a term in qrgwl 
          qflx_evap_grnd(p) = 0._r8
          ! Modify tracer fluxes, and change the qflx_evap_soi for output
          do m = 1, pwtrc
             wtr_qflx_sub_snow(p,m) = min(RSnow(m)*qflx_sub_snow(p),wtr_h2osno(c,m)/dtime-wtr_qmelt(c,m))
             wtr_qflx_evap_grnd(p,m) = 0._r8
          end do

       else

          if (t_grnd(c) < tfrz-0.1_r8) then
             qflx_dew_snow(p) = abs(qflx_evap_soi(p))
             do m = 1, pwtrc
               wtr_qflx_dew_snow(p,m) = abs(wtr_qflx_evap_soi(p,m))
             end do
          else
             ! Liquid dew on snow or "ground" is implicitly treated as a term in qrgwl
             qflx_dew_grnd(p) = 0._r8
             do m = 1, pwtrc
               wtr_qflx_dew_grnd(p,m) = 0._r8
             end do
          end if

       end if

       ! Update snow pack
       
       ! WJS (8-26-11): For consistency with non-lake columns, I am setting the values of
       ! qflx_rain_grnd and qflx_snow_grnd dependent on do_capsnow. For qflx_snow_grnd,
       ! this makes sense: as with non-lake columns, this gives the amount of snowfall
       ! that is added to the snowpack as opposed to running off due to snow capping. For
       ! qflx_rain_grnd, the definition over lakes is less well defined, since (I believe)
       ! all rain runs off over lakes (and qflx_snwcp_liq is always 0 over
       ! lakes). Nevertheless, I am trying to be consistent with the definition of
       ! qflx_rain_grnd elsewhere, which is: the amount of rainfall reaching the ground,
       ! but 0 if there is snow capping.

       if (do_capsnow(c)) then
          qflx_rain_grnd(p) = 0._r8
          qflx_snow_grnd(p) = 0._r8
          h2osno(c) = h2osno(c) - (qmelt(c) + qflx_sub_snow(p))*dtime
          qflx_snwcp_ice(p) = forc_snow(g) + qflx_dew_snow(p)
          do m = 1, pwtrc
            wtr_qflx_rain_grnd(p,m) = 0._r8
            wtr_qflx_snow_grnd(p,m) = 0._r8
            wtr_h2osno(c,m) = wtr_h2osno(c,m) - (wtr_qmelt(c,m) + wtr_qflx_sub_snow(p,m))*dtime
            wtr_qflx_snwcp_ice(p,m) = forc_wtr_snow(g,m) + wtr_qflx_dew_snow(p,m)
          end do
       else
          qflx_rain_grnd(p) = forc_rain(g)
          qflx_snow_grnd(p) = forc_snow(g)
          h2osno(c) = h2osno(c) + (forc_snow(g)-qmelt(c)-qflx_sub_snow(p)+qflx_dew_snow(p))*dtime
          qflx_snwcp_ice(p) = 0._r8
          do m = 1, pwtrc
            wtr_qflx_rain_grnd(p,m) = forc_wtr_rain(g,m)
            wtr_qflx_snow_grnd(p,m) = forc_wtr_snow(g,m)
            wtr_h2osno(c,m) = wtr_h2osno(c,m) + (forc_wtr_snow(g,m)-wtr_qmelt(c,m)-wtr_qflx_sub_snow(p,m)+ &
                              wtr_qflx_dew_snow(p,m))*dtime
            wtr_qflx_snwcp_ice(p,m) = 0._r8
          end do
       end if
       h2osno(c) = max(h2osno(c), 0._r8)
       do m = 1, pwtrc
         wtr_h2osno(c,m) = max(wtr_h2osno(c,m), 0._r8)
         if (h2osno(c) == 0._r8) then   ! check: if no snow, no isotope snow
            wtr_qflx_sub_snow(p,m)=wtr_qflx_sub_snow(p,m)+(wtr_h2osno(c,m)/dtime) !DEBUG
            wtr_h2osno(c,m) = 0._r8
         end if
       end do

       ! No snow if lake unfrozen

       if (t_grnd(c) > tfrz) then
         h2osno(c) = 0._r8
         do m = 1, pwtrc
           wtr_h2osno(c,m) = 0._r8
         end do
       end if

       ! Snow depth

       snowdp(c) = h2osno(c)/snow_bd !Assume a constant snow bulk density = 250.

       ! Determine ending water balance

       endwb(c) = h2osno(c)
       do m = 1, pwtrc
         wtr_endwb(c,m) = wtr_h2osno(c,m)
       end do

       ! The following are needed for global average on history tape.
       ! Note that components that are not displayed over lake on history tape
       ! must be set to spval here

       eflx_snomelt(c)   = qmelt(c)*hfus
       qflx_infl(c)      = 0._r8
       qflx_snomelt(c)   = qmelt(c)
       qflx_surf(c)      = 0._r8
       qflx_drain(c)     = 0._r8
       qflx_irrig(c)     = 0._r8
       rootr_column(c,:) = spval
       snowice(c)        = spval
       snowliq(c)        = spval
       soilalpha(c)      = spval
       zwt(c)            = spval
       fcov(c)           = spval
       fsat(c)           = spval
       qcharge(c)        = spval
       h2osoi_vol(c,:)   = spval
       h2osoi_ice(c,:)   = spval
       h2osoi_liq(c,:)   = spval
       qflx_snofrz_col(c) = spval
       qflx_qrgwl(c)     = forc_rain(g) + forc_snow(g) + qflx_floodg(g) - qflx_evap_tot(p) - qflx_snwcp_ice(p) - &
                           (endwb(c)-begwb(c))/dtime
       qflx_floodc(c) = qflx_floodg(g)
       qflx_runoff(c)    = qflx_drain(c) + qflx_surf(c) + qflx_qrgwl(c)
       qflx_top_soil(c)      = forc_rain(g) + qflx_snomelt(c)
       qflx_prec_grnd(p)     = forc_rain(g) + forc_snow(g)

       ! pft averages must be done here for output to history tape and other uses
       ! (note that pft2col is called before HydrologyLake, so we can't use that routine
       ! to do these column -> pft averages)

       do m = 1, pwtrc
         wtr_qflx_infl(c,m)      = 0._r8
         wtr_qflx_snomelt(c,m)   = wtr_qmelt(c,m)
         wtr_qflx_surf(c,m)      = 0._r8
         wtr_qflx_drain(c,m)     = 0._r8
         wtr_qflx_irrig(c,m)     = 0._r8
         wtr_snowice(c,m)        = spval
         wtr_snowliq(c,m)        = spval
         wtr_h2osoi_vol(c,:,m)   = spval
         wtr_h2osoi_ice(c,:,m)   = spval
         wtr_h2osoi_liq(c,:,m)   = spval
         wtr_qflx_snofrz_col(c,m)= spval
         wtr_qflx_qrgwl(c,m)     = forc_wtr_rain(g,m) + forc_wtr_snow(g,m) + wtr_qflx_floodg(g,m) - wtr_qflx_evap_tot(p,m) - &
                                   wtr_qflx_snwcp_ice(p,m) - (wtr_endwb(c,m)-wtr_begwb(c,m))/dtime
         wtr_qflx_floodc(c,m)    = wtr_qflx_floodg(g,m)
         wtr_qflx_runoff(c,m)    = wtr_qflx_drain(c,m) + wtr_qflx_surf(c,m) + wtr_qflx_qrgwl(c,m)
         wtr_qflx_top_soil(c,m)  = forc_wtr_rain(g,m) + wtr_qflx_snomelt(c,m)
         wtr_qflx_prec_grnd(p,m) = forc_wtr_rain(g,m) + forc_wtr_snow(g,m)
       end do

       qflx_evap_tot_col(c)  = qflx_evap_tot(p)
       qflx_prec_grnd_col(c) = qflx_prec_grnd(p)
       qflx_evap_grnd_col(c) = qflx_evap_grnd(p)
       qflx_dew_grnd_col(c)  = qflx_dew_grnd(p)
       qflx_dew_snow_col(c)  = qflx_dew_snow(p)
       qflx_sub_snow_col(c)  = qflx_sub_snow(p)
       qflx_rain_grnd_col(c) = qflx_rain_grnd(p)
       qflx_snow_grnd_col(c) = qflx_snow_grnd(p)
       qflx_snwcp_ice_col(c) = qflx_snwcp_ice(p)
       do m = 1, pwtrc
         wtr_qflx_evap_tot_col(c,m)  = wtr_qflx_evap_tot(p,m)
         wtr_qflx_prec_grnd_col(c,m) = wtr_qflx_prec_grnd(p,m)
         wtr_qflx_evap_grnd_col(c,m) = wtr_qflx_evap_grnd(p,m)
         wtr_qflx_dew_grnd_col(c,m)  = wtr_qflx_dew_grnd(p,m)
         wtr_qflx_dew_snow_col(c,m)  = wtr_qflx_dew_snow(p,m)
         wtr_qflx_sub_snow_col(c,m)  = wtr_qflx_sub_snow(p,m)
         wtr_qflx_rain_grnd_col(c,m) = wtr_qflx_rain_grnd(p,m)
         wtr_qflx_snow_grnd_col(c,m) = wtr_qflx_snow_grnd(p,m)
         wtr_qflx_snwcp_ice_col(c,m) = wtr_qflx_snwcp_ice(p,m)
       end do
    end do

  end subroutine HydrologyLake

end module HydrologyLakeMod
