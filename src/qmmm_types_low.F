!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2022 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \par History
!>      05.2004 created [fawzi]
!> \author Fawzi Mohamed
! **************************************************************************************************
MODULE qmmm_types_low
   USE cp_eri_mme_interface,            ONLY: cp_eri_mme_finalize,&
                                              cp_eri_mme_param
   USE ewald_environment_types,         ONLY: ewald_env_release,&
                                              ewald_environment_type
   USE ewald_pw_types,                  ONLY: ewald_pw_release,&
                                              ewald_pw_type
   USE force_field_types,               ONLY: deallocate_inp_info,&
                                              init_inp_info,&
                                              input_info_type
   USE input_constants,                 ONLY: do_eri_mme,&
                                              do_qmmm_none
   USE kinds,                           ONLY: dp
   USE particle_types,                  ONLY: allocate_particle_set,&
                                              deallocate_particle_set,&
                                              particle_type
   USE pw_grid_types,                   ONLY: pw_grid_type
   USE pw_grids,                        ONLY: pw_grid_release
   USE pw_pool_types,                   ONLY: pw_pool_give_back_pw,&
                                              pw_pool_p_type,&
                                              pw_pool_release,&
                                              pw_pool_type,&
                                              pw_pools_dealloc
   USE pw_types,                        ONLY: pw_type
   USE qmmm_gaussian_types,             ONLY: qmmm_gaussian_p_type
#include "./base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   LOGICAL, PRIVATE, PARAMETER :: debug_this_module = .TRUE.
   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'qmmm_types_low'
   INTEGER, SAVE, PRIVATE :: last_qmmm_env_id_nr = 0
   INTEGER, PARAMETER, PUBLIC :: force_mixing_label_none = -1, &
                                 force_mixing_label_QM_core_list = 10, &
                                 force_mixing_label_QM_core = 9, &
                                 force_mixing_label_QM_dynamics_list = 8, &
                                 force_mixing_label_QM_dynamics = 7, &
                                 force_mixing_label_buffer_list = 6, &
                                 force_mixing_label_buffer = 5, &
                                 force_mixing_label_termination = 4

   PUBLIC :: qmmm_env_qm_type, qmmm_pot_type, qmmm_pot_p_type
   PUBLIC :: qmmm_env_qm_release, qmmm_env_qm_create
   PUBLIC :: qmmm_env_mm_type, qmmm_env_mm_create, qmmm_env_mm_retain, qmmm_env_mm_release
   PUBLIC :: qmmm_imomm_link_type, qmmm_links_type
   PUBLIC :: add_set_type, add_set_release, create_add_set_type
   PUBLIC :: add_shell_type, create_add_shell_type
   PUBLIC :: qmmm_per_pot_type, qmmm_per_pot_p_type

! **************************************************************************************************
!> \brief variables needed for QM/MM calculation in QM section
!> \par History
!>      05.2004 created [fawzi]
!> \author Fawzi Mohamed
!>      Teodoro Laino
! **************************************************************************************************
   TYPE gridlevel_info_type
      INTEGER                                                 :: auxbas_grid
      INTEGER                                                 :: coarser_grid
   END TYPE gridlevel_info_type

! **************************************************************************************************
!> \brief Real Space Potential
! **************************************************************************************************
   TYPE qmmm_pot_type
      REAL(KIND=dp), DIMENSION(:, :), POINTER :: Pot0_2
      REAL(KIND=dp)   :: Rmax, Rmin, dx, Rc
      INTEGER         :: npts
      INTEGER, DIMENSION(:), POINTER :: mm_atom_index
   END TYPE qmmm_pot_type

   TYPE qmmm_pot_p_type
      TYPE(qmmm_pot_type), POINTER :: pot
   END TYPE qmmm_pot_p_type

! **************************************************************************************************
!> \brief Periodic Potential
! **************************************************************************************************
   TYPE qmmm_per_pot_type
      REAL(KIND=dp), DIMENSION(:), POINTER :: lg, gx, gy, gz
      REAL(KIND=dp)  :: Gmax, Fac(3)
      INTEGER        :: Kmax(3), n_rep_real(3)
      INTEGER, DIMENSION(:), POINTER :: mm_atom_index
      TYPE(pw_pool_type), POINTER :: pw_pool
      TYPE(pw_grid_type), POINTER :: pw_grid
      TYPE(pw_type), POINTER :: TabLR
   END TYPE qmmm_per_pot_type

   TYPE qmmm_per_pot_p_type
      TYPE(qmmm_per_pot_type), POINTER :: pot
   END TYPE qmmm_per_pot_p_type

