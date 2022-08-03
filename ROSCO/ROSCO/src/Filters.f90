! Copyright 2019 NREL

! Licensed under the Apache License, Version 2.0 (the "License"); you may not use
! this file except in compliance with the License. You may obtain a copy of the
! License at http://www.apache.org/licenses/LICENSE-2.0

! Unless required by applicable law or agreed to in writing, software distributed
! under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
! CONDITIONS OF ANY KIND, either express or implied. See the License for the
! specific language governing permissions and limitations under the License.
! -------------------------------------------------------------------------------------------
! This module contains all the filters and related subroutines

! Filters:
!       LPFilter: Low-pass filter
!       SecLPFilter: Second order low-pass filter
!       HPFilter: High-pass filter
!       NotchFilter: Notch filter
!       NotchFilterSlopes: Notch Filter with descending slopes
!       PreFilterMeasuredSignals: Pre-filter signals during each run iteration

MODULE Filters
!...............................................................................................................................
    USE Constants
    IMPLICIT NONE

CONTAINS
!-------------------------------------------------------------------------------------------------------------------------------
    REAL FUNCTION LPFilter(InputSignal, DT, CornerFreq, iStatus, reset, inst)
    ! Discrete time Low-Pass Filter of the form:
    !                               Continuous Time Form:   H(s) = CornerFreq/(1 + CornerFreq)
    !                               Discrete Time Form:     H(z) = (b1z + b0) / (a1*z + a0)
    !
        REAL(DbKi), INTENT(IN)         :: InputSignal
        REAL(DbKi), INTENT(IN)         :: DT                       ! time step [s]
        REAL(DbKi), INTENT(IN)         :: CornerFreq               ! corner frequency [rad/s]
        INTEGER(IntKi), INTENT(IN)     :: iStatus                  ! A status flag set by the simulation as follows: 0 if this is the first call, 1 for all subsequent time steps, -1 if this is the final call at the end of the simulation.
        INTEGER(IntKi), INTENT(INOUT)  :: inst                     ! Instance number. Every instance of this function needs to have an unique instance number to ensure instances don't influence each other.
        LOGICAL(4), INTENT(IN)         :: reset                    ! Reset the filter to the input signal

            ! Local
        REAL(DbKi), DIMENSION(99), SAVE    :: a1                   ! Denominator coefficient 1
        REAL(DbKi), DIMENSION(99), SAVE    :: a0                   ! Denominator coefficient 0
        REAL(DbKi), DIMENSION(99), SAVE    :: b1                    ! Numerator coefficient 1
        REAL(DbKi), DIMENSION(99), SAVE    :: b0                    ! Numerator coefficient 0 

        REAL(DbKi), DIMENSION(99), SAVE    :: InputSignalLast      ! Input signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: OutputSignalLast ! Output signal the last time this filter was called. Supports 99 separate instances.

            ! Initialization
        IF ((iStatus == 0) .OR. reset) THEN   
            OutputSignalLast(inst) = InputSignal
            InputSignalLast(inst) = InputSignal
            a1(inst) = 2 + CornerFreq*DT
            a0(inst) = CornerFreq*DT - 2
            b1(inst) = CornerFreq*DT
            b0(inst) = CornerFreq*DT
        ENDIF

        ! Define coefficients

        ! Filter
        LPFilter = 1.0/a1(inst) * (-a0(inst)*OutputSignalLast(inst) & 
                                    + b1(inst)*InputSignal + b0(inst)*InputSignalLast(inst))

        ! Save signals for next time step
        InputSignalLast(inst)  = InputSignal
        OutputSignalLast(inst) = LPFilter
        inst = inst + 1

    END FUNCTION LPFilter
