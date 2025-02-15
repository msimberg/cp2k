!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2022 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Definition of disperson types for DFT calculations
!> \author JGH (20.10.2008)
! **************************************************************************************************
MODULE qs_dispersion_types

   USE input_section_types,             ONLY: section_vals_type
   USE kinds,                           ONLY: default_string_length,&
                                              dp
   USE qs_neighbor_list_types,          ONLY: neighbor_list_set_p_type,&
                                              release_neighbor_list_sets
#include "./base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'qs_dispersion_types'

! **************************************************************************************************
   INTEGER, PARAMETER                       :: dftd2_pp = 1
   INTEGER, PARAMETER                       :: dftd3_pp = 2

   TYPE qs_dispersion_type
      INTEGER                                :: TYPE
      INTEGER                                :: pp_type
      INTEGER                                :: nl_type
      CHARACTER(LEN=default_string_length)  :: ref_functional
      REAL(KIND=dp)                          :: scaling
      REAL(KIND=dp)                          :: rc_disp
      REAL(KIND=dp)                          :: exp_pre
      TYPE(section_vals_type), POINTER       :: dftd_section
      LOGICAL                                :: verbose !extended output
      CHARACTER(LEN=default_string_length)  :: parameter_file_name
      CHARACTER(LEN=default_string_length)  :: kernel_file_name
      !DFT-D3 global parameters
      INTEGER                                :: max_elem !elements parametrized
      INTEGER                                :: maxc !max coordination number references per element
      REAL(KIND=dp)                          :: k1, k2, k3 !ad hoc parameters
      REAL(KIND=dp)                          :: alp !ad hoc parameters
      REAL(KIND=dp)                          :: s6, s8, sr6 !scaling parameters
      REAL(KIND=dp)                          :: a1, a2 !BJ scaling parameters
      REAL(KIND=dp)                          :: eps_cn
      LOGICAL                                :: doabc !neglect C9 terms
      LOGICAL                                :: c9cnst !use constant c9 terms
      LOGICAL                                :: lrc !calculate a long range correction
      LOGICAL                                :: srb !calculate a short range bond correction
      REAL(KIND=dp), DIMENSION(4)            :: srb_params ! parameters for SRB (s,g,t1,t2)
      TYPE(neighbor_list_set_p_type), &
         DIMENSION(:), POINTER                :: sab_vdw, sab_cn ! neighborlists for pair interactions
      REAL(KIND=dp), DIMENSION(:, :, :, :, :), POINTER &
         :: c6ab
      INTEGER, DIMENSION(:), POINTER           :: maxci
      REAL(KIND=dp), DIMENSION(:, :), POINTER  :: r0ab
      REAL(KIND=dp), DIMENSION(:), POINTER    :: rcov !covalent radii
      REAL(KIND=dp), DIMENSION(:), POINTER    :: r2r4 !atomic <r^2>/<r^4> values
      REAL(KIND=dp), DIMENSION(:), POINTER    :: cn !coordination numbers (defaults)
      TYPE(cn_kind_list), DIMENSION(:), POINTER &
         :: cnkind
      TYPE(cn_atom_list), DIMENSION(:), POINTER &
         :: cnlist
      ! KG molecular corrections
      LOGICAL                                :: domol
      REAL(KIND=dp)                          :: kgc8 !s8 scaling parameter
      !vdW-DF variables
      REAL(KIND=dp)                          :: pw_cutoff
      REAL(KIND=dp)                          :: b_value, c_value, scale_rvv10 !parameters for the rVV10 functional
      INTEGER                                :: nqs, nr_points
      !! The number of q points and radial points
      !! used in generating the kernel phi(q1*r, q2*r)
      !! (see DION 14-16 and SOLER 3)
      REAL(KIND=dp)                          :: r_max, q_cut, q_min, dk
      !! The maximum value of r, the maximum and minimum
      !! values of q and the k-space spacing of grid points.
      !! Note that, during a vdW run, values of q0 found
      !! larger than q_cut will be saturated (SOLER 6-7) to
      !! q_cut
      REAL(KIND=dp), DIMENSION(:), POINTER    :: q_mesh !! The values of all the q points used
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER &
         :: kernel !! A matrix holding the Fourier transformed kernel function
      !! for each pair of q values.  The ordering is
      !! kernel(k_point, q1_value, q2_value)
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER &
         :: d2phi_dk2 !! A matrix holding the second derivatives of the above
      !! kernel matrix at each of the q points.  Stored as
      !! d2phi_dk2(k_point, q1_value, q2_value)
      REAL(KIND=dp), DIMENSION(:, :), POINTER  :: d2y_dx2 !! 2nd derivatives of q_mesh for interpolation
      INTEGER, DIMENSION(:, :), POINTER  :: d3_exclude_pair
      INTEGER  :: nd3_exclude_pair
   END TYPE qs_dispersion_type

   TYPE qs_atom_dispersion_type
      INTEGER                                :: TYPE
      LOGICAL                                :: defined
      REAL(KIND=dp)                          :: vdw_radii !van der Waals radii
      REAL(KIND=dp)                          :: c6 !c6 coefficients
   END TYPE qs_atom_dispersion_type

   TYPE cn_kind_list
      REAL(KIND=dp)                          :: cnum
      INTEGER                                :: kind
   END TYPE cn_kind_list
   TYPE cn_atom_list
      REAL(KIND=dp)                          :: cnum
      INTEGER                                :: natom
      INTEGER, DIMENSION(:), POINTER          :: atom
   END TYPE cn_atom_list