! **************************************************************************************************
!> \brief LINKs IMOMM
! **************************************************************************************************
   TYPE qmmm_imomm_link_type
      INTEGER  :: qm_index, mm_index
      REAL(KIND=dp) :: alpha
   END TYPE qmmm_imomm_link_type

   TYPE qmmm_imomm_link_p_type
      TYPE(qmmm_imomm_link_type), POINTER :: link
   END TYPE qmmm_imomm_link_p_type

! **************************************************************************************************
!> \brief LINKs PSEUDO
! **************************************************************************************************
   TYPE qmmm_pseudo_link_type
      INTEGER  :: qm_index, mm_index
   END TYPE qmmm_pseudo_link_type

   TYPE qmmm_pseudo_link_p_type
      TYPE(qmmm_pseudo_link_type), POINTER :: link
   END TYPE qmmm_pseudo_link_p_type

! **************************************************************************************************
!> \brief LINKs summary
! **************************************************************************************************
   TYPE qmmm_links_type
      TYPE(qmmm_imomm_link_p_type), DIMENSION(:), POINTER :: imomm
      TYPE(qmmm_pseudo_link_p_type), DIMENSION(:), POINTER :: pseudo
   END TYPE qmmm_links_type

! **************************************************************************************************
!> \brief ...
! **************************************************************************************************
   TYPE add_env_type
      INTEGER       :: Index1, Index2
      REAL(KIND=dp) :: alpha
   END TYPE add_env_type

! **************************************************************************************************
!> \brief ...
! **************************************************************************************************
   TYPE add_set_type
      INTEGER                                                 :: num_mm_atoms
      TYPE(add_env_type), DIMENSION(:), POINTER              :: add_env
      TYPE(particle_type), DIMENSION(:), POINTER              :: added_particles
      INTEGER, DIMENSION(:), POINTER                   :: mm_atom_index
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_atom_chrg
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_el_pot_radius
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_el_pot_radius_corr
      TYPE(qmmm_pot_p_type), DIMENSION(:), POINTER            :: Potentials
      TYPE(qmmm_per_pot_p_type), DIMENSION(:), POINTER        :: Per_Potentials
      TYPE(qmmm_gaussian_p_type), DIMENSION(:), POINTER        :: pgfs
   END TYPE add_set_type

! **************************************************************************************************
!> \brief parameters for core-shell model potentials
! **************************************************************************************************
   TYPE add_shell_type
      INTEGER                                                 :: num_mm_atoms
      TYPE(particle_type), DIMENSION(:), POINTER              :: added_particles
      TYPE(particle_type), DIMENSION(:), POINTER              :: added_cores
      INTEGER, DIMENSION(:), POINTER                   :: mm_core_index
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_core_chrg
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_el_pot_radius
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_el_pot_radius_corr
      TYPE(qmmm_pot_p_type), DIMENSION(:), POINTER            :: Potentials
      TYPE(qmmm_per_pot_p_type), DIMENSION(:), POINTER        :: Per_Potentials
      TYPE(qmmm_gaussian_p_type), DIMENSION(:), POINTER        :: pgfs
   END TYPE add_shell_type

! **************************************************************************************************
!> \brief ...
! **************************************************************************************************
   TYPE image_charge_type
      LOGICAL                                    :: all_mm
      LOGICAL                                    :: coeff_iterative
      LOGICAL                                    :: image_restart
      INTEGER                                    :: state_image_matrix
      INTEGER, DIMENSION(:), POINTER             :: image_mm_list
      TYPE(particle_type), DIMENSION(:), POINTER :: particles_all
      REAL(KIND=dp), DIMENSION(:, :), POINTER    :: image_forcesMM
      REAL(KIND=dp)                              :: V0
      REAL(KIND=dp)                              :: eta
      INTEGER                                    :: image_matrix_method
      TYPE(cp_eri_mme_param)                     :: eri_mme_param
   END TYPE image_charge_type

