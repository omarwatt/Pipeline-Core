LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;
USE work.const_package.all;

ENTITY RV32IM_CORE IS
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
		AUX_CNT_WIDTH		: integer	:= 8;
		MULT_WIDTH     		: integer := 16

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
END RV32IM_CORE;
--============================================================================
ARCHITECTURE structure OF RV32IM_CORE IS
	-- declare signals used to connect VHDL components
	SIGNAL mclk_w 		: STD_LOGIC;
	SIGNAL mclk_cnt_q	: STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
	SIGNAL PCwrite_w	: STD_LOGIC;
	SIGNAL Strigger_w	: STD_LOGIC;
	SIGNAL IFIDwrite_w	: STD_LOGIC;
		---------------------------------------------------------------- IF
	SIGNAL if_pc_w		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL if_pcplus4_w	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL if_instr_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
 
	---------------------------------------------------------------- IF/ID
	SIGNAL ifid_pc_q		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ifid_pcplus4_q	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ifid_instr_q		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
 
	---------------------------------------------------------------- ID (comb)
	SIGNAL id_regdst_w, id_alusrc_w, id_memtoreg_w, id_regwrite_w	: STD_LOGIC;
	SIGNAL id_memread_w, id_memwrite_w, id_branch_w					: STD_LOGIC;
	SIGNAL id_jal_w, id_jalr_w, id_wbsrc_w, id_mul_w				: STD_LOGIC;
	SIGNAL id_upperim_w		: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL id_aluop_w		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL id_mulop_w		: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL id_rdata1_w, id_rdata2_w, id_signext_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
 
	---------------------------------------------------------------- ID/EX
	SIGNAL idex_pc_q, idex_pcplus4_q	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL idex_instr_q					: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL idex_rdata1_q, idex_rdata2_q, idex_signext_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL idex_rs1_q, idex_rs2_q, idex_rd_q	: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL idex_aluop_q		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL idex_upperim_q	: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL idex_mulop_q		: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL idex_alusrc_q, idex_wbsrc_q, idex_regwrite_q, idex_memread_q	: STD_LOGIC;
	SIGNAL idex_memwrite_q, idex_memtoreg_q, idex_regdst_q				: STD_LOGIC;
	SIGNAL idex_branch_q, idex_jal_q, idex_jalr_q						: STD_LOGIC;
	SIGNAL idex_mul_q	: STD_LOGIC;
 
	---------------------------------------------------------------- EX (comb)
	SIGNAL forwardA_w, forwardB_w	: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL ex_brtaken_w				: STD_LOGIC;
	SIGNAL ex_alures_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ex_addrgen_w				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ex_P0_w, ex_P1_w, ex_P2_w, ex_P3_w	: STD_LOGIC_VECTOR(MULT_WIDTH-1 DOWNTO 0);
 	SIGNAL ex_rs2_fwd_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	---------------------------------------------------------------- EX/MEM
	SIGNAL exmem_pc_q, exmem_pcplus4_q	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL exmem_instr_q				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL exmem_alures_q				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL exmem_rdata2_q				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL exmem_addrgen_q				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL exmem_P0_q, exmem_P1_q, exmem_P2_q, exmem_P3_q	: STD_LOGIC_VECTOR(MULT_WIDTH-1 DOWNTO 0);
	SIGNAL exmem_mulop_q : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL exmem_rd_q		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL exmem_regwrite_q, exmem_memread_q, exmem_memwrite_q	: STD_LOGIC;
	SIGNAL exmem_memtoreg_q, exmem_regdst_q, exmem_wbsrc_q		: STD_LOGIC;
	SIGNAL exmem_branch_q, exmem_jal_q, exmem_jalr_q, exmem_brtaken_q	: STD_LOGIC;
	SIGNAL exmem_mul_q	: STD_LOGIC;
 
	---------------------------------------------------------------- MEM (comb)
	SIGNAL mem_mulres_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_dtcm_rd_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_dtcm_addr_w	: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL redirect_w		: STD_LOGIC;
	SIGNAL redirect_pc_w	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
 	SIGNAL mem_mux_res_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	---------------------------------------------------------------- MEM/WB
	SIGNAL memwb_pc_q		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL memwb_pcplus4_q	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL memwb_instr_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL memwb_mux_res_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL memwb_mul2_res_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL memwb_dtcm_rd_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL memwb_rd_q		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL memwb_regwrite_q	: STD_LOGIC;
	SIGNAL memwb_wbsrc_q	: STD_LOGIC;
	SIGNAL memwb_memtoreg_q : STD_LOGIC;
	SIGNAL memwb_regdst_q 	: STD_LOGIC;
	
	---------------------------------------------------------------- WB
	SIGNAL wb_mux_res_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL wbid_mux_res_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	---------------------------------------------------------------- hazards / counters
	SIGNAL stall_w			: STD_LOGIC;
	SIGNAL clkcnt_q			: UNSIGNED(CLK_CNT_WIDTH-1 DOWNTO 0);
	SIGNAL stcnt_q			: UNSIGNED(AUX_CNT_WIDTH-1 DOWNTO 0);
	SIGNAL fhcnt_q			: UNSIGNED(AUX_CNT_WIDTH-1 DOWNTO 0);
