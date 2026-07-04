LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;


ENTITY tb_RV32I IS
	generic(
		WORD_GRANULARITY	: boolean	:= G_WORD_GRANULARITY;
		MODELSIM			: integer	:= G_MODELSIM;
		DATA_BUS_WIDTH		: integer	:= 32;
		ITCM_ADDR_WIDTH		: integer	:= G_ADDRWIDTH;
		DTCM_ADDR_WIDTH		: integer	:= G_ADDRWIDTH;
		PC_WIDTH			: integer	:= G_PC_WIDTH;
		MA_WIDTH			: integer	:= G_MA_WIDTH;
		DATA_WORDS_NUM		: integer	:= G_DATA_WORDSNUM;
		CLK_CNT_WIDTH		: integer	:= 16;
		AUX_CNT_WIDTH		: integer	:= 8
	);
END tb_RV32I ;


ARCHITECTURE struct OF tb_RV32I IS
	--Inputs
	SIGNAL rst_i			: STD_LOGIC;
	SIGNAL clk_i			: STD_LOGIC;
	SIGNAL BPADDR_i			: STD_LOGIC_VECTOR(AUX_CNT_WIDTH-1 DOWNTO 0);

	--Outputs (Signal-Tap / verification)
	SIGNAL CLKCNT_o			: STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

	SIGNAL IFpc_o			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL IFinstruction_o	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL IDpc_o			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL IDinstruction_o	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL EXpc_o			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL EXinstruction_o	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL MEMpc_o			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL MEMinstruction_o	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL WBpc_o			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL WBinstruction_o	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL STRIGGER_o		: STD_LOGIC;
	SIGNAL FHCNT_o			: STD_LOGIC_VECTOR(AUX_CNT_WIDTH-1 DOWNTO 0);
	SIGNAL STCNT_o			: STD_LOGIC_VECTOR(AUX_CNT_WIDTH-1 DOWNTO 0);

BEGIN
	CORE : RV32IM_CORE
	generic map(
		WORD_GRANULARITY	=> WORD_GRANULARITY,
		MODELSIM			=> MODELSIM,
		DATA_BUS_WIDTH		=> DATA_BUS_WIDTH,
		ITCM_ADDR_WIDTH		=> ITCM_ADDR_WIDTH,
		DTCM_ADDR_WIDTH		=> DTCM_ADDR_WIDTH,
		PC_WIDTH			=> PC_WIDTH,
		MA_WIDTH			=> MA_WIDTH,
		DATA_WORDS_NUM		=> DATA_WORDS_NUM,
		CLK_CNT_WIDTH		=> CLK_CNT_WIDTH,
		AUX_CNT_WIDTH		=> AUX_CNT_WIDTH
	)
	PORT MAP (
		--Inputs
		rst_i				=> rst_i,
		clk_i				=> clk_i,
		BPADDR_i			=> BPADDR_i,

		--Outputs
		CLKCNT_o			=> CLKCNT_o,

		IFpc_o				=> IFpc_o,
		IFinstruction_o		=> IFinstruction_o,
		IDpc_o				=> IDpc_o,
		IDinstruction_o		=> IDinstruction_o,
		EXpc_o				=> EXpc_o,
		EXinstruction_o		=> EXinstruction_o,
		MEMpc_o				=> MEMpc_o,
		MEMinstruction_o	=> MEMinstruction_o,
		WBpc_o				=> WBpc_o,
		WBinstruction_o		=> WBinstruction_o,

		STRIGGER_o			=> STRIGGER_o,
		FHCNT_o				=> FHCNT_o,
		STCNT_o				=> STCNT_o
	);
--------------------------------------------------------------------
	gen_clk : -- MCLK cycle = 100 ns = 0.1 us
	process
	begin
		clk_i <= '1';
		wait for 50 ns;
		clk_i <= not clk_i;
		wait for 50 ns;
	end process;

	gen_rst :
	process
	begin
		rst_i <= '1', '0' after 100 ns;
		wait;
	end process;

	gen_bp : -- breakpoint word address (SW7-0); set to whatever you want STRIGGER to fire on
	process
	begin
		BPADDR_i <= x"ff";
		wait;
	end process;
--------------------------------------------------------------------
END struct;