!-------------------------------------------------------------------------------------------------------------------------------
    REAL(DbKi) FUNCTION SecLPFilter(InputSignal, DT, CornerFreq, Damp, iStatus, reset, inst)
    ! Discrete time Low-Pass Filter of the form:
    !                               Continuous Time Form:   H(s) = CornerFreq^2/(s^2 + 2*CornerFreq*Damp*s + CornerFreq^2)
    !                               Discrete Time From:     H(z) = (b2*z^2 + b1*z + b0) / (a2*z^2 + a1*z + a0)
        REAL(DbKi), INTENT(IN)         :: InputSignal
        REAL(DbKi), INTENT(IN)         :: DT                       ! time step [s]
        REAL(DbKi), INTENT(IN)         :: CornerFreq               ! corner frequency [rad/s]
        REAL(DbKi), INTENT(IN)         :: Damp                     ! Dampening constant
        INTEGER(IntKi), INTENT(IN)      :: iStatus                  ! A status flag set by the simulation as follows: 0 if this is the first call, 1 for all subsequent time steps, -1 if this is the final call at the end of the simulation.
        INTEGER(IntKi), INTENT(INOUT)   :: inst                     ! Instance number. Every instance of this function needs to have an unique instance number to ensure instances don't influence each other.
        LOGICAL(4), INTENT(IN)      :: reset                    ! Reset the filter to the input signal

        ! Local
        REAL(DbKi), DIMENSION(99), SAVE    :: a2                   ! Denominator coefficient 2
        REAL(DbKi), DIMENSION(99), SAVE    :: a1                   ! Denominator coefficient 1
        REAL(DbKi), DIMENSION(99), SAVE    :: a0                   ! Denominator coefficient 0
        REAL(DbKi), DIMENSION(99), SAVE    :: b2                   ! Numerator coefficient 2
        REAL(DbKi), DIMENSION(99), SAVE    :: b1                   ! Numerator coefficient 1
        REAL(DbKi), DIMENSION(99), SAVE    :: b0                   ! Numerator coefficient 0 
        REAL(DbKi), DIMENSION(99), SAVE    :: InputSignalLast1     ! Input signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: InputSignalLast2     ! Input signal the next to last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: OutputSignalLast1    ! Output signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: OutputSignalLast2    ! Output signal the next to last time this filter was called. Supports 99 separate instances.

        ! Initialization
        IF ((iStatus == 0) .OR. reset )  THEN
            OutputSignalLast1(inst)  = InputSignal
            OutputSignalLast2(inst)  = InputSignal
            InputSignalLast1(inst)   = InputSignal
            InputSignalLast2(inst)   = InputSignal
            
            ! Coefficients
            a2(inst) = DT**2.0*CornerFreq**2.0 + 4.0 + 4.0*Damp*CornerFreq*DT
            a1(inst) = 2.0*DT**2.0*CornerFreq**2.0 - 8.0
            a0(inst) = DT**2.0*CornerFreq**2.0 + 4.0 - 4.0*Damp*CornerFreq*DT
            b2(inst) = DT**2.0*CornerFreq**2.0
            b1(inst) = 2.0*DT**2.0*CornerFreq**2.0
            b0(inst) = DT**2.0*CornerFreq**2.0
        ENDIF

        ! Filter
        SecLPFilter = 1.0/a2(inst) * (b2(inst)*InputSignal + b1(inst)*InputSignalLast1(inst) + & 
                                                        b0(inst)*InputSignalLast2(inst) - & 
                                a1(inst)*OutputSignalLast1(inst) - a0(inst)*OutputSignalLast2(inst))

        ! Save signals for next time step
        InputSignalLast2(inst)   = InputSignalLast1(inst)
        InputSignalLast1(inst)   = InputSignal
        OutputSignalLast2(inst)  = OutputSignalLast1(inst)
        OutputSignalLast1(inst)  = SecLPFilter

        inst = inst + 1

    END FUNCTION SecLPFilter