! **************************************************************************************************
!> \brief ...
! **************************************************************************************************
   TYPE qmmm_env_qm_type
      INTEGER :: ref_count, id_nr
      LOGICAL                                                 :: center_qm_subsys
      LOGICAL                                                 :: center_qm_subsys0, do_translate
      LOGICAL                                                 :: center_qm_subsys_pbc_aware
      LOGICAL                                                 :: do_force_mixing
      LOGICAL                                                 :: compatibility
      LOGICAL                                                 :: qmmm_link
      LOGICAL                                                 :: move_mm_charges
      LOGICAL                                                 :: add_mm_charges
      LOGICAL                                                 :: periodic
      LOGICAL                                                 :: multipole
      LOGICAL                                                 :: image_charge
      INTEGER                                                 :: par_scheme
      INTEGER                                                 :: qmmm_coupl_type
      INTEGER                                                 :: num_qm_atoms
      INTEGER                                                 :: num_mm_atoms
      INTEGER                                                 :: num_image_mm_atoms
      REAL(KIND=dp)                                           :: eps_mm_rspace
      REAL(KIND=dp), DIMENSION(3)                             :: dOmmOqm, utrasl, transl_v
      REAL(KIND=dp), DIMENSION(2)                             :: spherical_cutoff
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: maxradius
      INTEGER, DIMENSION(:), POINTER                    :: qm_atom_index
      INTEGER, DIMENSION(:), POINTER                    :: mm_atom_index
      INTEGER, DIMENSION(:), POINTER                    :: mm_link_atoms
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_atom_chrg
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_el_pot_radius
      REAL(KIND=dp), DIMENSION(:), POINTER                    :: mm_el_pot_radius_corr
      TYPE(qmmm_pot_p_type), DIMENSION(:), POINTER            :: Potentials
      TYPE(qmmm_per_pot_p_type), DIMENSION(:), POINTER        :: Per_Potentials
      TYPE(gridlevel_info_type)                               :: gridlevel_info
      TYPE(qmmm_gaussian_p_type), DIMENSION(:), POINTER        :: pgfs
      TYPE(pw_pool_p_type), DIMENSION(:), POINTER             :: aug_pools
      TYPE(qmmm_links_type), POINTER                          :: qmmm_links
      TYPE(add_set_type), POINTER                             :: added_charges
      TYPE(add_shell_type), POINTER                           :: added_shells
      TYPE(image_charge_type), POINTER                        :: image_charge_pot
      TYPE(ewald_environment_type), POINTER                   :: ewald_env
      TYPE(ewald_pw_type), POINTER                            :: ewald_pw
   END TYPE qmmm_env_qm_type

! **************************************************************************************************
!> \brief ...
! **************************************************************************************************
   TYPE qmmm_env_mm_type
      INTEGER :: ref_count, id_nr
      LOGICAL                                                 :: qmmm_link
      LOGICAL                                                 :: use_qmmm_ff
      LOGICAL                                                 :: multiple_potential
      INTEGER                                                 :: qmmm_coupl_type
      INTEGER, DIMENSION(:), POINTER                   :: qm_atom_index
      INTEGER, DIMENSION(:), POINTER                   :: mm_link_atoms
      REAL(KIND=dp), DIMENSION(:), POINTER                   :: mm_link_scale_factor
      REAL(KIND=dp), DIMENSION(:), POINTER                   :: fist_scale_charge_link
      INTEGER, DIMENSION(:), POINTER                   :: qm_molecule_index
      TYPE(input_info_type), POINTER                           :: inp_info
   END TYPE qmmm_env_mm_type

CONTAINS

! **************************************************************************************************
!> \brief ...
!> \param qmmm_env ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE qmmm_env_mm_create(qmmm_env)
      TYPE(qmmm_env_mm_type), POINTER                    :: qmmm_env

      CPASSERT(.NOT. ASSOCIATED(qmmm_env))
      ALLOCATE (qmmm_env)
      qmmm_env%ref_count = 1
      last_qmmm_env_id_nr = last_qmmm_env_id_nr + 1
      qmmm_env%id_nr = last_qmmm_env_id_nr
      NULLIFY (qmmm_env%qm_atom_index, &
               qmmm_env%qm_molecule_index, &
               qmmm_env%mm_link_atoms, &
               qmmm_env%mm_link_scale_factor, &
               qmmm_env%fist_scale_charge_link, &
               qmmm_env%inp_info)
      qmmm_env%qmmm_coupl_type = do_qmmm_none
      qmmm_env%qmmm_link = .FALSE.
      qmmm_env%use_qmmm_ff = .FALSE.
      ALLOCATE (qmmm_env%inp_info)
      CALL init_inp_info(qmmm_env%inp_info)
   END SUBROUTINE qmmm_env_mm_create

! **************************************************************************************************
!> \brief ...
!> \param qmmm_env ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE qmmm_env_mm_retain(qmmm_env)
      TYPE(qmmm_env_mm_type), POINTER                    :: qmmm_env

      CPASSERT(ASSOCIATED(qmmm_env))
      CPASSERT(qmmm_env%ref_count > 0)
      qmmm_env%ref_count = qmmm_env%ref_count + 1
   END SUBROUTINE qmmm_env_mm_retain