! **************************************************************************************************

   PUBLIC :: qs_atom_dispersion_type, qs_dispersion_type
   PUBLIC :: dftd2_pp, dftd3_pp
   PUBLIC :: qs_dispersion_release

! **************************************************************************************************
CONTAINS
! **************************************************************************************************
!> \brief ...
!> \param dispersion_env ...
! **************************************************************************************************
   SUBROUTINE qs_dispersion_release(dispersion_env)

      TYPE(qs_dispersion_type), POINTER                  :: dispersion_env

      INTEGER                                            :: i

      IF (ASSOCIATED(dispersion_env)) THEN
         IF (ASSOCIATED(dispersion_env%maxci)) THEN
            ! DFT-D3 arrays
            DEALLOCATE (dispersion_env%maxci)
            DEALLOCATE (dispersion_env%c6ab)
            DEALLOCATE (dispersion_env%r0ab)
            DEALLOCATE (dispersion_env%rcov)
            DEALLOCATE (dispersion_env%r2r4)
            DEALLOCATE (dispersion_env%cn)
            IF (ASSOCIATED(dispersion_env%cnkind)) THEN
               DEALLOCATE (dispersion_env%cnkind)
            END IF
            IF (ASSOCIATED(dispersion_env%cnlist)) THEN
               DO i = 1, SIZE(dispersion_env%cnlist)
                  DEALLOCATE (dispersion_env%cnlist(i)%atom)
               END DO
               DEALLOCATE (dispersion_env%cnlist)
            END IF
         END IF
         ! vdD-DF
         IF (ASSOCIATED(dispersion_env%q_mesh)) THEN
            DEALLOCATE (dispersion_env%q_mesh)
         END IF
         IF (ASSOCIATED(dispersion_env%kernel)) THEN
            DEALLOCATE (dispersion_env%kernel)
         END IF
         IF (ASSOCIATED(dispersion_env%d2phi_dk2)) THEN
            DEALLOCATE (dispersion_env%d2phi_dk2)
         END IF
         IF (ASSOCIATED(dispersion_env%d2y_dx2)) THEN
            DEALLOCATE (dispersion_env%d2y_dx2)
         END IF
         IF (ASSOCIATED(dispersion_env%d3_exclude_pair)) THEN
            DEALLOCATE (dispersion_env%d3_exclude_pair)
         END IF
         ! neighborlists
         CALL release_neighbor_list_sets(dispersion_env%sab_vdw)
         CALL release_neighbor_list_sets(dispersion_env%sab_cn)

         DEALLOCATE (dispersion_env)

      END IF

   END SUBROUTINE qs_dispersion_release

END MODULE qs_dispersion_types

