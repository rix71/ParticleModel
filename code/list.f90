#include "cppdefs.h"
module mod_list
  use mod_precdefs
  use mod_errors
  use mod_variable, only: t_variable
  use mod_field
  implicit none
  private
  !===================================================
  !---------------------------------------------
  public :: t_list
  !---------------------------------------------
  type t_node
    private
    class(t_variable), allocatable :: item
    character(len=LEN_CHAR_S)  :: key
    type(t_node), pointer      :: next => null()

  contains
    final :: dtor_node
  end type t_node
  !---------------------------------------------
  interface t_node
    module procedure :: ctor_node
  end interface t_node
  !---------------------------------------------
  type t_list
    private
    integer :: num_nodes = 0
    type(t_node), pointer :: head => null()
    type(t_node), pointer :: tail => null()

  contains
    private
    procedure, public :: size => l_get_size
    procedure, public :: add_node => l_add_node
    procedure, public :: key_exists => l_key_exists
    procedure, public :: node_loc => l_node_loc
    generic           :: get_node => l_get_idx_node, l_get_key_node
    procedure         :: l_get_idx_node, l_get_key_node
    procedure, public :: get_info => l_get_info
    generic, public   :: get_item => l_get_key_item, l_get_idx_item
    procedure         :: l_get_key_item, l_get_idx_item
    final             :: dtor_linked_list
  end type t_list
  !===================================================
contains
  !===========================================
  !---------------------------------------------
  ! Node functions
  !---------------------------------------------
  type(t_node) function ctor_node(data, key) result(n)
    class(t_variable), intent(in)    :: data
    character(len=*), intent(in) :: key

    n%item = data
    n%key = key

  end function ctor_node
  !===========================================
  recursive subroutine dtor_node(this)
    type(t_node), intent(inout) :: this

    if (allocated(this%item)) then
      deallocate (this%item)
    end if
    if (associated(this%next)) then
      deallocate (this%next)
    end if

  end subroutine dtor_node
  !===========================================
  !---------------------------------------------
  ! List functions
  !---------------------------------------------
  subroutine dtor_linked_list(this)
    type(t_list), intent(inout) :: this

    this%num_nodes = 0
    if (associated(this%head)) then
      deallocate (this%head)
    end if

  end subroutine dtor_linked_list
  !===========================================
  integer function l_get_size(this)
    class(t_list), intent(in) :: this

    l_get_size = this%num_nodes

  end function l_get_size
  !===========================================
  subroutine l_get_idx_node(this, idx, res)
    class(t_list), intent(in)          :: this
    integer, intent(in)                :: idx
    type(t_node), pointer, intent(out) :: res
    type(t_node), pointer              :: current_node
    integer                            :: i

    if (idx < 1) then
      call throw_error("list :: l_get_idx_node", "Index out of bounds")
    else if (idx > this%num_nodes) then
      call throw_error("list :: l_get_idx_node", "Index out of bounds")
    end if

    current_node => this%head
    do i = 2, idx
      current_node => current_node%next
    end do
    res => current_node

  end subroutine l_get_idx_node
  !===========================================
  subroutine l_get_key_node(this, key, res)
    class(t_list), intent(in)          :: this
    character(*), intent(in)           :: key
    type(t_node), pointer, intent(out) :: res
    type(t_node), pointer              :: current_node

    current_node => this%head
    if (associated(current_node)) then
      do while (associated(current_node))
        if (trim(current_node%key) == trim(key)) then
          res => current_node
          return
        end if
        current_node => current_node%next
      end do
      current_node => null()
      call throw_error("list :: l_get_key_node", "Did not find key: "//trim(key))
    else
      current_node => null()
      call throw_error("list :: l_get_key_node", "The list is empty")
    end if

  end subroutine l_get_key_node
  !===========================================
  subroutine l_get_key_item(this, key, res)
    class(t_list), intent(in)           :: this
    character(len=*), intent(in)        :: key
    class(t_variable), pointer, intent(out) :: res
    type(t_node), pointer               :: current_node

    call this%get_node(key, current_node)
    res => current_node%item
    current_node => null()

  end subroutine l_get_key_item
  !===========================================
  subroutine l_get_idx_item(this, idx, res)
    class(t_list), intent(in)           :: this
    integer, intent(in)                 :: idx
    class(t_variable), pointer, intent(out) :: res
    type(t_node), pointer               :: current_node

    call this%get_node(idx, current_node)
    res => current_node%item
    current_node => null()

  end subroutine l_get_idx_item
  !===========================================
  subroutine l_get_info(this)
    class(t_list), intent(in) :: this
    type(t_node), pointer     :: current_node
    class(t_variable), pointer :: item

    FMT2, "Nodes: ", this%num_nodes
    current_node => this%head
    do while (associated(current_node))
      FMT3, "-> "//trim(current_node%key)
      item => current_node%item
      select type (item)
      class is (t_field_static)
        FMT3, "  Static field", item%get_dim(), "D"
      class is (t_field_dynamic)
        FMT3, "  Dynamic field", item%get_dim(), "D"
      end select
      current_node => current_node%next
    end do
    current_node => null()

  end subroutine l_get_info
  !===========================================
  logical function l_key_exists(this, key) result(res)
    class(t_list), intent(in)    :: this
    character(len=*), intent(in) :: key
    type(t_node), pointer        :: current_node

    res = .false.
    current_node => this%head
    do while (associated(current_node))
      if (trim(current_node%key) == trim(key)) then
        res = .true.
        current_node => null()
        return
      end if
      current_node => current_node%next
    end do
  end function l_key_exists
  !===========================================
  integer function l_node_loc(this, key) result(res)
    class(t_list), intent(in) :: this
    character(len=*), intent(in) :: key
    type(t_node), pointer :: current_node
    integer :: count

    res = 0
    count = 1
    current_node => this%head
    do while (associated(current_node))
      if (trim(current_node%key) == trim(key)) then
        res = count
        return
      end if
      count = count + 1
      current_node => current_node%next
    end do

  end function l_node_loc
  !===========================================
  subroutine l_add_node(this, key, data)
    class(t_list), intent(inout) :: this
    class(t_variable), intent(in)    :: data
    character(len=*), intent(in) :: key

    if (associated(this%tail)) then
      if (.not. this%key_exists(key)) then
        allocate (this%tail%next, source=t_node(data, key))
        this%tail => this%tail%next
      else
        call throw_error("list :: l_add_node", "Key already exists: "//trim(key))
      end if
    else
      allocate (this%head, source=t_node(data, key))
      this%tail => this%head
    end if
    this%num_nodes = this%num_nodes + 1

  end subroutine l_add_node

end module mod_list