! **************************************************************************************************
!> \brief releases the given qmmm_env (see doc/ReferenceCounting.html)
!> \param qmmm_env the object to release
!> \author Fawzi Mohamed
!>      Teodoro Laino
! **************************************************************************************************
   SUBROUTINE qmmm_env_mm_release(qmmm_env)
      TYPE(qmmm_env_mm_type), POINTER                    :: qmmm_env

      IF (ASSOCIATED(qmmm_env)) THEN
         CPASSERT(qmmm_env%ref_count > 0)
         qmmm_env%ref_count = qmmm_env%ref_count - 1
         IF (qmmm_env%ref_count == 0) THEN
            IF (ASSOCIATED(qmmm_env%qm_atom_index)) THEN
               DEALLOCATE (qmmm_env%qm_atom_index)
            END IF
            IF (ASSOCIATED(qmmm_env%qm_molecule_index)) THEN
               DEALLOCATE (qmmm_env%qm_molecule_index)
            END IF
            IF (ASSOCIATED(qmmm_env%mm_link_atoms)) THEN
               DEALLOCATE (qmmm_env%mm_link_atoms)
            END IF
            IF (ASSOCIATED(qmmm_env%mm_link_scale_factor)) THEN
               DEALLOCATE (qmmm_env%mm_link_scale_factor)
            END IF
            IF (ASSOCIATED(qmmm_env%fist_scale_charge_link)) THEN
               DEALLOCATE (qmmm_env%fist_scale_charge_link)
            END IF
            IF (ASSOCIATED(qmmm_env%inp_info)) THEN
               CALL deallocate_inp_info(qmmm_env%inp_info)
               DEALLOCATE (qmmm_env%inp_info)
            END IF

            DEALLOCATE (qmmm_env)
         END IF
      END IF
      NULLIFY (qmmm_env)
   END SUBROUTINE qmmm_env_mm_release

! **************************************************************************************************
!> \brief ...
!> \param qmmm_env ...
!> \author Fawzi Mohamed
! **************************************************************************************************
   SUBROUTINE qmmm_env_qm_create(qmmm_env)
      TYPE(qmmm_env_qm_type), POINTER                    :: qmmm_env

      CPASSERT(.NOT. ASSOCIATED(qmmm_env))
      ALLOCATE (qmmm_env)
      qmmm_env%ref_count = 1
      last_qmmm_env_id_nr = last_qmmm_env_id_nr + 1
      qmmm_env%id_nr = last_qmmm_env_id_nr
      NULLIFY (qmmm_env%qm_atom_index, qmmm_env%mm_link_atoms, &
               qmmm_env%mm_atom_index, qmmm_env%mm_atom_chrg, &
               qmmm_env%pgfs, qmmm_env%maxradius, &
               qmmm_env%aug_pools, qmmm_env%potentials, &
               qmmm_env%qmmm_links, qmmm_env%added_charges, &
               qmmm_env%per_potentials, qmmm_env%image_charge_pot, &
               qmmm_env%added_shells)
      NULLIFY (qmmm_env%ewald_env, qmmm_env%ewald_pw)
      qmmm_env%do_translate = .TRUE.
      qmmm_env%center_qm_subsys = .TRUE.
      qmmm_env%center_qm_subsys0 = .TRUE.
      qmmm_env%center_qm_subsys_pbc_aware = .FALSE.
      qmmm_env%do_force_mixing = .FALSE.
      qmmm_env%compatibility = .TRUE.
      qmmm_env%qmmm_link = .FALSE.
      qmmm_env%add_mm_charges = .FALSE.
      qmmm_env%move_mm_charges = .FALSE.
      qmmm_env%periodic = .FALSE.
      qmmm_env%multipole = .FALSE.
      qmmm_env%image_charge = .FALSE.
      qmmm_env%qmmm_coupl_type = do_qmmm_none
      qmmm_env%num_qm_atoms = 0
      qmmm_env%num_mm_atoms = 0
      qmmm_env%num_image_mm_atoms = 0
      qmmm_env%gridlevel_info%auxbas_grid = 0
      qmmm_env%gridlevel_info%coarser_grid = 0
      CALL create_add_set_type(qmmm_env%added_charges, ndim=0)
      !CALL create_add_shell_type(qmmm_env%added_shells, ndim=0)
      CALL create_image_charge_type(qmmm_env%image_charge_pot)
   END SUBROUTINE qmmm_env_qm_create