!-------------------------------------------------------------------------------------------------------------------------------
    REAL(DbKi) FUNCTION HPFilter( InputSignal, DT, CornerFreq, iStatus, reset, inst)
    ! Discrete time High-Pass Filter
        USE ROSCO_Types, ONLY : FilterParameters
        !TYPE(FilterParameters),       INTENT(INOUT)       :: FP 

        REAL(DbKi), INTENT(IN)     :: InputSignal
        REAL(DbKi), INTENT(IN)     :: DT                       ! time step [s]
        REAL(DbKi), INTENT(IN)     :: CornerFreq               ! corner frequency [rad/s]
        INTEGER(IntKi), INTENT(IN)     :: iStatus                  ! A status flag set by the simulation as follows: 0 if this is the first call, 1 for all subsequent time steps, -1 if this is the final call at the end of the simulation.
        INTEGER(IntKi), INTENT(INOUT)  :: inst                     ! Instance number. Every instance of this function needs to have an unique instance number to ensure instances don't influence each other.
        LOGICAL(4), INTENT(IN)  :: reset                    ! Reset the filter to the input signal
        ! Local
        REAL(DbKi)                 :: K                        ! Constant gain
        REAL(DbKi), DIMENSION(99), SAVE    :: InputSignalLast      ! Input signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: OutputSignalLast ! Output signal the last time this filter was called. Supports 99 separate instances.

        ! Initialization
        IF ((iStatus == 0) .OR. reset)  THEN
            OutputSignalLast(inst) = InputSignal
            InputSignalLast(inst) = InputSignal
        ENDIF
        K = 2.0 / DT

        ! Body
        !HPFilter = K/(CornerFreq + K)*InputSignal - K/(CornerFreq + K)*FP%hpf_InputSignalLast(inst) - (CornerFreq - K)/(CornerFreq + K)*FP%hpf_OutputSignalLast(inst)
        HPFilter = K/(CornerFreq + K)*InputSignal - K/(CornerFreq + K)*InputSignalLast(inst) - (CornerFreq - K)/(CornerFreq + K)*OutputSignalLast(inst)

        ! Save signals for next time step
        InputSignalLast(inst)   = InputSignal
        OutputSignalLast(inst)  = HPFilter
        inst = inst + 1

    END FUNCTION HPFilter
!-------------------------------------------------------------------------------------------------------------------------------
    REAL(DbKi) FUNCTION NotchFilterSlopes(InputSignal, DT, CornerFreq, Damp, iStatus, reset, inst, Moving)
    ! Discrete time inverted Notch Filter with descending slopes, G = CornerFreq*s/(Damp*s^2+CornerFreq*s+Damp*CornerFreq^2)
        USE ROSCO_Types, ONLY : FilterParameters
        !TYPE(FilterParameters),       INTENT(INOUT)       :: FP 

        REAL(DbKi), INTENT(IN)                  :: InputSignal
        REAL(DbKi), INTENT(IN)                  :: DT               ! time step [s]
        REAL(DbKi), INTENT(IN)                  :: CornerFreq       ! corner frequency [rad/s]
        REAL(DbKi), INTENT(IN)                  :: Damp             ! Dampening constant
        INTEGER(IntKi), INTENT(IN)              :: iStatus          ! A status flag set by the simulation as follows: 0 if this is the first call, 1 for all subsequent time steps, -1 if this is the final call at the end of the simulation.
        INTEGER(IntKi), INTENT(INOUT)           :: inst             ! Instance number. Every instance of this function needs to have an unique instance number to ensure instances don't influence each other.
        LOGICAL(4), INTENT(IN)                  :: reset            ! Reset the filter to the input signal
        ! Local
        REAL(DbKi), DIMENSION(99), SAVE :: b2, b0, a2, a1, a0    ! Input signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE :: InputSignalLast1    ! Input signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE :: InputSignalLast2    ! Input signal the next to last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE :: OutputSignalLast1   ! Output signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE :: OutputSignalLast2   ! Output signal the next to last time this filter was called. Supports 99 separate instances.
        
        LOGICAL, OPTIONAL,  INTENT(IN)          :: Moving           ! Moving CornerFreq flag

        LOGICAL                                 :: Moving_          ! Local version
        REAL(DbKi)                              :: CornerFreq_          ! Local version

        Moving_ = .FALSE.
        IF (PRESENT(Moving)) Moving_ = Moving   

        ! Saturate Corner Freq at 0
        IF (CornerFreq < 0) THEN 
            CornerFreq_ = 0
        ELSE
            CornerFreq_ = CornerFreq
        ENDIF
        
        ! Initialization
        IF ((iStatus == 0) .OR. reset) THEN
            OutputSignalLast1(inst)  = InputSignal
            OutputSignalLast2(inst)  = InputSignal
            InputSignalLast1(inst)   = InputSignal
            InputSignalLast2(inst)   = InputSignal
            !b2(inst) = 2.0 * DT * CornerFreq
            !b0(inst) = -b2(inst)
            !a2(inst) = Damp*DT**2.0*CornerFreq**2.0 + 2.0*DT*CornerFreq + 4.0*Damp
            !a1(inst) = 2.0*Damp*DT**2.0*CornerFreq**2.0 - 8.0*Damp
            !a0(inst) = Damp*DT**2.0*CornerFreq**2.0 - 2*DT*CornerFreq + 4.0*Damp
        ENDIF

        IF ((iStatus == 0) .OR. reset .OR. Moving_) THEN
            b2(inst) = 2.0 * DT * CornerFreq_
            b0(inst) = -b2(inst)
            a2(inst) = Damp*DT**2.0*CornerFreq_**2.0 + 2.0*DT*CornerFreq_ + 4.0*Damp
            a1(inst) = 2.0*Damp*DT**2.0*CornerFreq_**2.0 - 8.0*Damp
            a0(inst) = Damp*DT**2.0*CornerFreq_**2.0 - 2*DT*CornerFreq_ + 4.0*Damp
        ENDIF

        NotchFilterSlopes = 1.0/a2(inst) * (b2(inst)*InputSignal + b0(inst)*InputSignalLast2(inst) &
                            - a1(inst)*OutputSignalLast1(inst)  - a0(inst)*OutputSignalLast2(inst))

        ! Save signals for next time step
        InputSignalLast2(inst)   = InputSignalLast1(inst)
        InputSignalLast1(inst)   = InputSignal          !Save input signal for next time step
        OutputSignalLast2(inst)  = OutputSignalLast1(inst)      !Save input signal for next time step
        OutputSignalLast1(inst)  = NotchFilterSlopes
        inst = inst + 1

    END FUNCTION NotchFilterSlopes
