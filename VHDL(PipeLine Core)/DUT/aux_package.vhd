library IEEE;
use ieee.std_logic_1164.all;
USE work.cond_compilation_package.all;


package aux_package is

	component RV32IM_CORE IS
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
		PORT(
			--Inputs
			rst_i				: IN	STD_LOGIC;									-- KEY0
			clk_i				: IN	STD_LOGIC;									-- 50 MHz
			BPADDR_i			: IN	STD_LOGIC_VECTOR(AUX_CNT_WIDTH-1 DOWNTO 0);	-- SW7-0 (word addr)

			--Outputs (Signal-Tap auxiliary pins)
			CLKCNT_o			: OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

			IFpc_o				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			IFinstruction_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			IDpc_o				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			IDinstruction_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EXpc_o				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EXinstruction_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEMpc_o				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MEMinstruction_o	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			WBpc_o				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			WBinstruction_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

			STRIGGER_o			: OUT	STD_LOGIC;
			FHCNT_o				: OUT	STD_LOGIC_VECTOR(AUX_CNT_WIDTH-1 DOWNTO 0);
			STCNT_o				: OUT	STD_LOGIC_VECTOR(AUX_CNT_WIDTH-1 DOWNTO 0)
		);
	END component;
---------------------------------------------------------  
	component control is
		PORT( 
		--Inputs
		instruction_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		--Outputs
		RegDst_ctrl_o 		: OUT 	STD_LOGIC;
		ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
		MemtoReg_ctrl_o 	: OUT 	STD_LOGIC;
		RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
		MemRead_ctrl_o 		: OUT 	STD_LOGIC;
		MemWrite_ctrl_o	 	: OUT 	STD_LOGIC;
		Branch_ctrl_o 		: OUT 	STD_LOGIC;
		Jal_ctrl_o 			: OUT 	STD_LOGIC;
		Jalr_ctrl_o 		: OUT 	STD_LOGIC;
		WBSrc_o				: OUT 	STD_LOGIC;
		mul_ctrl_o			: OUT 	STD_LOGIC;
		UpperIm_ctrl_o		: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_o	 	: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
		MULOp_ctrl_o	 	: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0)
	);
	end component;
---------------------------------------------------------	
	component dmemory is
		generic(
			DATA_BUS_WIDTH 	: integer := 32;
			DTCM_ADDR_WIDTH : integer := 8;
			WORDS_NUM 			: integer := 256
		);
		PORT(	
			--Inputs
			clk_i			: IN 	STD_LOGIC;
			rst_i			: IN 	STD_LOGIC;
			dtcm_addr_i 	: IN 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
			dtcm_data_wr_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MemRead_ctrl_i  : IN 	STD_LOGIC;
			MemWrite_ctrl_i : IN 	STD_LOGIC;
			
			--Outputs
			dtcm_data_rd_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------		
	component Execute is
		generic(
			DATA_BUS_WIDTH 	: integer := 32;
			PC_WIDTH 		: integer := 10;
			MULT_WIDTH 		: integer := 10
		);
		PORT(	
			--Inputs
			read_data1_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			sign_extend_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			UpperIm_ctrl_i	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			ALUOp_ctrl_i	: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
			MULOp_ctrl_i	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			ALUSrc_ctrl_i 	: IN 	STD_LOGIC;
			pc_i			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			WBSrc_i 		: IN 	STD_LOGIC;
			mem_res_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			wb_res_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			ForwardA_i		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			ForwardB_i		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			--Outputs
			brTaken_o 		: OUT	STD_LOGIC;
			alu_res_o 		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			addr_gen_o 		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			P0_o,P1_o		: OUT	STD_LOGIC_VECTOR(MULT_WIDTH-1 DOWNTO 0);
			P2_o,P3_o		: OUT	STD_LOGIC_VECTOR(MULT_WIDTH-1 DOWNTO 0);
			rs2_fwd_o		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------		
	component Idecode is
		generic(
			PC_WIDTH 		: integer	:= 10;
			DATA_BUS_WIDTH	: integer := 32
		);
		PORT(
			--Inputs
			clk_i			: IN 	STD_LOGIC;
			rst_i			: IN 	STD_LOGIC;
			pc_plus4_i		: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			write_data_i	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			RegWrite_ctrl_i : IN 	STD_LOGIC;
			wb_rd_i			: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
			
			--Outputs
			read_data1_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			SignExt_o 		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)		 
		);
	end component;
---------------------------------------------------------		
	component Ifetch is
		generic(
			WORD_GRANULARITY 	: boolean	:= False;
			DATA_BUS_WIDTH 		: integer	:= 32;
			PC_WIDTH 					: integer	:= 10;
			ITCM_ADDR_WIDTH 	: integer	:= 8;
			WORDS_NUM 				: integer	:= 256
		);
		PORT(
			--Inputs
			clk_i			: IN 	STD_LOGIC;
			rst_i 			: IN 	STD_LOGIC;
			PCwrite_i 		: IN 	STD_LOGIC;
			redirect_i		: IN 	STD_LOGIC;
			redirect_pc_i	: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			BPADDR_i		: IN 	STD_LOGIC_VECTOR(7 DOWNTO 0);
			--Outputs
			pc_o 			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_plus4_o 		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_o 	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			STRIGGER_o		: OUT 	STD_LOGIC
		);
	end component;
---------------------------------------------------------
	COMPONENT PLL IS
		port(
			areset		: IN STD_LOGIC  := '0';
			inclk0		: IN STD_LOGIC  := '0';
			c0     		: OUT STD_LOGIC ;
			locked		: OUT STD_LOGIC 
		);
  	END COMPONENT;
---------------------------------------------------------	
	COMPONENT ForwardingUnit IS
		PORT(
			idex_rs1_i		: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
			idex_rs2_i		: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
	
			exmem_rd_i		: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
			exmem_regwrite_i: IN	STD_LOGIC;
	
			memwb_rd_i		: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
			memwb_regwrite_i: IN	STD_LOGIC;
	
			forwardA_o		: OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);
			forwardB_o		: OUT	STD_LOGIC_VECTOR(1 DOWNTO 0)
		);
	END COMPONENT;
---------------------------------------------------------
	COMPONENT HazardUnit is
		generic (
			DATA_BUS_WIDTH: integer := 32
		);
		port (
			ifid_instuction_i   : IN    std_logic_vector(DATA_BUS_WIDTH-1 downto 0);
			idex_rd_i           : IN    std_logic_vector(4 downto 0);
			idex_regwrite_i	    : IN	STD_LOGIC;
			idex_memread_i		: IN	STD_LOGIC;
			idex_mul_i			: IN    STD_LOGIC;

			stall_o				: OUT   STD_LOGIC;
			PCwrite_o			: OUT   STD_LOGIC;
			IFIDwrite_o			: OUT   STD_LOGIC
		);
	end COMPONENT;
---------------------------------------------------------
	COMPONENT Mul_Stage2 is
		generic (
			DATA_BUS_WIDTH 	: integer := 32;
			MULT_WIDTH      : integer := 16
		);
		port (
			P0_i,P1_i       : IN STD_LOGIC_VECTOR(MULT_WIDTH-1 DOWNTO 0);
			P2_i,P3_i       : IN STD_LOGIC_VECTOR(MULT_WIDTH-1 DOWNTO 0);
			MULOp_ctrl_i    : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			Mul_res_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end COMPONENT;
---------------------------------------------------------
end aux_package;


