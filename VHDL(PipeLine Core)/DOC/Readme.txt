=====================================================================================================
LAB5 - Scalar Single-Cycle & 5-Stage Pipelined RV32IM CPU microArchitecture
Advanced CPU Architecture & Hardware Accelerators (361-1-4693) - Instructor: Hanan Ribo
Target device: Intel Cyclone V  5CSXFC6D6F31C6  (DE-SoC board)
Tools: Quartus Prime 25.1std.0 | ModelSim | Signal-Tap | In-System Memory Content Editor (ISMCE) | RARS
=====================================================================================================

OVERVIEW
This project implements a RISC-V compatible CPU supporting the RV32IM (MULDIV-partial) instruction
set, in two micro-architectural variants that share the same datapath sub-modules:
  - RV32IM_sc        : a scalar single-cycle core (one instruction per clock).
  - RV32IM_pipeline  : a scalar 5-stage pipelined core (IF / ID / EX / MEM / WB) with full data
                       forwarding, combinational hazard (interlock) detection, and branch/jump
                       resolution in stage 4.
Both cores use a Harvard organisation with separate ITCM (instruction) and DTCM (data) tightly-coupled
memories of 8 kB each, a standard RISC-V register file, a structural top level, and a single PLL-derived
clock (MCLK). Push-button KEY0 is the active core reset that forces the PC to the first instruction.

-----------------------------------------------------------------------------------------------------
CORE SUB-MODULES (shared by both cores)
-----------------------------------------------------------------------------------------------------

IFETCH (Ifetch:IFE)
The instruction-fetch stage. Holds the PC register and the PC+4 adder, contains the ITCM (8 kB
instruction memory, FPGA embedded altsyncram), and selects the next PC through a mux that chooses
between PC+4 and a branch/jump target. Outputs the fetched instruction and the current PC.

IDECODE (Idecode:ID)
The decode stage. Contains the standard RISC-V register file (32 x 32-bit, two read ports, one write
port) and the sign-extension / immediate-generation logic for I/S/B/U/J formats. Supplies read_data1
and read_data2 to EXECUTE and routes the write-back value into the destination register rd.

CONTROL (control:CTL)
The main control unit. Decodes the opcode and funct fields of the instruction into the datapath
control signals: ALUOp, ALUSrc, MULOp, Branch, Jal, Jalr, MemRead, MemWrite, MemtoReg, RegDst,
RegWrite, UpperIm and WBSrc.

EXECUTE (Execute:EXE)
The execute stage. Contains the ALU (add/sub, logic, shift, comparison for branch resolution), the
16-bit multiplier, the branch-target / effective-address generation, and the result mux that selects
the value forwarded to memory / write-back (ALU result, multiplier result, memory data, PC+4, or the
upper-immediate). The result-mux chain is the dominant contributor to the single-cycle critical path.

16-BIT MULTIPLIER (mul)
Implements only the mul instruction of the M-extension. mul rd, rs1, rs2 multiplies the lower 16-bit
half-words of rs1 and rs2 and writes the 32-bit product to rd. The 16x16 product is built from four
embedded 8-bit multipliers (FPGA DSP blocks):
   P0 = A_low x B_low,  P1 = A_low x B_high,  P2 = A_high x B_low,  P3 = A_high x B_high
   M  = P1 + P2 ,   RESULT = P0 + (M << 8) + (P3 << 16)
In the single-cycle core the multiplier is purely combinational; in the pipeline it is split into two
stages (see "Two-stage multiplier" below) so it stays off the critical path.

DMEMORY (dmemory:MEM)
The data-memory stage. Contains the DTCM (8 kB data memory, FPGA embedded altsyncram) with the
load/store interface. The DTCM is clocked on not(clk) so that, in the single-cycle core, a load can be
fetched, decoded, address-computed and read within the same clock period.

PLL (altpll, \G0:MCLK)
Clock-management block. Takes the 50 MHz board oscillator and synthesises the stable, phase-aligned
core clock MCLK used by the whole design and by the MCLK counter.

MCLK COUNTER
A free-running cycle counter clocked by MCLK, cleared on reset. In the single-cycle core it drives
mclk_cnt_o; in the pipeline it drives CLKCNT_o, which is the denominator of the IPC equation.

-----------------------------------------------------------------------------------------------------
PIPELINE-SPECIFIC BLOCKS (RV32IM_pipeline only)
-----------------------------------------------------------------------------------------------------

PIPELINE REGISTERS (IF/ID, ID/EX, EX/MEM, MEM/WB)
Four edge-triggered register banks that slice the single-cycle datapath into five stages. Each bank
carries the data, control and PC/instruction fields of its stage and provides an enable input (for
stalls) and a clear input (for flushes).

STALL-CONDITION UNIT (Hazard detection)
A purely combinational interlock checker (combinational-check approach, not score-board). It detects
load-use and mul-use hazards - cases where a dependent instruction would read a result that is not yet
available even with forwarding - and freezes the front of the pipeline by de-asserting PCwrite and
IF/ID-write while bubbling ID/EX. Each stalled clock increments STCNT_o.