!-------------------------------------------------------------------------------------------------------------------------------
    REAL(DbKi) FUNCTION NotchFilter(InputSignal, DT, omega, betaNum, betaDen, iStatus, reset, inst)
    ! Discrete time Notch Filter 
    !                               Continuous Time Form: G(s) = (s^2 + 2*omega*betaNum*s + omega^2)/(s^2 + 2*omega*betaDen*s + omega^2)
    !                               Discrete Time Form:   H(z) = (b2*z^2 +b1*z^2 + b0*z)/((z^2 +a1*z^2 + a0*z))
        USE ROSCO_Types, ONLY : FilterParameters
        ! TYPE(FilterParameters),       INTENT(INOUT)       :: FP 

        REAL(DbKi), INTENT(IN)     :: InputSignal
        REAL(DbKi), INTENT(IN)     :: DT                       ! time step [s]
        REAL(DbKi), INTENT(IN)     :: omega                    ! corner frequency [rad/s]
        REAL(DbKi), INTENT(IN)     :: betaNum                  ! Dampening constant in numerator of filter transfer function
        REAL(DbKi), INTENT(IN)     :: betaDen                  ! Dampening constant in denominator of filter transfer function
        INTEGER(IntKi), INTENT(IN)     :: iStatus                  ! A status flag set by the simulation as follows: 0 if this is the first call, 1 for all subsequent time steps, -1 if this is the final call at the end of the simulation.
        INTEGER(IntKi), INTENT(INOUT)  :: inst                     ! Instance number. Every instance of this function needs to have an unique instance number to ensure instances don't influence each other.
        LOGICAL(4), INTENT(IN)  :: reset                    ! Reset the filter to the input signal
        ! Local
        !REAL(DbKi)                 :: K                        ! Constant gain
        REAL(DbKi), DIMENSION(99), SAVE    :: K, b2, b1, b0, a1, a0    ! Constant gain
        REAL(DbKi), DIMENSION(99), SAVE    :: InputSignalLast1         ! Input signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: InputSignalLast2         ! Input signal the next to last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: OutputSignalLast1        ! Output signal the last time this filter was called. Supports 99 separate instances.
        REAL(DbKi), DIMENSION(99), SAVE    :: OutputSignalLast2        ! Output signal the next to last time this filter was called. Supports 99 separate instances.

        ! Initialization
        !K = 2.0/DT
        IF ((iStatus == 0) .OR. reset) THEN
            OutputSignalLast1(inst)  = InputSignal
            OutputSignalLast2(inst)  = InputSignal
            InputSignalLast1(inst)   = InputSignal
            InputSignalLast2(inst)   = InputSignal
            K(inst) = 2.0/DT
            b2(inst) = (K(inst)**2.0 + 2.0*omega*BetaNum*K(inst) + omega**2.0)/(K(inst)**2.0 + 2.0*omega*BetaDen*K(inst) + omega**2.0)
            b1(inst) = (2.0*omega**2.0 - 2.0*K(inst)**2.0)  / (K(inst)**2.0 + 2.0*omega*BetaDen*K(inst) + omega**2.0);
            b0(inst) = (K(inst)**2.0 - 2.0*omega*BetaNum*K(inst) + omega**2.0) / (K(inst)**2.0 + 2.0*omega*BetaDen*K(inst) + omega**2.0)
            a1(inst) = (2.0*omega**2.0 - 2.0*K(inst)**2.0)  / (K(inst)**2.0 + 2.0*omega*BetaDen*K(inst) + omega**2.0)
            a0(inst) = (K(inst)**2.0 - 2.0*omega*BetaDen*K(inst) + omega**2.0)/ (K(inst)**2.0 + 2.0*omega*BetaDen*K(inst) + omega**2.0)
        ENDIF
        
        ! Body
        NotchFilter = b2(inst)*InputSignal + b1(inst)*InputSignalLast1(inst) + b0(inst)*InputSignalLast2(inst) - a1(inst)*OutputSignalLast1(inst) - a0(inst)*OutputSignalLast2(inst)

        ! Save signals for next time step
        InputSignalLast2(inst)   = InputSignalLast1(inst)
        InputSignalLast1(inst)   = InputSignal                  ! Save input signal for next time step
        OutputSignalLast2(inst)  = OutputSignalLast1(inst)      ! Save input signal for next time step
        OutputSignalLast1(inst)  = NotchFilter
        inst = inst + 1

    END FUNCTION NotchFilter
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE PreFilterMeasuredSignals(CntrPar, LocalVar, DebugVar, objInst, ErrVar)
    ! Prefilter measured wind turbine signals to separate the filtering from the actual control actions

        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, DebugVariables, ObjectInstances, ErrorVariables
        
        TYPE(ControlParameters), INTENT(INOUT)      :: CntrPar
        TYPE(LocalVariables),    INTENT(INOUT)      :: LocalVar
        TYPE(DebugVariables),    INTENT(INOUT)      :: DebugVar
        TYPE(ObjectInstances),   INTENT(INOUT)      :: objInst
        TYPE(ErrorVariables),   INTENT(INOUT)       :: ErrVar
        INTEGER(IntKi) :: K  ! Integer used to loop through turbine blades

        REAL(DbKi) :: u_CornerFreq = 0.0333 ! Corner frequency for wind speed

        ! If there's an error, don't even try to run
        IF (ErrVar%aviFAIL < 0) THEN
            RETURN
        ENDIF

        ! Filter the HSS (generator) speed measurement:
        ! Apply Low-Pass Filter (choice between first- and second-order low-pass filter)
        IF (CntrPar%F_LPFType == 1) THEN
            LocalVar%GenSpeedF = LPFilter(LocalVar%GenSpeed, LocalVar%DT, CntrPar%F_LPFCornerFreq, LocalVar%iStatus, .FALSE., objInst%instLPF)
        ELSEIF (CntrPar%F_LPFType == 2) THEN   
            LocalVar%GenSpeedF = SecLPFilter(LocalVar%GenSpeed, LocalVar%DT, CntrPar%F_LPFCornerFreq, CntrPar%F_LPFDamping, LocalVar%iStatus, .FALSE., objInst%instSecLPF) ! Second-order low-pass filter on generator speed
        ENDIF
        ! Apply Notch Fitler
        IF (CntrPar%F_NotchType == 1 .OR. CntrPar%F_NotchType == 3) THEN
            LocalVar%GenSpeedF = NotchFilter(LocalVar%GenSpeedF, LocalVar%DT, CntrPar%F_NotchCornerFreq, CntrPar%F_NotchBetaNumDen(1), CntrPar%F_NotchBetaNumDen(2), LocalVar%iStatus, .FALSE., objInst%instNotch)
        ENDIF

        ! Filtering the tower fore-aft acceleration signal 
        IF (CntrPar%Fl_Mode == 1) THEN
            LocalVar%NacIMU_FA_AccF = SecLPFilter(LocalVar%NacIMU_FA_Acc, LocalVar%DT, CntrPar%F_FlCornerFreq(0), CntrPar%F_FlDamping, LocalVar%iStatus, .FALSE., objInst%instSecLPF) ! Fixed Damping
            ! LocalVar%NacIMU_FA_AccF = NotchFilterSlopes(LocalVar%NacIMU_FA_Acc, LocalVar%DT, CntrPar%F_FlCornerFreq(0), CntrPar%F_FlDamping, LocalVar%iStatus, .FALSE., objInst%instNotchSlopes) ! Fixed Damping
            IF (CntrPar%F_NotchType >= 2) THEN
                LocalVar%NACIMU_FA_AccF = NotchFilter(LocalVar%NacIMU_FA_AccF, LocalVar%DT, CntrPar%F_NotchCornerFreq, CntrPar%F_NotchBetaNumDen(1), CntrPar%F_NotchBetaNumDen(2), LocalVar%iStatus, .FALSE., objInst%instNotch) ! Fixed Damping
            ENDIF
        ENDIF

        LocalVar%FA_AccHPF = HPFilter(LocalVar%FA_Acc, LocalVar%DT, CntrPar%FA_HPFCornerFreq, LocalVar%iStatus, .FALSE., objInst%instHPF)

        ! Filter Wind Speed Estimator Signal
        !LocalVar%We_Vw_F = LPFilter(LocalVar%WE_Vw, LocalVar%DT,CntrPar%F_WECornerFreq, LocalVar%iStatus, LocalVar%restart, objInst%instLPF) ! 30 second time constant
        LocalVar%HorWindV_F = LPFilter(LocalVar%HorWindV, LocalVar%DT, u_CornerFreq, LocalVar%iStatus, .FALSE., objInst%instLPF)
        LocalVar%We_Vw_F = LPFilter(LocalVar%We_Vw, LocalVar%DT, 0.6283, LocalVar%iStatus, .FALSE., objInst%instLPF)

        ! Blade root bending moment for IPC
        DO K = 1,LocalVar%NumBl
            IF ((CntrPar%IPC_ControlMode > 0) .OR. (CntrPar%DAC_Mode == 3)) THEN
                ! Moving inverted notch at rotor speed to isolate 1P
                LocalVar%RootMOOPF(K) = NotchFilterSlopes(LocalVar%rootMOOP(K), LocalVar%DT, LocalVar%RotSpeedF, 0.7_DbKi, LocalVar%iStatus, LocalVar%restart, objInst%instNotchSlopes, .TRUE.)
            ELSEIF ( CntrPar%DAC_Mode == 2 ) THEN
                ! Filter Blade root bending moments
                LocalVar%RootMOOPF(K) = SecLPFilter(LocalVar%rootMOOP(K),LocalVar%DT, CntrPar%F_DACCornerFreq(1), CntrPar%F_DACCornerFreq(2), LocalVar%iStatus, LocalVar%restart,objInst%instSecLPF)
                LocalVar%RootMOOPF(K) = NotchFilter(LocalVar%RootMOOPF(K), LocalVar%DT, CntrPar%F_NotchCornerFreq, CntrPar%F_NotchBetaNumDen(1), CntrPar%F_NotchBetaNumDen(2), LocalVar%iStatus, LocalVar%restart, objInst%instNotch) 
                LocalVar%RootMOOPF(K) = HPFilter(LocalVar%rootMOOPF(K),LocalVar%DT, 0.1_DbKi, LocalVar%iStatus, LocalVar%restart,objInst%instHPF)
            ELSE
                LocalVar%RootMOOPF(K) = LocalVar%rootMOOP(K)
            ENDIF     
        END DO


        ! Control commands (used by WSE, mostly)
        LocalVar%VS_LastGenTrqF = SecLPFilter(LocalVar%VS_LastGenTrq, LocalVar%DT, CntrPar%F_LPFCornerFreq, 0.7_DbKi, LocalVar%iStatus, LocalVar%restart, objInst%instSecLPF)
        LocalVar%PC_PitComTF    = SecLPFilter(LocalVar%PC_PitComT, LocalVar%DT, CntrPar%F_LPFCornerFreq*0.25, 0.7_DbKi, LocalVar%iStatus, LocalVar%restart, objInst%instSecLPF)

        ! Debug Variables
        DebugVar%GenSpeedF = LocalVar%GenSpeedF
        DebugVar%RotSpeedF = LocalVar%RotSpeedF
        DebugVar%NacIMU_FA_AccF = LocalVar%NacIMU_FA_AccF
        DebugVar%FA_AccF = LocalVar%FA_AccF
    END SUBROUTINE PreFilterMeasuredSignals
    END MODULE Filters