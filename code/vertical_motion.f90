#include "cppdefs.h"
#include "particle.h"
module mod_vertical_motion
  !----------------------------------------------------------------
  ! Calculates the particles' vertical velocity
  !----------------------------------------------------------------
  use mod_errors
  use mod_precdefs
  use mod_params
  use time_vars, only: dt
  use mod_physics, only: seawater_density, seawater_viscosity, bottom_friction_velocity
  use mod_particle, only: t_particle

  use mod_fieldset, only: t_fieldset
  implicit none
  private
  !===================================================
  !---------------------------------------------
  public :: vertical_velocity, correct_vertical_bounds
  !---------------------------------------------
  ! [variable/type definition]
  !===================================================
contains
  !===========================================
  subroutine vertical_velocity(p, fieldset, time)
    type(t_particle), intent(inout) :: p
    type(t_fieldset), intent(in)    :: fieldset
    real(rk), intent(in)            :: time
    real(rk)                        :: vert_vel
    real(rk)                        :: vel_buoyancy
    real(rk)                        :: vel_resuspension

    dbghead(vertical_motion :: vertical_velocity)
    debug(time)

    vel_buoyancy = buoyancy(p, fieldset, time, p%delta_rho, p%kin_visc)
    vel_resuspension = resuspension(p, fieldset, time, p%u_star)
    vert_vel = vel_buoyancy + vel_resuspension
    ! vert_vel = buoyancy(p, fieldset, time, p%delta_rho, p%kin_visc) + resuspension(p, fieldset, time, p%u_star)

    debug(vel_buoyancy); debug(vel_resuspension); debug(vert_vel)

    ! Correct velocity if particle jumps out of water
    vert_vel = correct_vertical_bounds(fieldset, time, p%lon0, p%lat0, p%depth1, vert_vel, ignore_bottom=.true.)
    DBG, "Vertical velocity after correction:"
    debug(vert_vel)

    p%depth1 = p%depth1 + (vert_vel * dt)
    p%vel_vertical = vert_vel

    call fieldset%search_indices(t=time, x=p%lon1, y=p%lat1, z=p%depth1, k=p%k1, kr=p%kr1)

    ! Check if the particle has settled, if so, set its' state to ST_BOTTOM
    call p%check_depth(fieldset, time)

    dbgtail(vertical_motion :: vertical_velocity)
    return
  end subroutine vertical_velocity
  !===========================================
  real(rk) function resuspension(p, fieldset, time, u_star) result(res)
    !---------------------------------------------
    ! Gives a settled particle vertical velocity if
    ! the bottom friction velocity exceeds a certain threshold
    ! TODO: currently, resuspension_threshold is a namelist parameter,
    ! perhaps should be calculated as the particles' critical flow velocity.
    ! Ref: Erosion Behavior of Different Microplastic Particles in Comparison to Natural Sediments
    !       Kryss Waldschläger and Holger Schüttrumpf
    !       Environmental Science & Technology 2019 53 (22), 13219-13227
    !       DOI: 10.1021/acs.est.9b05394
    !---------------------------------------------
    type(t_particle), intent(in) :: p
    type(t_fieldset), intent(in) :: fieldset
    real(rk), intent(in) :: time
    real(rk) :: i, j, k
    real(rk), intent(out) :: u_star

    res = ZERO
    u_star = ZERO
    if (p%state /= ST_BOTTOM) then
      return
    end if

    if (resuspension_coeff > ZERO) then

      i = p%ir0
      j = p%jr0
      k = p%kr0

#ifdef DEBUG
      if (k >= fieldset%zax_top_idx) then
        ERROR, "vertical_motion :: resuspension: particle is above the top of the domain"
        debug(i); debug(j); debug(k)
        debug(resuspension_coeff)
      end if
#endif

      u_star = bottom_friction_velocity(fieldset, time, i, j, k)
      if (u_star > resuspension_threshold) then
        res = u_star * resuspension_coeff
      end if
    end if

    return
  end function resuspension
  !===========================================
  real(rk) function buoyancy(p, fieldset, time, delta_rho, kin_visc) result(res)
    !---------------------------------------------
    ! Calculate the vertical velocity due to buoyancy
    ! TODO: Which timestep should be used? (original or t + dt?)
    !---------------------------------------------
    type(t_particle), intent(in)    :: p
    type(t_fieldset), intent(in)    :: fieldset
    real(rk), intent(in)            :: time
    real(rk)                        :: i, j, k
    real(rk)                        :: rho_sw    ! Fluid density
    real(rk), intent(out)           :: delta_rho ! Density difference
    real(rk), intent(out)           :: kin_visc  ! Kinematic viscosity (surrounding the particle)

    res = ZERO
    if (p%state /= ST_SUSPENDED) then
      return
    end if

    i = p%ir0
    j = p%jr0
    k = p%kr0

    rho_sw = ONE

    ! Density
    rho_sw = seawater_density(fieldset, time, i, j, k, p%depth0)
    delta_rho = p%rho - rho_sw

    ! Viscosity
    kin_visc = seawater_viscosity(fieldset, time, i, j, k, p%depth0)

    res = Kooi_vertical_velocity(delta_rho, p%radius, rho_sw, kin_visc)