FORWARDING UNIT
Implements full data forwarding so that back-to-back dependent ALU instructions do not stall. It
compares the destination registers held in EX/MEM and MEM/WB against the source registers in ID/EX and
drives the Forward_Ain / Forward_Bin selects into the ALU operand muxes (and the store-data path).

TWO-STAGE MULTIPLIER (stage 1 / stage 2)
The 16-bit multiplier split across the pipeline: the four 8-bit partial products (P0..P3) are formed in
EX (Multiplier stage 1) and combined and shifted into the final 32-bit result in MEM (Multiplier stage
2). This keeps the multiplier delay within a single stage and off the global critical path.

BRANCH / JUMP RESOLUTION (stage 4)
Conditional branches and unconditional jumps are resolved in stage 4 (MEM). A taken branch/jump flushes
the three younger in-flight slots; each flushed clock increments FHCNT_o.

-----------------------------------------------------------------------------------------------------
SIGNAL-TAP / DEBUG INSTRUMENTATION
-----------------------------------------------------------------------------------------------------

STCNT_o  (8-bit stall counter)  - cleared on reset; increments on every clock in which a stall occurs.
FHCNT_o  (8-bit flush counter)  - cleared on reset; increments on every clock in which a flush occurs.
BPADDR_i (8-bit breakpoint addr)- fed by SW7-SW0 (word granularity), cleared on reset.
STRIGGER_o (Signal-Tap trigger) - asserts when IF_PC == BPADDR_i, so core signals can be captured from
                                  any chosen PC until the Signal-Tap buffer is full (Auto-run lets a
                                  whole program be debugged in one session).
IPC measurement:
   IPC = ( CLKCNT_o - (STCNT_o + 4 + depth * FHCNT_o) ) / CLKCNT_o = InstructionCounter / CLKCNT_o ,
   where IPC = 1/CPI and "depth" is the number of slots flushed per taken branch.
For the single-cycle core STCNT = FHCNT = 0, so CPI = 1 and IPC = 1 by construction.

-----------------------------------------------------------------------------------------------------
SYSTEM TOP ENTITY
-----------------------------------------------------------------------------------------------------

RV32IM_CORE (single-cycle) - structural top level
Inputs : clk_i (50 MHz -> PLL), rst_i (KEY0)
Submodules: IFETCH, IDECODE, CONTROL, EXECUTE, DMEMORY, PLL (MCLK), MCLK counter.
Outputs (to Signal-Tap): pc_o, instruction_o, RegWrite_ctrl_o, MemWrite_ctrl_o, Branch_ctrl_o,
read_data1_o, read_data2_o, write_data_o, alu_res_o, brTaken_o, dtcm_addr_o, dtcm_data_wr_o,
dtcm_data_rd_o, mclk_cnt_o.

RV32IM_CORE (pipelined) - structural top level
Inputs : clk_i (50 MHz -> PLL), rst_i (KEY0), BPADDR_i (SW7-SW0)
Submodules: the five stages, the four pipeline-register banks, the Stall-Condition (hazard) unit, the
Forwarding unit, the two-stage multiplier, PLL (MCLK) and the MCLK counter.
Outputs (to Signal-Tap): CLKCNT_o, per-stage PC/instruction taps (IFpc_o/IFinstruction_o,
IDpc_o/IDinstruction_o, EXpc_o/EXinstruction_o, MEMpc_o/MEMinstruction_o, WBpc_o/WBinstruction_o),
STRIGGER_o, FHCNT_o, STCNT_o.

-----------------------------------------------------------------------------------------------------
FPGA I/O INTERFACE  (Cyclone V 5CSXFC6D6F31C6, DE-SoC)
-----------------------------------------------------------------------------------------------------

Inputs
  CLK 50 MHz  - the board base oscillator; feeds the PLL, which generates the core clock MCLK.
  KEY0        - active core RESET (rst_i); brings the PC to the first program instruction.
  SW7-SW0     - breakpoint address BPADDR_i (pipeline only), word granularity, used by the Signal-Tap
                trigger STRIGGER_o = (IF_PC == BPADDR_i).

Clocking
  The PLL converts the 50 MHz input into the synthesised MCLK that clocks the entire core and the cycle
  counter. The achieved Fmax sets the ceiling on MCLK (34.99 MHz single-cycle, ~98.72 MHz pipelined).

Observation / debug
  The top-level output ports listed above are captured live on the board with Signal-Tap (triggered by
  BPADDR_i). The ITCM and DTCM contents are inspected and verified with the In-System Memory Content
  Editor (ISMCE) and compared against the RARS golden DTCM.hex / DTCM.mem.

Data flow summary
  switches/keys -> registered inputs (clk_i, rst_i, BPADDR_i) -> PLL -> MCLK -> RV32IM core (fetch ->
  decode -> execute/multiply -> data memory -> write-back) -> observation ports -> Signal-Tap / ISMCE.
