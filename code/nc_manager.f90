#define SAY_LESS
#include "cppdefs.h"
module nc_manager
  !----------------------------------------------------------------
  ! Some useful netCDF subroutines
  !----------------------------------------------------------------
  use mod_precdefs
  use netcdf
  implicit none
  private
  !===================================================
  !---------------------------------------------
  public :: nc_read_real_1d, nc_read_real_2d, nc_read_real_3d, nc_read_real_4d, nc_read_time_val, &
            nc_get_dim_len, nc_get_file_dims, nc_get_file_vars, nc_get_var_dims, nc_get_var_fillvalue, &
            nc_get_timeunit, nc_attr_exists, nc_get_attr, nc_var_exists, nc_check

  !---------------------------------------------
  ! Public write variables/functions
  public :: FILLVALUE_BIG, FILLVALUE_TOPO, &
            nc_initialise, nc_add_dimension, &
            nc_add_variable, nc_add_attr, nc_write

  !---------------------------------------------
  real(rk), parameter :: FILLVALUE_TOPO = -10.0_rk
  real(rk), parameter :: FILLVALUE_BIG = nf90_fill_float
  !---------------------------------------------
  ! Overload the writing subroutines
  interface nc_write
    module procedure nc_write_real_1d
    module procedure nc_write_int_2d_const
    module procedure nc_write_real_2d_const
    module procedure nc_write_real_3d
    module procedure nc_write_int_3d_const
    module procedure nc_write_real_3d_const
    module procedure nc_write_real_4d
  end interface nc_write
  interface nc_add_attr
    module procedure nc_add_glob_attr_text
    module procedure nc_add_glob_attr_numeric_int
    module procedure nc_add_glob_attr_numeric_real
    module procedure nc_add_var_attr_text
    module procedure nc_add_var_attr_numeric_int
    module procedure nc_add_var_attr_numeric_real
  end interface nc_add_attr
  interface nc_get_attr
    module procedure nc_get_glob_attr_text
    module procedure nc_get_glob_attr_numeric_int
    module procedure nc_get_glob_attr_numeric_real
    module procedure nc_get_var_attr_text
    module procedure nc_get_var_attr_numeric_int
    module procedure nc_get_var_attr_numeric_real
  end interface nc_get_attr
  !===================================================