! **************************************************************************************************
!> \brief releases the given qmmm_env (see doc/ReferenceCounting.html)
!> \param qmmm_env the object to release
!> \author Fawzi Mohamed
!>      Teodoro Laino
! **************************************************************************************************
   SUBROUTINE qmmm_env_qm_release(qmmm_env)
      TYPE(qmmm_env_qm_type), POINTER                    :: qmmm_env

      IF (ASSOCIATED(qmmm_env)) THEN
         CPASSERT(qmmm_env%ref_count > 0)
         qmmm_env%ref_count = qmmm_env%ref_count - 1
         IF (qmmm_env%ref_count == 0) THEN
            IF (ASSOCIATED(qmmm_env%qm_atom_index)) THEN
               DEALLOCATE (qmmm_env%qm_atom_index)
            END IF
            IF (ASSOCIATED(qmmm_env%maxradius)) THEN
               DEALLOCATE (qmmm_env%maxradius)
            END IF
            IF (ASSOCIATED(qmmm_env%mm_atom_index)) THEN
               DEALLOCATE (qmmm_env%mm_atom_index)
            END IF
            IF (ASSOCIATED(qmmm_env%mm_link_atoms)) THEN
               DEALLOCATE (qmmm_env%mm_link_atoms)
            END IF
            IF (ASSOCIATED(qmmm_env%mm_atom_chrg)) THEN
               DEALLOCATE (qmmm_env%mm_atom_chrg)
            END IF
            IF (ASSOCIATED(qmmm_env%mm_el_pot_radius)) THEN
               DEALLOCATE (qmmm_env%mm_el_pot_radius)
            END IF
            IF (ASSOCIATED(qmmm_env%mm_el_pot_radius_corr)) THEN
               DEALLOCATE (qmmm_env%mm_el_pot_radius_corr)
            END IF
            IF (ASSOCIATED(qmmm_env%pgfs)) THEN
               CALL pgfs_release(qmmm_env%pgfs)
               DEALLOCATE (qmmm_env%pgfs)
            END IF
            IF (ASSOCIATED(qmmm_env%Potentials)) THEN
               CALL qmmm_pot_type_dealloc(qmmm_env%Potentials)
               DEALLOCATE (qmmm_env%Potentials)
            END IF
            IF (ASSOCIATED(qmmm_env%Per_Potentials)) THEN
               CALL qmmm_per_pot_type_dealloc(qmmm_env%Per_Potentials)
               DEALLOCATE (qmmm_env%Per_Potentials)
            END IF
            IF (ASSOCIATED(qmmm_env%aug_pools)) THEN
               CALL pw_pools_dealloc(qmmm_env%aug_pools)
            END IF
            IF (ASSOCIATED(qmmm_env%qmmm_links)) THEN
               CALL qmmm_links_dealloc(qmmm_env%qmmm_links)
            END IF
            IF (ASSOCIATED(qmmm_env%added_charges)) THEN
               CALL add_set_release(qmmm_env%added_charges)
            END IF
            IF (ASSOCIATED(qmmm_env%added_shells)) THEN
               CALL add_shell_release(qmmm_env%added_shells)
            END IF
            IF (ASSOCIATED(qmmm_env%image_charge_pot)) THEN
               IF (qmmm_env%image_charge) THEN
                  IF (qmmm_env%image_charge_pot%image_matrix_method .EQ. do_eri_mme) THEN
                     CALL cp_eri_mme_finalize(qmmm_env%image_charge_pot%eri_mme_param)
                  END IF
               END IF
               CALL qmmm_image_charge_dealloc(qmmm_env%image_charge_pot)
            END IF
            IF (ASSOCIATED(qmmm_env%ewald_env)) THEN
               CALL ewald_env_release(qmmm_env%ewald_env)
            END IF
            IF (ASSOCIATED(qmmm_env%ewald_pw)) THEN
               CALL ewald_pw_release(qmmm_env%ewald_pw)
            END IF
            DEALLOCATE (qmmm_env)
         END IF
      END IF
      NULLIFY (qmmm_env)
   END SUBROUTINE qmmm_env_qm_release