BEGIN
	
	--=======================================
	-- PLL module connection
	--=======================================
	G0:
	if (MODELSIM = 0) generate
	  MCLK: PLL
		PORT MAP (
			inclk0 	=> clk_i,
			c0 		=> mclk_w
		);
	else generate
		mclk_w <= clk_i;
	end generate;
	--===========================================
	-- IFETCH (including ITCM) module connection
	--===========================================
	IFE : Ifetch
	generic map(
		WORD_GRANULARITY	=> 	WORD_GRANULARITY,
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH, 
		PC_WIDTH			=>	PC_WIDTH,
		ITCM_ADDR_WIDTH		=>	ITCM_ADDR_WIDTH,
		WORDS_NUM			=>	DATA_WORDS_NUM
	)
	PORT MAP (
		--Inputs
		clk_i 				=> mclk_w,  
		rst_i 				=> rst_i,
		PCwrite_i 			=> PCwrite_w,
		redirect_i			=> redirect_w,
		redirect_pc_i		=> redirect_pc_w,
		BPADDR_i			=> BPADDR_i,
		--Outputs
		pc_o 			=> if_pc_w,
		pc_plus4_o	 	=> if_pcplus4_w,
		instruction_o 	=> if_instr_w,
		STRIGGER_o 		=> Strigger_w
	);
	redirect_w 		<= '1' when (exmem_jal_q or exmem_jalr_q or (exmem_branch_q and exmem_brtaken_q)) else '0'; 
	redirect_pc_w 	<= exmem_alures_q(PC_WIDTH-1 DOWNTO 0) when exmem_jalr_q = '1' else exmem_addrgen_q;
	--=======================================
	-- IDECODE module connection
	--=======================================
	ID : Idecode
 	generic map(
		PC_WIDTH				=>	PC_WIDTH,
		DATA_BUS_WIDTH			=>  DATA_BUS_WIDTH
	)
	PORT MAP (	
		--Inputs
		clk_i 			=> mclk_w,  
		rst_i 			=> rst_i,
		pc_plus4_i	 	=> ifid_pcplus4_q,
    	instruction_i 	=> ifid_instr_q,
		write_data_i	=> wbid_mux_res_w,
		RegWrite_ctrl_i => memwb_regwrite_q,
		wb_rd_i			=> memwb_rd_q,
		--Outputs
		read_data1_o 		=> id_rdata1_w,
    	read_data2_o 		=> id_rdata2_w,
		SignExt_o 			=> id_signext_w	 
	);
	--=======================================
	-- CONTROL module connection
	--=======================================
	CTL:   control
	PORT MAP ( 	
		--Inputs
		instruction_i 	=> ifid_instr_q,
		
		--Outputs
		RegDst_ctrl_o	=> id_regdst_w,
		ALUSrc_ctrl_o 	=> id_alusrc_w,
		MemtoReg_ctrl_o => id_memtoreg_w,
		RegWrite_ctrl_o => id_regwrite_w,
		MemRead_ctrl_o 	=> id_memread_w,
		MemWrite_ctrl_o => id_memwrite_w,
		Branch_ctrl_o 	=> id_branch_w,
		Jal_ctrl_o 		=> id_jal_w,
		Jalr_ctrl_o		=> id_jalr_w,
		UpperIm_ctrl_o 	=> id_upperim_w,
		ALUOp_ctrl_o 	=> id_aluop_w,
		MULOp_ctrl_o	=> id_mulop_w,
		WBSrc_o 		=> id_wbsrc_w,
		mul_ctrl_o 		=> id_mul_w
	);
	--=======================================
	-- EXECUTE module connection
	--=======================================
	EXE:  Execute
    generic map(
		DATA_BUS_WIDTH 	=> 	DATA_BUS_WIDTH,
		PC_WIDTH 		=>	PC_WIDTH,
		MULT_WIDTH 		=>	MULT_WIDTH
	)
	PORT MAP (	
		--Inputs
		read_data1_i 	=> idex_rdata1_q,
    	read_data2_i 	=> idex_rdata2_q,
		sign_extend_i 	=> idex_signext_q,
		UpperIm_ctrl_i 	=> idex_upperim_q,
		ALUOp_ctrl_i 	=> idex_aluop_q,
		MULOp_ctrl_i 	=> idex_mulop_q,
		ALUSrc_ctrl_i 	=> idex_alusrc_q,
		pc_i			=> idex_pc_q,
		WBSrc_i			=> idex_wbsrc_q,
		mem_res_i		=> mem_mux_res_q,
		wb_res_i		=> wb_mux_res_w,
		ForwardA_i		=> forwardA_w,
		ForwardB_i		=> forwardB_w,
		--Outputs
		brTaken_o 		=> ex_brtaken_w,
    	alu_res_o		=> ex_alures_w,
		addr_gen_o 		=> ex_addrgen_w,
		P0_o 			=> ex_P0_w,			
		P1_o 			=> ex_P1_w,		
		P2_o 			=> ex_P2_w,			
		P3_o 			=> ex_P3_w,
		
		rs2_fwd_o 		=> ex_rs2_fwd_w		
	);
	--=======================================
	-- Hazard module connection
	--=======================================
	Hzrd: HazardUnit
	generic map (
		DATA_BUS_WIDTH
	)
	port map (
		ifid_instuction_i 	=> ifid_instr_q,
		idex_rd_i		  	=> idex_rd_q,
		idex_regwrite_i		=> idex_regwrite_q,
		idex_memread_i		=> idex_memread_q,
		idex_mul_i			=> idex_mul_q,
		stall_o				=> stall_w,
		PCwrite_o 			=> PCwrite_w,
		IFIDwrite_o 		=> IFIDwrite_w
	);
	--=======================================
	-- Forwarding module connection
	--=======================================
	FU: ForwardingUnit
	port map (
		idex_rs1_i			=> idex_rs1_q,
		idex_rs2_i			=> idex_rs2_q,
		exmem_rd_i			=> exmem_rd_q,
		exmem_regwrite_i	=> exmem_regwrite_q,
		memwb_rd_i			=> memwb_rd_q,
		memwb_regwrite_i	=> memwb_regwrite_q,
		forwardA_o			=> forwardA_w,
		forwardB_o			=> forwardB_w
	);
	--=======================================
	-- DTCM module connection
	--=======================================
	G1: 
	if (WORD_GRANULARITY = True) generate -- i.e. each WORD has a unike address
		mem_dtcm_addr_w	<= exmem_alures_q(MA_WIDTH-1 DOWNTO 2); -- increment memory address by 4;
	elsif (WORD_GRANULARITY = False) generate -- i.e. each BYTE has a unike address
		mem_dtcm_addr_w	<= exmem_alures_q(MA_WIDTH-1 DOWNTO 0);
	end generate;
	
	MEM:  dmemory
	generic map(
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH, 
		DTCM_ADDR_WIDTH		=> 	DTCM_ADDR_WIDTH,
		WORDS_NUM			=>	DATA_WORDS_NUM
	)
	PORT MAP (	
		--Inputs
		clk_i 				=> mclk_w,  
		rst_i 				=> rst_i,
		dtcm_addr_i 		=> mem_dtcm_addr_w,
		dtcm_data_wr_i 		=> exmem_rdata2_q,
		MemRead_ctrl_i 		=> exmem_memread_q, 
		MemWrite_ctrl_i 	=> exmem_memwrite_q,
				
		--Outputs
		dtcm_data_rd_o 		=> mem_dtcm_rd_w 
	);
	--=======================================
	-- Multiplication Stage 2
	--=======================================
	MUL: Mul_Stage2
	generic map (
		DATA_BUS_WIDTH 	=> DATA_BUS_WIDTH,
		MULT_WIDTH 		=> MULT_WIDTH
	)
	port map (
		P0_i			=> exmem_P0_q,
		P1_i			=> exmem_P1_q,
		P2_i			=> exmem_P2_q,
		P3_i			=> exmem_P3_q,
		MULOp_ctrl_i	=> exmem_mulop_q,
		Mul_res_o		=> mem_mulres_w
	);

	mem_mux_res_q	<= 	exmem_alures_q when exmem_wbsrc_q else
						mem_mulres_w;
	--=======================================
	-- WriteBack Logic
	--=======================================
	wb_mux_res_w	<= 	memwb_dtcm_rd_w 	when memwb_memtoreg_q
						else memwb_mux_res_q; 
	wbid_mux_res_w 	<= 	ZEROS_DBUS2PCADDR & memwb_pcplus4_q when memwb_regdst_q 	
					 	else wb_mux_res_w;
 	--=======================================
	-- MCLK counter register connection
	--=======================================									
	process (mclk_w , rst_i)
	begin
		if rst_i = '1' then
			mclk_cnt_q	<=	(others	=> '0');
		elsif rising_edge(mclk_w) then
			mclk_cnt_q	<=	mclk_cnt_q + '1';
		end if;
	end process;
	--========================================================================
	-- PIPELINE REGISTERS  (IF/ID | ID/EX | EX/MEM | MEM/WB) + stall/flush counters
	--========================================================================
	PIPE : process (mclk_w, rst_i)
	begin
		if rst_i = '1' then
			------------------------------------------------ IF/ID
			ifid_pc_q        <= (others => '0');
			ifid_pcplus4_q   <= (others => '0');
			ifid_instr_q     <= (others => '0');
			------------------------------------------------ ID/EX
			idex_pc_q        <= (others => '0');
			idex_pcplus4_q   <= (others => '0');
			idex_instr_q     <= (others => '0');
			idex_rdata1_q    <= (others => '0');
			idex_rdata2_q    <= (others => '0');
			idex_signext_q   <= (others => '0');
			idex_rs1_q       <= (others => '0');
			idex_rs2_q       <= (others => '0');
			idex_rd_q        <= (others => '0');
			idex_aluop_q     <= ALU_NONE;
			idex_upperim_q   <= "00";
			idex_mulop_q     <= Multi_NONE;
			idex_alusrc_q    <= '0';
			idex_wbsrc_q     <= '1';
			idex_regwrite_q  <= '0';
			idex_memread_q   <= '0';
			idex_memwrite_q  <= '0';
			idex_memtoreg_q  <= '0';
			idex_regdst_q    <= '0';
			idex_branch_q    <= '0';
			idex_jal_q       <= '0';
			idex_jalr_q      <= '0';
			idex_mul_q       <= '0';
			------------------------------------------------ EX/MEM
			exmem_pc_q       <= (others => '0');
			exmem_pcplus4_q  <= (others => '0');
			exmem_instr_q    <= (others => '0');
			exmem_alures_q   <= (others => '0');
			exmem_rdata2_q   <= (others => '0');
			exmem_addrgen_q  <= (others => '0');
			exmem_P0_q       <= (others => '0');
			exmem_P1_q       <= (others => '0');
			exmem_P2_q       <= (others => '0');
			exmem_P3_q       <= (others => '0');
			exmem_mulop_q    <= Multi_NONE;
			exmem_rd_q       <= (others => '0');
			exmem_regwrite_q <= '0';
			exmem_memread_q  <= '0';
			exmem_memwrite_q <= '0';
			exmem_memtoreg_q <= '0';
			exmem_regdst_q   <= '0';
			exmem_wbsrc_q    <= '1';
			exmem_branch_q   <= '0';
			exmem_jal_q      <= '0';
			exmem_jalr_q     <= '0';
			exmem_brtaken_q  <= '0';
			exmem_mul_q      <= '0';
			------------------------------------------------ MEM/WB
			memwb_pc_q       <= (others => '0');
			memwb_pcplus4_q  <= (others => '0');
			memwb_instr_q    <= (others => '0');
			memwb_mul2_res_w <= (others => '0');
			memwb_dtcm_rd_w  <= (others => '0');
			memwb_rd_q       <= (others => '0');
			memwb_regwrite_q <= '0';
			memwb_wbsrc_q    <= '1';
			memwb_memtoreg_q <= '0';
			memwb_regdst_q   <= '0';
			------------------------------------------------ counters
			clkcnt_q         <= (others => '0');
			stcnt_q          <= (others => '0');
			fhcnt_q          <= (others => '0');

		elsif rising_edge(mclk_w) then
			if STRIGGER_w = '0' then -- Halt the pipeline
				------------------------------------------------ IF/ID  (flush > hold > latch)
				if redirect_w = '1' then
					ifid_instr_q   <= (others => '0');
					ifid_pc_q      <= (others => '0');
					ifid_pcplus4_q <= (others => '0');
				elsif IFIDwrite_w = '0' then            -- stall: hold
					ifid_instr_q   <= ifid_instr_q;
					ifid_pc_q      <= ifid_pc_q;
					ifid_pcplus4_q <= ifid_pcplus4_q;
				else
					ifid_instr_q   <= if_instr_w;
					ifid_pc_q      <= if_pc_w;
					ifid_pcplus4_q <= if_pcplus4_w;
				end if;

				------------------------------------------------ ID/EX  (flush or stall -> bubble)
				if (redirect_w = '1') or (stall_w = '1') then
					idex_instr_q    <= (others => '0');
					idex_pc_q       <= (others => '0');
					idex_pcplus4_q  <= (others => '0');
					idex_rdata1_q   <= (others => '0');
					idex_rdata2_q   <= (others => '0');
					idex_signext_q  <= (others => '0');
					idex_rs1_q      <= (others => '0');
					idex_rs2_q      <= (others => '0');
					idex_rd_q       <= (others => '0');
					idex_aluop_q    <= ALU_NONE;
					idex_upperim_q  <= "00";
					idex_mulop_q    <= Multi_NONE;
					idex_alusrc_q   <= '0';
					idex_wbsrc_q    <= '1';
					idex_regwrite_q <= '0';
					idex_memread_q  <= '0';
					idex_memwrite_q <= '0';
					idex_memtoreg_q <= '0';
					idex_regdst_q   <= '0';
					idex_branch_q   <= '0';
					idex_jal_q      <= '0';
					idex_jalr_q     <= '0';
					idex_mul_q      <= '0';
				else
					idex_instr_q    <= ifid_instr_q;
					idex_pc_q       <= ifid_pc_q;
					idex_pcplus4_q  <= ifid_pcplus4_q;
					idex_rdata1_q   <= id_rdata1_w;
					idex_rdata2_q   <= id_rdata2_w;
					idex_signext_q  <= id_signext_w;
					idex_rs1_q      <= ifid_instr_q(19 downto 15);
					idex_rs2_q      <= ifid_instr_q(24 downto 20);
					idex_rd_q       <= ifid_instr_q(11 downto 7);
					idex_aluop_q    <= id_aluop_w;
					idex_upperim_q  <= id_upperim_w;
					idex_mulop_q    <= id_mulop_w;
					idex_alusrc_q   <= id_alusrc_w;
					idex_wbsrc_q    <= id_wbsrc_w;
					idex_regwrite_q <= id_regwrite_w;
					idex_memread_q  <= id_memread_w;
					idex_memwrite_q <= id_memwrite_w;
					idex_memtoreg_q <= id_memtoreg_w;
					idex_regdst_q   <= id_regdst_w;
					idex_branch_q   <= id_branch_w;
					idex_jal_q      <= id_jal_w;
					idex_jalr_q     <= id_jalr_w;
					idex_mul_q      <= id_mul_w;
				end if;

				------------------------------------------------ EX/MEM  (flush -> bubble)
				if redirect_w = '1' then
					exmem_instr_q    <= (others => '0');
					exmem_pc_q       <= (others => '0');
					exmem_pcplus4_q  <= (others => '0');
					exmem_alures_q   <= (others => '0');
					exmem_rdata2_q   <= (others => '0');
					exmem_addrgen_q  <= (others => '0');
					exmem_P0_q       <= (others => '0');
					exmem_P1_q       <= (others => '0');
					exmem_P2_q       <= (others => '0');
					exmem_P3_q       <= (others => '0');
					exmem_mulop_q    <= Multi_NONE;
					exmem_rd_q       <= (others => '0');
					exmem_regwrite_q <= '0';
					exmem_memread_q  <= '0';
					exmem_memwrite_q <= '0';
					exmem_memtoreg_q <= '0';
					exmem_regdst_q   <= '0';
					exmem_wbsrc_q    <= '1';
					exmem_branch_q   <= '0';
					exmem_jal_q      <= '0';
					exmem_jalr_q     <= '0';
					exmem_brtaken_q  <= '0';
					exmem_mul_q      <= '0';
				else
					exmem_instr_q    <= idex_instr_q;
					exmem_pc_q       <= idex_pc_q;
					exmem_pcplus4_q  <= idex_pcplus4_q;
					exmem_alures_q   <= ex_alures_w;
					exmem_rdata2_q   <= ex_rs2_fwd_w;     
					exmem_addrgen_q  <= ex_addrgen_w;
					exmem_P0_q       <= ex_P0_w;
					exmem_P1_q       <= ex_P1_w;
					exmem_P2_q       <= ex_P2_w;
					exmem_P3_q       <= ex_P3_w;
					exmem_mulop_q    <= idex_mulop_q;
					exmem_rd_q       <= idex_rd_q;
					exmem_regwrite_q <= idex_regwrite_q;
					exmem_memread_q  <= idex_memread_q;
					exmem_memwrite_q <= idex_memwrite_q;
					exmem_memtoreg_q <= idex_memtoreg_q;
					exmem_regdst_q   <= idex_regdst_q;
					exmem_wbsrc_q    <= idex_wbsrc_q;
					exmem_branch_q   <= idex_branch_q;
					exmem_jal_q      <= idex_jal_q;
					exmem_jalr_q     <= idex_jalr_q;
					exmem_brtaken_q  <= ex_brtaken_w;
					exmem_mul_q      <= idex_mul_q;
				end if;

				------------------------------------------------ MEM/WB  (always advances)
				memwb_instr_q    <= exmem_instr_q;
				memwb_pc_q       <= exmem_pc_q;
				memwb_pcplus4_q  <= exmem_pcplus4_q;
				memwb_mul2_res_w <= mem_mulres_w;
				memwb_dtcm_rd_w  <= mem_dtcm_rd_w;
				memwb_rd_q       <= exmem_rd_q;
				memwb_regwrite_q <= exmem_regwrite_q;
				memwb_wbsrc_q    <= exmem_wbsrc_q;
				memwb_memtoreg_q <= exmem_memtoreg_q;
				memwb_regdst_q   <= exmem_regdst_q;
				memwb_mux_res_q	 <= mem_mux_res_q;
				------------------------------------------------ counters
				clkcnt_q <= clkcnt_q + 1;
				if redirect_w = '1' then
					fhcnt_q <= fhcnt_q + 1;
				elsif stall_w = '1' then
					stcnt_q <= stcnt_q + 1;
				end if;
			end if;
		end if;
	end process;


---------------------------------------------------------------------------------------
-- Copying out important signals only for Verification and FPGA Velidation(Signal-TAP)
---------------------------------------------------------------------------------------
-- breakpoint trigger: IF-stage PC word index == BPADDR_i


	STRIGGER_o <= STRIGGER_w;

	CLKCNT_o <= STD_LOGIC_VECTOR(clkcnt_q);
	STCNT_o  <= STD_LOGIC_VECTOR(stcnt_q);
	FHCNT_o  <= STD_LOGIC_VECTOR(fhcnt_q);

	IFpc_o  <= if_pc_w;     
	IFinstruction_o  <= if_instr_w;
	IDpc_o  <= ifid_pc_q;   
	IDinstruction_o  <= ifid_instr_q;
	EXpc_o  <= idex_pc_q;   
	EXinstruction_o  <= idex_instr_q;
	MEMpc_o <= exmem_pc_q;  
	MEMinstruction_o <= exmem_instr_q;
	WBpc_o  <= memwb_pc_q;  
	WBinstruction_o  <= memwb_instr_q;														-- TOP output
	
---------------------------------------------------------------------------------------

END structure;