contains
  !===========================================
  subroutine nc_initialise(FILE_NAME)

    integer                      :: ncid
    character(len=*), intent(in) :: FILE_NAME

    FMT1, "======== Init netCDF output ========"

    call nc_check(trim(FILE_NAME), nf90_create(trim(FILE_NAME), nf90_netcdf4, ncid), "init :: create")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "init :: close")

    FMT2, trim(FILE_NAME), " initialized successfully"

    return
  end subroutine nc_initialise
  !===========================================
  subroutine nc_add_dimension(FILE_NAME, dimname, dimid, dimsize)

    integer, intent(inout)         :: dimid
    integer, intent(in), optional  :: dimsize
    integer                        :: ncid
    character(len=*), intent(in)   :: dimname
    character(len=*), intent(in)   :: FILE_NAME

    FMT1, "======== Add netCDF dimension ========"
    FMT2, "Adding dimension ", trim(dimname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "add dim :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "add dim :: redef mode")
    if (present(dimsize)) then
      call nc_check(trim(FILE_NAME), nf90_def_dim(ncid, trim(dimname), dimsize, dimid), "add dim :: def "//trim(dimname))
    else
      call nc_check(trim(FILE_NAME), nf90_def_dim(ncid, trim(dimname), nf90_unlimited, dimid), "add dim :: def "//trim(dimname))
    end if
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "add dim :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "add dim :: close")

    FMT2, trim(dimname), " added successfully"

    return
  end subroutine nc_add_dimension
  !===========================================
  subroutine nc_add_variable(FILE_NAME, varname, dType, nDims, dimids, missing_val)
    !---------------------------------------------
    ! Add variables to output file
    !---------------------------------------------

    character(len=*), intent(in)   :: FILE_NAME
    character(len=*), intent(in)   :: varname
    character(len=*), intent(in)   :: dType
    integer, intent(in)            :: nDims
    integer, intent(in)            :: dimids(nDims)
    integer                        :: ncid, varid
    real(rk), intent(in), optional :: missing_val

    FMT1, "======== Add netCDF variable ========"
    FMT2, "Adding variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "add var :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "add var :: redef mode")
    select case (dType)
    case ('float')
      call nc_check(trim(FILE_NAME), nf90_def_var(ncid, varname, nf90_double, dimids, varid), "add var :: def "//trim(varname))
      if (present(missing_val)) then
        call nc_check(trim(FILE_NAME), nf90_put_att(ncid, varid, "missing_value", missing_val), "add var :: def "//trim(varname))
      end if
    case ('int')
      call nc_check(trim(FILE_NAME), nf90_def_var(ncid, varname, nf90_int, dimids, varid), "add var :: def "//trim(varname))
      if (present(missing_val)) then
      call nc_check(trim(FILE_NAME), nf90_put_att(ncid, varid, "missing_value", int(missing_val)), "add var :: def "//trim(varname))
      end if
    end select
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "add var :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "add var :: close")

    FMT2, trim(varname), " added successfully"

    return
  end subroutine nc_add_variable
  !===========================================
  subroutine nc_add_glob_attr_text(FILE_NAME, attrname, attrval)
    !---------------------------------------------
    ! Add attribute to variable
    !---------------------------------------------

    character(len=*), intent(in)   :: FILE_NAME
    character(len=*), intent(in)   :: attrname, attrval
    integer                        :: ncid

    FMT1, "======== Add netCDF attribute ========"
    FMT2, "Adding attribute ", trim(attrname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "nc_add_glob_attr_text :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "nc_add_glob_attr_text :: redef mode")
    call nc_check(trim(FILE_NAME), nf90_put_att(ncid, nf90_global, trim(attrname), trim(attrval)), "nc_add_glob_attr_text :: put "//trim(attrname))
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "nc_add_glob_attr_text :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "nc_add_glob_attr_text :: close")

    FMT2, trim(attrname), " added successfully"

    return
  end subroutine nc_add_glob_attr_text
  !===========================================
  subroutine nc_add_glob_attr_numeric_int(FILE_NAME, attrname, attrval)
    !---------------------------------------------
    ! Add attribute to variable
    !---------------------------------------------

    character(len=*), intent(in)   :: FILE_NAME
    character(len=*), intent(in)   :: attrname
    integer, intent(in)           :: attrval
    integer                        :: ncid

    FMT1, "======== Add netCDF attribute ========"
    FMT2, "Adding attribute ", trim(attrname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "nc_add_glob_attr_numeric :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "nc_add_glob_attr_numeric :: redef mode")
    call nc_check(trim(FILE_NAME), nf90_put_att(ncid, nf90_global, trim(attrname), attrval), "nc_add_glob_attr_numeric :: put "//trim(attrname))
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "nc_add_glob_attr_numeric :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "nc_add_glob_attr_numeric :: close")

    FMT2, trim(attrname), " added successfully"

    return
  end subroutine nc_add_glob_attr_numeric_int
  !===========================================
  subroutine nc_add_glob_attr_numeric_real(FILE_NAME, attrname, attrval)
    !---------------------------------------------
    ! Add attribute to variable
    !---------------------------------------------

    character(len=*), intent(in)   :: FILE_NAME
    character(len=*), intent(in)   :: attrname
    real(rk), intent(in)           :: attrval
    integer                        :: ncid

    FMT1, "======== Add netCDF attribute ========"
    FMT2, "Adding attribute ", trim(attrname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "nc_add_glob_attr_numeric :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "nc_add_glob_attr_numeric :: redef mode")
    call nc_check(trim(FILE_NAME), nf90_put_att(ncid, nf90_global, trim(attrname), attrval), "nc_add_glob_attr_numeric :: put "//trim(attrname))
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "nc_add_glob_attr_numeric :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "nc_add_glob_attr_numeric :: close")

    FMT2, trim(attrname), " added successfully"

    return
  end subroutine nc_add_glob_attr_numeric_real
  !===========================================
  subroutine nc_add_var_attr_text(FILE_NAME, varname, attrname, attrval)
    !---------------------------------------------
    ! Add attribute to variable
    !---------------------------------------------

    character(len=*), intent(in)   :: FILE_NAME
    character(len=*), intent(in)   :: varname, attrname, attrval
    integer                        :: ncid, varid

    FMT1, "======== Add netCDF attribute ========"
    FMT2, "Adding attribute ", trim(attrname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "nc_add_var_attr_text :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "nc_add_var_attr_text :: redef mode")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "nc_add_var_attr_text :: inq varid")
    call nc_check(trim(FILE_NAME), nf90_put_att(ncid, varid, trim(attrname), trim(attrval)), "nc_add_var_attr_text :: put "//trim(attrname))
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "nc_add_var_attr_text :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "nc_add_var_attr_text :: close")

    FMT2, trim(attrname), " added successfully"

    return
  end subroutine nc_add_var_attr_text
  !===========================================
  subroutine nc_add_var_attr_numeric_int(FILE_NAME, varname, attrname, attrval)
    !---------------------------------------------
    ! Add attribute to variable
    !---------------------------------------------

    character(len=*), intent(in)   :: FILE_NAME
    character(len=*), intent(in)   :: varname, attrname
    integer, intent(in)            :: attrval
    integer                        :: ncid, varid

    FMT1, "======== Add netCDF attribute ========"
    FMT2, "Adding attribute ", trim(attrname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "nc_add_var_attr_numeric :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "nc_add_var_attr_numeric :: redef mode")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "nc_add_var_attr_numeric :: inq varid")
    call nc_check(trim(FILE_NAME), nf90_put_att(ncid, varid, trim(attrname), attrval), "nc_add_var_attr_numeric :: put "//trim(attrname))
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "nc_add_var_attr_numeric :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "nc_add_var_attr_numeric :: close")

    FMT2, trim(attrname), " added successfully"

    return
  end subroutine nc_add_var_attr_numeric_int
  !===========================================
  subroutine nc_add_var_attr_numeric_real(FILE_NAME, varname, attrname, attrval)
    !---------------------------------------------
    ! Add attribute to variable
    !---------------------------------------------

    character(len=*), intent(in)   :: FILE_NAME
    character(len=*), intent(in)   :: varname, attrname
    real(rk), intent(in)           :: attrval
    integer                        :: ncid, varid

    FMT1, "======== Add netCDF attribute ========"
    FMT2, "Adding attribute ", trim(attrname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "nc_add_var_attr_numeric :: open")
    call nc_check(trim(FILE_NAME), nf90_redef(ncid), "nc_add_var_attr_numeric :: redef mode")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "nc_add_var_attr_numeric :: inq varid")
    call nc_check(trim(FILE_NAME), nf90_put_att(ncid, varid, trim(attrname), attrval), "nc_add_var_attr_numeric :: put "//trim(attrname))
    call nc_check(trim(FILE_NAME), nf90_enddef(ncid), "nc_add_var_attr_numeric :: end def")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "nc_add_var_attr_numeric :: close")

    FMT2, trim(attrname), " added successfully"

    return
  end subroutine nc_add_var_attr_numeric_real
  !===========================================
  subroutine nc_write_real_1d(FILE_NAME, datain, varname, nvals)
    !---------------------------------------------
    ! Write 1D real data with no time axis (output will be 1D)
    !---------------------------------------------

    integer, parameter           :: nDims = 1
    integer                      :: ncid, varid, start(nDims), count(nDims)
    integer, intent(in)          :: nvals
    character(len=*), intent(in) :: FILE_NAME
    character(len=*), intent(in) :: varname
    real(rk), intent(in)         :: datain(nvals)

    FMT1, "======== Write netCDF variable ========"
    FMT2, "Writing variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "write :: open")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "write :: inq varid")
    start = (/1/)
    count = (/nvals/)
    call nc_check(trim(FILE_NAME), nf90_put_var(ncid, varid, datain, start=start, count=count), "write :: put var")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "write :: close")

    FMT2, trim(varname), " written successfully"

    return
  end subroutine nc_write_real_1d
  !===========================================
  subroutine nc_write_int_2d_const(FILE_NAME, datain, varname, nx, ny)
    !---------------------------------------------
    ! Write 2D integer data with no time axis (output will be 2D)
    !---------------------------------------------

    integer, intent(in)          :: nx, ny
    integer, intent(in)          :: datain(nx, ny)
    integer, parameter           :: nDims = 2
    integer                      :: ncid, varid, start(nDims), count(nDims)
    character(len=*), intent(in) :: FILE_NAME
    character(len=*), intent(in) :: varname

    FMT1, "======== Write netCDF variable ========"
    FMT2, "Writing variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "write :: open")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "write :: inq varid")
    start = (/1, 1/)
    count = (/nx, ny/)
    call nc_check(trim(FILE_NAME), nf90_put_var(ncid, varid, datain, start=start, count=count), "write :: put var")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "write :: close")

    FMT2, trim(varname), " written successfully"

    return
  end subroutine nc_write_int_2d_const
  !===========================================
  subroutine nc_write_real_2d_const(FILE_NAME, datain, varname, nx, ny)
    !---------------------------------------------
    ! Write 2D real data with no time axis (output will be 2D)
    !---------------------------------------------

    integer, parameter           :: nDims = 2
    integer                      :: ncid, varid, start(nDims), count(nDims)
    integer, intent(in)          :: nx, ny
    character(len=*), intent(in) :: FILE_NAME
    character(len=*), intent(in) :: varname
    real(rk), intent(in)         :: datain(nx, ny)

    FMT1, "======== Write netCDF variable ========"
    FMT2, "Writing variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "write :: open")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "write :: inq varid")
    start = (/1, 1/)
    count = (/nx, ny/)
    call nc_check(trim(FILE_NAME), nf90_put_var(ncid, varid, datain, start=start, count=count), "write :: put var")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "write :: close")

    FMT2, trim(varname), " written successfully"

    return
  end subroutine nc_write_real_2d_const
  !===========================================
  subroutine nc_write_real_3d(FILE_NAME, datain, varname, nx, ny, itime)
    !---------------------------------------------
    ! Write 2D real data to itime time step (output will be 3D)
    !---------------------------------------------

    integer, intent(in)          :: nx, ny, itime
    integer, parameter           :: nDims = 3
    integer                      :: ncid, varid, start(nDims), count(nDims)
    character(len=*), intent(in) :: FILE_NAME
    character(len=*), intent(in) :: varname
    real(rk), intent(in)         :: datain(nx, ny)

    FMT1, "======== Write netCDF variable ========"
    FMT2, "Writing variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "write :: open")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "write :: inq varid")
    start = [1, 1, itime]
    count = [nx, ny, 1]
    call nc_check(trim(FILE_NAME), nf90_put_var(ncid, varid, datain, start=start, count=count), "write :: put var")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "write :: close")

    FMT2, trim(varname), " written successfully"

    return
  end subroutine nc_write_real_3d
  !===========================================
  subroutine nc_write_int_3d_const(FILE_NAME, datain, varname, nx, ny, ntime)
    !---------------------------------------------
    ! Write 3D real data (output will be 3D)
    !---------------------------------------------

    integer, intent(in)          :: nx, ny, ntime
    integer, parameter           :: nDims = 3
    integer                      :: ncid, varid, start(nDims), count(nDims)
    character(len=*), intent(in) :: FILE_NAME
    character(len=*), intent(in) :: varname
    integer, intent(in)          :: datain(nx, ny, ntime)

    FMT1, "======== Write netCDF variable ========"
    FMT2, "Writing variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "write :: open")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "write :: inq varid")
    start = [1, 1, 1]
    count = [nx, ny, ntime]
    call nc_check(trim(FILE_NAME), nf90_put_var(ncid, varid, datain, start=start, count=count), "write :: put var")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "write :: close")

    FMT2, trim(varname), " written successfully"

    return
  end subroutine nc_write_int_3d_const
  !===========================================
  subroutine nc_write_real_3d_const(FILE_NAME, datain, varname, nx, ny, ntime)
    !---------------------------------------------
    ! Write 3D real data (output will be 3D)
    !---------------------------------------------

    integer, intent(in)          :: nx, ny, ntime
    integer, parameter           :: nDims = 3
    integer                      :: ncid, varid, start(nDims), count(nDims)
    character(len=*), intent(in) :: FILE_NAME
    character(len=*), intent(in) :: varname
    real(rk), intent(in)         :: datain(nx, ny, ntime)

    FMT1, "======== Write netCDF variable ========"
    FMT2, "Writing variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "write :: open")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "write :: inq varid")
    start = [1, 1, 1]
    count = [nx, ny, ntime]
    call nc_check(trim(FILE_NAME), nf90_put_var(ncid, varid, datain, start=start, count=count), "write :: put var")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "write :: close")

    FMT2, trim(varname), " written successfully"

    return
  end subroutine nc_write_real_3d_const
  !===========================================
  subroutine nc_write_real_4d(FILE_NAME, datain, varname, nx, ny, nz, itime)
    !---------------------------------------------
    ! Write 3D real data to itime time step (output will be 4D)
    !---------------------------------------------

    integer, intent(in)          :: nx, ny, nz, itime
    integer, parameter           :: nDims = 4
    integer                      :: ncid, varid, start(nDims), count(nDims)
    character(len=*), intent(in) :: FILE_NAME
    character(len=*), intent(in) :: varname
    real(rk), intent(in)         :: datain(nx, ny, nz)

    FMT1, "======== Write netCDF variable ========"
    FMT2, "Writing variable ", trim(varname), " to ", trim(FILE_NAME)

    call nc_check(trim(FILE_NAME), nf90_open(trim(FILE_NAME), nf90_write, ncid), "write :: open")
    call nc_check(trim(FILE_NAME), nf90_inq_varid(ncid, trim(varname), varid), "write :: inq varid")
    start = (/1, 1, 1, itime/)
    count = (/nx, ny, nz, 1/)
    call nc_check(trim(FILE_NAME), nf90_put_var(ncid, varid, datain, start=start, count=count), "write :: put var")
    call nc_check(trim(FILE_NAME), nf90_close(ncid), "write :: close")

    FMT2, trim(varname), " written successfully"

    return
  end subroutine nc_write_real_4d
  !===========================================
  subroutine nc_read_real_1d(fname, vname, nvals, dataout)

    integer               :: nvals
    integer               :: ncid, varid
    character(len=*)      :: fname
    character(len=*)      :: vname
    real(rk), intent(out) :: dataout(nvals)

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_read_real_1d :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, vname, varid), "nc_read_real_1d :: inq_varid "//trim(vname))
    call nc_check(trim(fname), nf90_get_var(ncid, varid, dataout), "nc_read_real_1d :: get_var "//trim(vname))
    call nc_check(trim(fname), nf90_close(ncid), "nc_read_real_1d :: close")

    return
  end subroutine nc_read_real_1d
  !===========================================
  subroutine nc_read_real_2d(fname, vname, nx, ny, dataout, start, count)

    integer               :: nx, ny
    integer               :: ncid, varid
    integer, optional     :: start(2), count(2)
    character(len=*)      :: fname
    character(len=*)      :: vname
    real(rk), intent(out) :: dataout(nx, ny)

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_read_real_2d :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, vname, varid), "nc_read_real_2d :: inq_varid "//trim(vname))
    if (present(start)) then
call nc_check(trim(fname), nf90_get_var(ncid, varid, dataout, start=start, count=count), "nc_read_real_2d :: get_var "//trim(vname))
    else
      call nc_check(trim(fname), nf90_get_var(ncid, varid, dataout), "nc_read_real_2d :: get_var "//trim(vname))
    end if
    call nc_check(trim(fname), nf90_close(ncid), "nc_read_real_2d :: close")

    return
  end subroutine nc_read_real_2d
  !===========================================
  subroutine nc_read_real_3d(fname, vname, start, count, dataout)
    integer               :: ncid, varid
    integer, dimension(3) :: start, count
    character(len=*)      :: fname
    character(len=*)      :: vname
    real(rk), intent(out) :: dataout(count(1), count(2), count(3))

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_read_real_3d :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, vname, varid), "nc_read_real_3d :: inq_varid "//trim(vname))
    call nc_check(trim(fname), nf90_get_var(ncid, varid, dataout, start=start, &
                                            count=count), "nc_read_real_3d :: get_var "//trim(vname))
    call nc_check(trim(fname), nf90_close(ncid), "nc_read_real_3d :: close")

    return
  end subroutine nc_read_real_3d
  !===========================================
  subroutine nc_read_real_4d(fname, vname, start, count, dataout)

    integer               :: ncid, varid
    integer, dimension(4) :: start, count
    character(len=*)      :: fname
    character(len=*)      :: vname
    real(rk), intent(out) :: dataout(count(1), count(2), count(3), count(4))

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_read_real_4d :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, vname, varid), "nc_read_real_4d :: inq_varid "//trim(vname))
    call nc_check(trim(fname), nf90_get_var(ncid, varid, dataout, start=start, &
                                            count=count), "nc_read_real_4d :: get_var "//trim(vname))
    call nc_check(trim(fname), nf90_close(ncid), "nc_read_real_4d :: close")

    return
  end subroutine nc_read_real_4d
  !===========================================
  real(rk) function nc_read_time_val(fname, n) result(res)

    integer                      :: ncid, varid
    integer, intent(in)          :: n
    character(len=*), intent(in) :: fname
    real(rk)                     :: tmpval(1)

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_read_time_val :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, 'time', varid), "nc_read_time_val :: inq_var_id 'time'")
    call nc_check(trim(fname), nf90_get_var(ncid, varid, tmpval, start=[n], count=[1]), "nc_read_time_val :: get_var 'time'")
    call nc_check(trim(fname), nf90_close(ncid), "nc_read_time_val :: close")

    res = tmpval(1)

    return
  end function nc_read_time_val
  !===========================================
  subroutine nc_get_dim_len(fname, dname, dimlen)
    !---------------------------------------------
    ! Inquire the length of a dimension
    !---------------------------------------------

    integer, intent(out)         :: dimlen
    integer                      :: ncid, dimid
    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: dname

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "get_dim_len :: open")
    call nc_check(trim(fname), nf90_inq_dimid(ncid, dname, dimid), 'get_dim_len :: inq_dim_id '//trim(dname))
    call nc_check(trim(fname), nf90_inquire_dimension(ncid, dimid, len=dimlen), 'get_dim_len :: inq_dim '//trim(dname))
    call nc_check(trim(fname), nf90_close(ncid), 'get_dim_len :: close')

    return
  end subroutine nc_get_dim_len
  !===========================================
  subroutine nc_get_file_dims(fname, ndims, dimnames, dimlens)
    !---------------------------------------------
    ! Inquire the dimensions of a file
    ! All outputs are optional
    ! Output: ndims, dimnames, dimlens
    !---------------------------------------------
    character(len=*), intent(in)  :: fname
    integer, intent(out), optional :: ndims
    character(len=*), allocatable, intent(out), optional :: dimnames(:)
    integer, allocatable, intent(out), optional :: dimlens(:)
    integer :: ncid, numdims
    integer :: i

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "get_file_dims :: open")
    call nc_check(trim(fname), nf90_inquire(ncid, nDimensions=numdims), "get_file_dims :: inquire")
    if (present(ndims)) then
      ndims = numdims
    end if

    if (present(dimnames)) then
      allocate (dimnames(numdims))
      do i = 1, numdims
        call nc_check(trim(fname), nf90_inquire_dimension(ncid, i, name=dimnames(i)), "get_file_dims :: inquire_dimension")
      end do
    end if

    if (present(dimlens)) then
      allocate (dimlens(numdims))
      do i = 1, numdims
        call nc_check(trim(fname), nf90_inquire_dimension(ncid, i, len=dimlens(i)), "get_file_dims :: inquire_dimension")
      end do
    end if

    call nc_check(trim(fname), nf90_close(ncid), "get_file_dims :: close")

    return
  end subroutine nc_get_file_dims
  !===========================================
  subroutine nc_get_file_vars(fname, nvars, varnames, vartypes, vardims)
    !---------------------------------------------
    ! Inquire the variables of a file
    ! All outputs are optional
    ! Output: nvars, varnames, vartypes, vardims
    !---------------------------------------------
    character(len=*), intent(in)  :: fname
    integer, intent(out), optional :: nvars
    character(len=*), allocatable, intent(out), optional :: varnames(:)
    integer, allocatable, intent(out), optional :: vartypes(:)
    integer, allocatable, intent(out), optional :: vardims(:)
    integer :: ncid, numvars
    integer :: i

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "get_file_vars :: open")
    call nc_check(trim(fname), nf90_inquire(ncid, nVariables=numvars), "get_file_vars :: inquire")
    if (present(nvars)) then
      nvars = numvars
    end if

    if (present(varnames)) then
      allocate (varnames(numvars))
      do i = 1, numvars
        call nc_check(trim(fname), nf90_inquire_variable(ncid, i, name=varnames(i)), "get_file_vars :: inquire_variable")
      end do
    end if

    if (present(vartypes)) then
      allocate (vartypes(numvars))
      do i = 1, numvars
        call nc_check(trim(fname), nf90_inquire_variable(ncid, i, xtype=vartypes(i)), "get_file_vars :: inquire_variable")
      end do
    end if

    if (present(vardims)) then
      allocate (vardims(numvars))
      do i = 1, numvars
        call nc_check(trim(fname), nf90_inquire_variable(ncid, i, ndims=vardims(i)), "get_file_vars :: inquire_variable")
      end do
    end if

    call nc_check(trim(fname), nf90_close(ncid), "get_file_vars :: close")

    return
  end subroutine nc_get_file_vars
  !===========================================
  subroutine nc_get_var_dims(fname, vname, ndims, dimnames, dimlens)
    !---------------------------------------------
    ! Inquire the dimensions of a variable
    ! All outputs are optional
    ! Output: ndims, dimnames, dimlens
    !---------------------------------------------
    character(len=*), intent(in)  :: fname
    character(len=*), intent(in)  :: vname
    integer, intent(out), optional :: ndims
    character(len=*), allocatable, intent(out), optional :: dimnames(:)
    integer, allocatable, intent(out), optional :: dimlens(:)
    integer :: ncid, varid, numdims
    integer :: dimids(nf90_max_var_dims)
    integer :: i

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "get_var_dims :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, vname, varid), "get_var_dims :: inq_var_id "//trim(vname))
    call nc_check(trim(fname), nf90_inquire_variable(ncid, varid, ndims=numdims), "get_var_dims :: inq_var "//trim(vname))
    if (present(ndims)) ndims = numdims

    if (present(dimnames) .or. present(dimlens)) then
    call nc_check(trim(fname), nf90_inquire_variable(ncid, varid, dimids=dimids(:numdims)), "get_var_dims :: inq_var "//trim(vname))
      if (present(dimnames)) then
        allocate (dimnames(numdims))
        do i = 1, numdims
      call nc_check(trim(fname), nf90_inquire_dimension(ncid, dimids(i), name=dimnames(i)), "get_var_dims :: inq_dim "//trim(vname))
        end do
      end if
      if (present(dimlens)) then
        allocate (dimlens(numdims))
        do i = 1, numdims
        call nc_check(trim(fname), nf90_inquire_dimension(ncid, dimids(i), len=dimlens(i)), "get_var_dims :: inq_dim "//trim(vname))
        end do
      end if
    end if

    call nc_check(trim(fname), nf90_close(ncid), "get_var_dims :: close")

    return
  end subroutine nc_get_var_dims
  !===========================================
  logical function nc_get_var_fillvalue(fname, vname, fill_value)
    !---------------------------------------------
    ! Inquire the fill value of a variable
    ! Output: fill_value
    ! Function returns .true. if fill value is found
    !---------------------------------------------
    character(len=*), intent(in)  :: fname
    character(len=*), intent(in)  :: vname
    real(rk), intent(out)             :: fill_value
    integer :: ncid, varid, status

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "get_var_fillvalue :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, vname, varid), "get_var_fillvalue :: inq_var_id "//trim(vname))
    status = nf90_get_att(ncid, varid, '_FillValue', fill_value)
    if (status == nf90_enotatt) then
      nc_get_var_fillvalue = .false.
    else if (status == nf90_noerr) then
      nc_get_var_fillvalue = .true.
    else
      call nc_check(trim(fname), status, "get_var_fillvalue :: get_attr '_FillValue' "//trim(vname))
    end if
    call nc_check(trim(fname), nf90_close(ncid), "get_var_fillvalue :: close")

    return
  end function nc_get_var_fillvalue
  !===========================================
  subroutine nc_get_timeunit(fname, timeunit)

    integer                       :: ncid, varid
    character(len=*), intent(in)  :: fname
    character(len=*), intent(out) :: timeunit

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "get_timeunit :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, "time", varid), "get_timeunit :: inq_var_id 'time'")
    call nc_check(trim(fname), nf90_get_att(ncid, varid, 'units', timeunit), "get_timeunit :: get_attr 'units'")
    call nc_check(trim(fname), nf90_close(ncid), 'get_timeunit :: close')

    return
  end subroutine nc_get_timeunit
  !===========================================
  logical function nc_attr_exists(fname, vname, attrname)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: vname
    character(len=*), intent(in) :: attrname
    integer                      :: ncid, varid

    nc_attr_exists = .true.
    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_attr_exists :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, trim(vname), varid), "nc_attr_exists :: inq_var_id "//trim(vname))
    if (nf90_inquire_attribute(ncid, varid, trim(attrname)) == nf90_enotatt) nc_attr_exists = .false.
    call nc_check(trim(fname), nf90_close(ncid), 'nc_attr_exists :: close')

    return
  end function nc_attr_exists
  !===========================================
  subroutine nc_get_glob_attr_text(fname, attrname, attr_text)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: attrname
    character(len=256), intent(out) :: attr_text
    integer                      :: ncid

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_get_glob_attr_text :: open")
    call nc_check(trim(fname), nf90_get_att(ncid, nf90_global, trim(attrname), attr_text), "nc_get_glob_attr_text :: get_attr '"//trim(attrname)//"'")
    call nc_check(trim(fname), nf90_close(ncid), "nc_get_glob_attr_text :: close")

  end subroutine nc_get_glob_attr_text
  !===========================================
  subroutine nc_get_glob_attr_numeric_int(fname, attrname, attr_val)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: attrname
    integer, intent(out)         :: attr_val
    integer                      :: ncid

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_get_glob_attr_numeric :: open")
call nc_check(trim(fname), nf90_get_att(ncid, nf90_global, trim(attrname), attr_val), "nc_get_glob_attr_numeric :: get_attr '"//trim(attrname)//"'")
    call nc_check(trim(fname), nf90_close(ncid), 'nc_get_glob_attr_numeric :: close')

    return
  end subroutine nc_get_glob_attr_numeric_int
  !===========================================
  subroutine nc_get_glob_attr_numeric_real(fname, attrname, attr_val)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: attrname
    real(rk), intent(out)        :: attr_val
    integer                      :: ncid

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_get_glob_attr_numeric :: open")
call nc_check(trim(fname), nf90_get_att(ncid, nf90_global, trim(attrname), attr_val), "nc_get_glob_attr_numeric :: get_attr '"//trim(attrname)//"'")
    call nc_check(trim(fname), nf90_close(ncid), 'nc_get_glob_attr_numeric :: close')

    return
  end subroutine nc_get_glob_attr_numeric_real
  !===========================================
  subroutine nc_get_var_attr_text(fname, vname, attrname, attr_text)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: vname
    character(len=*), intent(in) :: attrname
    character(len=256), intent(out) :: attr_text
    integer                      :: ncid, varid

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_get_var_attr_text :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, trim(vname), varid), "nc_get_var_attr_text :: inq_var_id "//trim(vname))
    call nc_check(trim(fname), nf90_get_att(ncid, varid, trim(attrname), attr_text), "nc_get_var_attr_text :: get_attr '"//trim(attrname)//"'")
    call nc_check(trim(fname), nf90_close(ncid), "nc_get_var_attr_text :: close")

  end subroutine nc_get_var_attr_text
  !===========================================
  subroutine nc_get_var_attr_numeric_int(fname, vname, attrname, attr_val)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: vname
    character(len=*), intent(in) :: attrname
    integer, intent(out)         :: attr_val
    integer                      :: ncid, varid

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_get_var_attr_numeric :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, trim(vname), varid), "nc_get_var_attr_numeric :: inq_var_id "//trim(vname))
call nc_check(trim(fname), nf90_get_att(ncid, varid, trim(attrname), attr_val), "nc_get_var_attr_numeric :: get_attr '"//trim(attrname)//"'")
    call nc_check(trim(fname), nf90_close(ncid), 'nc_get_var_attr_numeric :: close')

    return
  end subroutine nc_get_var_attr_numeric_int
  !===========================================
  subroutine nc_get_var_attr_numeric_real(fname, vname, attrname, attr_val)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: vname
    character(len=*), intent(in) :: attrname
    real(rk), intent(out)        :: attr_val
    integer                      :: ncid, varid

    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_get_var_attr_numeric :: open")
    call nc_check(trim(fname), nf90_inq_varid(ncid, trim(vname), varid), "nc_get_var_attr_numeric :: inq_var_id "//trim(vname))
call nc_check(trim(fname), nf90_get_att(ncid, varid, trim(attrname), attr_val), "nc_get_var_attr_numeric :: get_attr '"//trim(attrname)//"'")
    call nc_check(trim(fname), nf90_close(ncid), 'nc_get_var_attr_numeric :: close')

    return
  end subroutine nc_get_var_attr_numeric_real
  !===========================================
  logical function nc_var_exists(fname, vname)

    character(len=*), intent(in) :: fname
    character(len=*), intent(in) :: vname
    integer                      :: ncid, varid

    nc_var_exists = .true.
    call nc_check(trim(fname), nf90_open(fname, nf90_nowrite, ncid), "nc_var_exists :: open")
    if (nf90_inq_varid(ncid, trim(vname), varid) == nf90_enotvar) nc_var_exists = .false.
    call nc_check(trim(fname), nf90_close(ncid), 'nc_var_exists :: close')

  end function nc_var_exists
  !===========================================
  subroutine nc_check(fname, status, code)

    integer, intent(in) :: status
    character(len=*)    :: fname, code

    if (status /= nf90_noerr) then
      ERROR, "NETCDF: Stopped at "//trim(code)//" with ", status
      ERROR, trim(nf90_strerror(status))
      ERROR, "NETCDF: File name: "//trim(fname)
      stop
    end if

  end subroutine nc_check

end module nc_manager