! **************************************************************************************************
!> \brief deallocates the pgfs type
!> \param pgfs ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE pgfs_release(pgfs)
      TYPE(qmmm_gaussian_p_type), DIMENSION(:), POINTER  :: pgfs

      INTEGER                                            :: I

      DO I = 1, SIZE(pgfs)
         IF (ASSOCIATED(pgfs(I)%pgf)) THEN
            IF (ASSOCIATED(pgfs(I)%pgf%Ak)) THEN
               DEALLOCATE (pgfs(I)%pgf%Ak)
            END IF
            IF (ASSOCIATED(pgfs(I)%pgf%Gk)) THEN
               DEALLOCATE (pgfs(I)%pgf%Gk)
            END IF
            IF (ASSOCIATED(pgfs(I)%pgf%grid_level)) THEN
               DEALLOCATE (pgfs(I)%pgf%grid_level)
            END IF
            DEALLOCATE (pgfs(I)%pgf)
         END IF
      END DO
   END SUBROUTINE pgfs_release

! **************************************************************************************************
!> \brief deallocates the qmmm_links structure
!> \param qmmm_links ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE qmmm_links_dealloc(qmmm_links)
      TYPE(qmmm_links_type), POINTER                     :: qmmm_links

      INTEGER                                            :: I

      IF (ASSOCIATED(qmmm_links%imomm)) THEN
         DO i = 1, SIZE(qmmm_links%imomm)
            IF (ASSOCIATED(qmmm_links%imomm(i)%link)) DEALLOCATE (qmmm_links%imomm(i)%link)
         END DO
         DEALLOCATE (qmmm_links%imomm)
      END IF
      IF (ASSOCIATED(qmmm_links%pseudo)) THEN
         DO i = 1, SIZE(qmmm_links%pseudo)
            IF (ASSOCIATED(qmmm_links%pseudo(i)%link)) DEALLOCATE (qmmm_links%pseudo(i)%link)
         END DO
         DEALLOCATE (qmmm_links%pseudo)
      END IF
      DEALLOCATE (qmmm_links)
   END SUBROUTINE qmmm_links_dealloc

! ****************************************************************************
!> \brief deallocates the image_charge_pot structure
!> \param image_charge_pot ...
!> \author Dorothea Golze
! **************************************************************************************************
   SUBROUTINE qmmm_image_charge_dealloc(image_charge_pot)
      TYPE(image_charge_type), POINTER                   :: image_charge_pot

      IF (ASSOCIATED(image_charge_pot)) THEN
         IF (ASSOCIATED(image_charge_pot%image_mm_list)) THEN
            IF (.NOT. image_charge_pot%all_mm) THEN
               DEALLOCATE (image_charge_pot%image_mm_list)
            END IF
         END IF
         IF (ASSOCIATED(image_charge_pot%image_forcesMM)) THEN
            DEALLOCATE (image_charge_pot%image_forcesMM)
         END IF
         DEALLOCATE (image_charge_pot)
      END IF
   END SUBROUTINE qmmm_image_charge_dealloc

! **************************************************************************************************
!> \brief deallocates the qmmm_pot_type structure
!> \param Potentials ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE qmmm_pot_type_dealloc(Potentials)
      TYPE(qmmm_pot_p_type), DIMENSION(:), POINTER       :: Potentials

      INTEGER                                            :: I

      DO I = 1, SIZE(Potentials)
         IF (ASSOCIATED(Potentials(I)%Pot)) THEN
            IF (ASSOCIATED(Potentials(I)%Pot%pot0_2)) THEN
               DEALLOCATE (Potentials(I)%Pot%pot0_2)
            END IF
            IF (ASSOCIATED(Potentials(I)%Pot%mm_atom_index)) THEN
               DEALLOCATE (Potentials(I)%Pot%mm_atom_index)
            END IF
            DEALLOCATE (Potentials(I)%Pot)
         END IF
      END DO

   END SUBROUTINE qmmm_pot_type_dealloc