#ifdef DEBUG
    if (res > 1.) then
      ERROR, "vertical_motion :: buoyancy: vertical velocity too large"
      ERROR, "vertical_motion :: buoyancy: vertical velocity = ", res
      ERROR, "vertical_motion :: buoyancy: particle state = ", p%state
      ERROR, "vertical_motion :: buoyancy: particle delta_rho = ", delta_rho
      ERROR, "vertical_motion :: buoyancy: seawater density = ", rho_sw
      ERROR, "vertical_motion :: buoyancy: seawater kin_visc = ", kin_visc
      ERROR, "vertical_motion :: buoyancy: particle vel_vertical = ", p%vel_vertical
      call throw_error("vertical_motion :: buoyancy", "Too high vertical velocity")
    end if
#endif

    return
  end function buoyancy
  !===========================================
  real(rk) function Kooi_vertical_velocity(delta_rho, rad_p, rho_env, kin_visc) result(res)
    !---------------------------------------------
    ! Calculate vertical velocity
    ! Reference: Kooi 2017
    !---------------------------------------------
    real(rk), intent(in) :: delta_rho, rad_p, rho_env
    real(rk), intent(in) :: kin_visc  ! Kinematic viscosity
    real(rk)             :: d_star    ! Dimensionless diameter
    real(rk)             :: w_star    ! Dimensionless settling velocity

    res = ZERO
    d_star = (delta_rho * g * (2.*rad_p)**3.) / (rho_env * (kin_visc**2.)) ! g negative?
    if (d_star < 0.05) then
      w_star = 1.74e-4 * (d_star**2)
    else if (d_star > 5.e9) then
      w_star = 1000.
    else
      w_star = 10.**(-3.76715 + (1.92944 * log10(d_star)) - (0.09815 * log10(d_star)**2.) &
                     - (0.00575 * log10(d_star)**3.) + (0.00056 * log10(d_star)**4.))
    end if
    if (delta_rho > ZERO) then
      res = -1.0 * ((delta_rho / rho_env) * g * w_star * kin_visc)**(1./3.)
    else
      res = (-1.0 * (delta_rho / rho_env) * g * w_star * kin_visc)**(1./3.)
    end if

    return
  end function Kooi_vertical_velocity
  !===========================================
  real(rk) function correct_vertical_bounds(fieldset, time, lon, lat, depth, vert_vel, ignore_bottom) result(res)
    type(t_fieldset), intent(in) :: fieldset
    real(rk), intent(in) :: time
    real(rk), intent(in) :: lon
    real(rk), intent(in) :: lat
    real(rk), intent(in) :: depth
    real(rk), intent(in) :: vert_vel
    logical, intent(in), optional :: ignore_bottom
    real(rk) :: elev
    real(rk) :: dep
    real(rk) :: target_depth
    integer :: i, j
    real(rk) :: ir, jr
    logical :: ignore

    res = vert_vel
    ignore = .false.
    if (present(ignore_bottom)) ignore = ignore_bottom

    call fieldset%search_indices(x=lon, y=lat, i=i, j=j, ir=ir, jr=jr)

    elev = fieldset%sealevel(time, ir, jr)
    if (depth + (vert_vel * dt) >= elev) then
      res = ((elev - depth) / dt) * 0.99_rk
    end if

    if (ignore) return

    dep = -ONE * fieldset%domain%get_bathymetry(i, j)
    if (depth + (vert_vel * dt) <= dep) then
      target_depth = 0.9_rk * dep
      res = (target_depth - depth) / dt
    end if
    ! if (depth + (vert_vel * dt) <= dep) then
    !   if (depth >= dep) then
    !     ! If we are still in the water column, but about to hit the bottom, then we have to go slower
    !     res = ((dep - depth) / dt) * 0.9_rk
    !   else
    !     ! If we're already undergound (due to horizontal transport), then we have to go up and faster
    !     res = ((dep - depth) / dt) * 1.1_rk
    !   end if
    ! end if

    return
  end function correct_vertical_bounds

end module mod_vertical_motion
