!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2022 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Performs density functional perturbation theory (tddfpt) calculations.
!>      Uses the self consistent approach. The tddfpt calculation uses the ground
!>      state of the unperturbed system as the initial state.
! **************************************************************************************************
MODULE qs_tddfpt_module
   USE bibliography,                    ONLY: Iannuzzi2005,&
                                              cite_reference
   USE cp_log_handling,                 ONLY: cp_get_default_logger,&
                                              cp_logger_get_default_io_unit,&
                                              cp_logger_type
   USE cp_output_handling,              ONLY: cp_print_key_finished_output,&
                                              cp_print_key_unit_nr
   USE dbcsr_api,                       ONLY: dbcsr_p_type
   USE header,                          ONLY: tddfpt_header
   USE input_constants,                 ONLY: oe_gllb,&
                                              oe_lb,&
                                              oe_none,&
                                              oe_saop,&
                                              oe_sic,&
                                              tddfpt_excitations
   USE input_section_types,             ONLY: section_get_ival,&
                                              section_vals_create,&
                                              section_vals_get_subs_vals,&
                                              section_vals_release,&
                                              section_vals_retain,&
                                              section_vals_set_subs_vals,&
                                              section_vals_type,&
                                              section_vals_val_get
   USE qs_energy_types,                 ONLY: qs_energy_type
   USE qs_environment_types,            ONLY: get_qs_env,&
                                              qs_environment_type
   USE qs_ks_methods,                   ONLY: qs_ks_build_kohn_sham_matrix
   USE qs_ks_types,                     ONLY: qs_ks_env_type,&
                                              set_ks_env
   USE qs_p_env_types,                  ONLY: qs_p_env_type
   USE qs_rho_types,                    ONLY: qs_rho_type
   USE qs_scf_types,                    ONLY: qs_scf_env_type
   USE qs_tddfpt_eigensolver,           ONLY: eigensolver
   USE qs_tddfpt_types,                 ONLY: tddfpt_env_type
   USE qs_tddfpt_utils,                 ONLY: find_contributions,&
                                              tddfpt_cleanup,&
                                              tddfpt_init
   USE xc_pot_saop,                     ONLY: add_saop_pot
#include "./base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE
   PUBLIC :: tddfpt_calculation

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'qs_tddfpt_module'

CONTAINS

! **************************************************************************************************
!> \brief Performs the perturbation calculation
!> \param qs_env ...
! **************************************************************************************************
   SUBROUTINE tddfpt_calculation(qs_env)

      TYPE(qs_environment_type), POINTER                 :: qs_env

      CHARACTER(LEN=*), PARAMETER :: routineN = 'tddfpt_calculation'

      INTEGER                                            :: handle, iw
      TYPE(cp_logger_type), POINTER                      :: logger
      TYPE(qs_ks_env_type), POINTER                      :: ks_env
      TYPE(qs_p_env_type)                                :: p_env
      TYPE(section_vals_type), POINTER                   :: dft_section, input
      TYPE(tddfpt_env_type)                              :: t_env

      NULLIFY (logger)
      logger => cp_get_default_logger()
      NULLIFY (input, ks_env)
      CALL get_qs_env(qs_env, ks_env=ks_env, input=input)
      dft_section => section_vals_get_subs_vals(input, "DFT")

      IF (section_get_ival(dft_section, "EXCITATIONS") /= tddfpt_excitations) RETURN
      CALL cite_reference(Iannuzzi2005)

      CALL timeset(routineN, handle)

      IF (section_get_ival(dft_section, "TDDFPT%OE_CORR") /= oe_none) THEN
         CALL orbital_eigenvalue_correction(qs_env)
      END IF

      iw = cp_print_key_unit_nr(logger, dft_section, "PRINT%PROGRAM_BANNER", &
                                extension=".Log")
      CALL tddfpt_header(iw)
      CALL cp_print_key_finished_output(iw, logger, dft_section, &
                                        "PRINT%PROGRAM_BANNER")

      !---------------------------------------!
      ! we don't want to update the KS matrix !
      !---------------------------------------!
      CALL set_ks_env(ks_env, rho_changed=.FALSE.)

      CALL tddfpt_init(p_env, t_env, qs_env)

      CALL eigensolver(p_env, qs_env, t_env)

      CALL find_contributions(qs_env, t_env)

      CALL tddfpt_cleanup(t_env, p_env)

      CALL timestop(handle)

   END SUBROUTINE tddfpt_calculation

! **************************************************************************************************
!> \brief Apply a special potential to obtain better
!>       orbital eigenvalues.
!> \param qs_env ...
! **************************************************************************************************
   SUBROUTINE orbital_eigenvalue_correction(qs_env)

      TYPE(qs_environment_type), POINTER                 :: qs_env

      INTEGER                                            :: oe_corr, output_unit
      TYPE(cp_logger_type), POINTER                      :: logger
      TYPE(dbcsr_p_type), DIMENSION(:), POINTER          :: matrix_ks
      TYPE(qs_energy_type), POINTER                      :: energy
      TYPE(qs_rho_type), POINTER                         :: rho
      TYPE(qs_scf_env_type), POINTER                     :: scf_env
      TYPE(section_vals_type), POINTER                   :: input, xc_fun_orig, xc_fun_tmp

      CPASSERT(ASSOCIATED(qs_env))

      NULLIFY (logger, scf_env, input, energy, matrix_ks, rho)
      logger => cp_get_default_logger()
      output_unit = cp_logger_get_default_io_unit(logger)

      IF (output_unit > 0) THEN
         WRITE (output_unit, "(2X,A)") "", &
            "-----------------------------------------------------------------------------", &
            "-                    orbital eigenvalue correction started                  -", &
            "-----------------------------------------------------------------------------", &
            ""
      END IF

      CALL get_qs_env(qs_env, &
                      scf_env=scf_env, &
                      input=input, &
                      matrix_ks=matrix_ks, &
                      rho=rho)

      !----------------------!
      ! KS matrix without XC !
      !----------------------!
      xc_fun_orig => section_vals_get_subs_vals(input, "DFT%XC%XC_FUNCTIONAL")
      CALL section_vals_retain(xc_fun_orig)
      NULLIFY (xc_fun_tmp)
      CALL section_vals_create(xc_fun_tmp, xc_fun_orig%section)
      CALL section_vals_set_subs_vals(input, "DFT%XC%XC_FUNCTIONAL", xc_fun_tmp)
      CALL section_vals_release(xc_fun_tmp)

      CALL get_qs_env(qs_env, energy=energy)
      CALL qs_ks_build_kohn_sham_matrix(qs_env, calculate_forces=.FALSE., &
                                        just_energy=.FALSE.)

      CALL section_vals_set_subs_vals(input, "DFT%XC%XC_FUNCTIONAL", xc_fun_orig)
      CALL section_vals_release(xc_fun_orig)

      CALL section_vals_val_get(input, "DFT%TDDFPT%OE_CORR", i_val=oe_corr)
      IF (oe_corr == oe_saop .OR. &
          oe_corr == oe_lb .OR. &
          oe_corr == oe_gllb) THEN
         CALL add_saop_pot(matrix_ks, qs_env, oe_corr)
      ELSE IF (oe_corr == oe_sic) THEN
      END IF

   END SUBROUTINE orbital_eigenvalue_correction

END MODULE qs_tddfpt_module