! **************************************************************************************************
!> \brief deallocates the qmmm_per_pot_type structure
!>      for QM/MM periodic boundary conditions
!> \param Per_Potentials ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE qmmm_per_pot_type_dealloc(Per_Potentials)
      TYPE(qmmm_per_pot_p_type), DIMENSION(:), POINTER   :: Per_Potentials

      INTEGER                                            :: I

      DO I = 1, SIZE(Per_Potentials)
         IF (ASSOCIATED(Per_Potentials(I)%Pot)) THEN
            IF (ASSOCIATED(Per_Potentials(I)%Pot%LG)) THEN
               DEALLOCATE (Per_Potentials(I)%Pot%LG)
            END IF
            IF (ASSOCIATED(Per_Potentials(I)%Pot%gx)) THEN
               DEALLOCATE (Per_Potentials(I)%Pot%gx)
            END IF
            IF (ASSOCIATED(Per_Potentials(I)%Pot%gy)) THEN
               DEALLOCATE (Per_Potentials(I)%Pot%gy)
            END IF
            IF (ASSOCIATED(Per_Potentials(I)%Pot%gz)) THEN
               DEALLOCATE (Per_Potentials(I)%Pot%gz)
            END IF
            IF (ASSOCIATED(Per_Potentials(I)%Pot%mm_atom_index)) THEN
               DEALLOCATE (Per_Potentials(I)%Pot%mm_atom_index)
            END IF
            IF (ASSOCIATED(Per_Potentials(I)%Pot%TabLR)) THEN
               CALL pw_pool_give_back_pw(Per_Potentials(I)%Pot%pw_pool, Per_Potentials(I)%Pot%TabLR)
            END IF
            IF (ASSOCIATED(Per_Potentials(I)%Pot%pw_pool)) THEN
               CALL pw_pool_release(Per_Potentials(I)%Pot%pw_pool)
               CPASSERT(.NOT. ASSOCIATED(Per_Potentials(I)%Pot%pw_pool))
            END IF
            IF (ASSOCIATED(Per_Potentials(I)%Pot%pw_grid)) THEN
               CALL pw_grid_release(Per_Potentials(I)%Pot%pw_grid)
               CPASSERT(.NOT. ASSOCIATED(Per_Potentials(I)%Pot%pw_grid))
            END IF
            DEALLOCATE (Per_Potentials(I)%Pot)
         END IF
      END DO

   END SUBROUTINE qmmm_per_pot_type_dealloc

! **************************************************************************************************
!> \brief deallocates the add_set_release
!> \param added_charges ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE add_set_release(added_charges)
      TYPE(add_set_type), POINTER                        :: added_charges

      IF (ASSOCIATED(added_charges)) THEN
         IF (ASSOCIATED(added_charges%add_env)) THEN
            DEALLOCATE (added_charges%add_env)
         END IF
         IF (ASSOCIATED(added_charges%added_particles)) THEN
            CALL deallocate_particle_set(added_charges%added_particles)
         END IF
         IF (ASSOCIATED(added_charges%mm_atom_index)) THEN
            DEALLOCATE (added_charges%mm_atom_index)
         END IF
         IF (ASSOCIATED(added_charges%mm_atom_chrg)) THEN
            DEALLOCATE (added_charges%mm_atom_chrg)
         END IF
         IF (ASSOCIATED(added_charges%mm_el_pot_radius)) THEN
            DEALLOCATE (added_charges%mm_el_pot_radius)
         END IF
         IF (ASSOCIATED(added_charges%mm_el_pot_radius_corr)) THEN
            DEALLOCATE (added_charges%mm_el_pot_radius_corr)
         END IF
         IF (ASSOCIATED(added_charges%Potentials)) THEN
            CALL qmmm_pot_type_dealloc(added_charges%Potentials)
            DEALLOCATE (added_charges%Potentials)
         END IF
         IF (ASSOCIATED(added_charges%Per_Potentials)) THEN
            CALL qmmm_per_pot_type_dealloc(added_charges%Per_Potentials)
            DEALLOCATE (added_charges%Per_Potentials)
         END IF
         IF (ASSOCIATED(added_charges%pgfs)) THEN
            CALL pgfs_release(added_charges%pgfs)
            DEALLOCATE (added_charges%pgfs)
         END IF
         DEALLOCATE (added_charges)
      END IF
   END SUBROUTINE add_set_release

! **************************************************************************************************
!> \brief deallocates the add_shell_release
!> \param added_shells ...
!> \author MattW
! **************************************************************************************************
   SUBROUTINE add_shell_release(added_shells)

      TYPE(add_shell_type), POINTER                      :: added_shells

      IF (ASSOCIATED(added_shells)) THEN
         IF (ASSOCIATED(added_shells%added_particles)) THEN
            !XXXFIST should clean up shell particles
            NULLIFY (added_shells%added_particles)
            NULLIFY (added_shells%added_cores)
            !CALL deallocate_particle_set(added_shells%added_particles)
         END IF
         IF (ASSOCIATED(added_shells%mm_core_index)) THEN
            DEALLOCATE (added_shells%mm_core_index)
         END IF
         IF (ASSOCIATED(added_shells%mm_core_chrg)) THEN
            DEALLOCATE (added_shells%mm_core_chrg)
         END IF
         IF (ASSOCIATED(added_shells%mm_el_pot_radius)) THEN
            DEALLOCATE (added_shells%mm_el_pot_radius)
         END IF
         IF (ASSOCIATED(added_shells%mm_el_pot_radius_corr)) THEN
            DEALLOCATE (added_shells%mm_el_pot_radius_corr)
         END IF
         IF (ASSOCIATED(added_shells%Potentials)) THEN
            CALL qmmm_pot_type_dealloc(added_shells%Potentials)
            DEALLOCATE (added_shells%Potentials)
         END IF
         IF (ASSOCIATED(added_shells%Per_Potentials)) THEN
            CALL qmmm_per_pot_type_dealloc(added_shells%Per_Potentials)
            DEALLOCATE (added_shells%Per_Potentials)
         END IF
         IF (ASSOCIATED(added_shells%pgfs)) THEN
            CALL pgfs_release(added_shells%pgfs)
            DEALLOCATE (added_shells%pgfs)
         END IF
         DEALLOCATE (added_shells)
      END IF

   END SUBROUTINE add_shell_release

! **************************************************************************************************
!> \brief creates the add_set_type structure
!> \param added_charges ...
!> \param ndim ...
!> \author Teodoro Laino
! **************************************************************************************************
   SUBROUTINE create_add_set_type(added_charges, ndim)
      TYPE(add_set_type), POINTER                        :: added_charges
      INTEGER, INTENT(IN)                                :: ndim

      IF (ASSOCIATED(added_charges)) CALL add_set_release(added_charges)
      ALLOCATE (added_charges)

      NULLIFY (added_charges%add_env, &
               added_charges%mm_atom_index, &
               added_charges%added_particles, &
               added_charges%mm_atom_chrg, &
               added_charges%mm_el_pot_radius, &
               added_charges%mm_el_pot_radius_corr, &
               added_charges%potentials, &
               added_charges%per_potentials, &
               added_charges%pgfs)

      added_charges%num_mm_atoms = ndim
      IF (ndim == 0) RETURN
      !
      ! Allocate leave out just potential and pgfs...
      !
      ALLOCATE (added_charges%add_env(ndim))
      CALL allocate_particle_set(added_charges%added_particles, ndim)
      ALLOCATE (added_charges%mm_atom_index(ndim))
      ALLOCATE (added_charges%mm_atom_chrg(ndim))
      ALLOCATE (added_charges%mm_el_pot_radius(ndim))
      ALLOCATE (added_charges%mm_el_pot_radius_corr(ndim))
   END SUBROUTINE create_add_set_type

! **************************************************************************************************
!> \brief creates the add_shell_type structure
!> \param added_shells ...
!> \param ndim ...
!> \author Teodoro Laino
! **************************************************************************************************

   SUBROUTINE create_add_shell_type(added_shells, ndim)
      TYPE(add_shell_type), POINTER                      :: added_shells
      INTEGER, INTENT(IN)                                :: ndim

      IF (ASSOCIATED(added_shells)) CALL add_shell_release(added_shells)
      ALLOCATE (added_shells)

      NULLIFY (added_shells%mm_core_index, &
               added_shells%added_particles, &
               added_shells%added_cores, &
               added_shells%mm_core_chrg, &
               added_shells%mm_el_pot_radius, &
               added_shells%mm_el_pot_radius_corr, &
               added_shells%potentials, &
               added_shells%per_potentials, &
               added_shells%pgfs)

      added_shells%num_mm_atoms = ndim
      IF (ndim == 0) RETURN
      !
      ! Allocate leave out just potential and pgfs...
      !
      ALLOCATE (added_shells%mm_core_index(ndim))
      ALLOCATE (added_shells%mm_core_chrg(ndim))
      ALLOCATE (added_shells%mm_el_pot_radius(ndim))
      ALLOCATE (added_shells%mm_el_pot_radius_corr(ndim))

   END SUBROUTINE create_add_shell_type

! **************************************************************************************************
!> \brief creates the image_charge_type structure
!> \param image_charge_pot ...
!> \author Dorothea Golze
! **************************************************************************************************
   SUBROUTINE create_image_charge_type(image_charge_pot)
      TYPE(image_charge_type), POINTER                   :: image_charge_pot

      IF (ASSOCIATED(image_charge_pot)) CALL qmmm_image_charge_dealloc(image_charge_pot)
      ALLOCATE (image_charge_pot)

      NULLIFY (image_charge_pot%image_mm_list, &
               image_charge_pot%particles_all, &
               image_charge_pot%image_forcesMM)

      image_charge_pot%all_mm = .TRUE.
      image_charge_pot%coeff_iterative = .FALSE.
      image_charge_pot%image_restart = .FALSE.

   END SUBROUTINE create_image_charge_type

END MODULE qmmm_types_low
