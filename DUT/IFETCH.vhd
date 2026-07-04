LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


ENTITY Ifetch IS
	generic(
		WORD_GRANULARITY 	: boolean	:= False;
		DATA_BUS_WIDTH 		: integer	:= 32;
		PC_WIDTH 			: integer	:= 10;
		ITCM_ADDR_WIDTH 	: integer	:= 8;
		WORDS_NUM 			: integer	:= 256
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
END Ifetch;


ARCHITECTURE behavior OF Ifetch IS
	SIGNAL pc_q				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_q		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_r 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL itcm_addr_w		: STD_LOGIC_VECTOR(ITCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL next_pc_w  		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL rst_q  			: STD_LOGIC;
	SIGNAL STRIGGER_w  		: STD_LOGIC;
	SIGNAL BPADDR_q  		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	
BEGIN
	--=======================================
	-- ITCM (ROM) connection
	--=======================================
	inst_memory: altsyncram
	GENERIC MAP (
		operation_mode			=> "ROM",
		width_a 				=> DATA_BUS_WIDTH,
		widthad_a 				=> ITCM_ADDR_WIDTH,
		numwords_a 				=> WORDS_NUM,
		lpm_hint 				=> "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = ITCM",
		lpm_type 				=> "altsyncram",
		outdata_reg_a 			=> "UNREGISTERED",
		init_file 				=> "C:\Users\omar_\Desktop\CPU LAB\Lab5\tests\test1\RV32IM\man_compiled\bin\M9K-intel\ITCM.hex",
		intended_device_family	=> "Cyclone"
	)
	PORT MAP (
		clock0    	=> clk_i,
		address_a	=> itcm_addr_w,  
		q_a 	   	=> instruction_o 
	);
-------------------------------------------------------------------------------------
-- rst_i synchronization
-------------------------------------------------------------------------------------
PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			rst_q <= '1';	-- preset
		ELSIF(clk_i'EVENT  AND clk_i='1') THEN
			rst_q <= rst_i;
		END IF;
END PROCESS;

-----------------------------------------------------------------------------------		
	-- Adder to execute PC+4
  	pc_plus4_r(PC_WIDTH-1 DOWNTO 0)	<= next_pc_w(PC_WIDTH-1 DOWNTO 0) + 4;

	STRIGGER_w 	<= '1' when pc_q(PC_WIDTH-1 DOWNTO 2) = BPADDR_q ELSE '0';
	STRIGGER_o 	<= STRIGGER_w;
-----------------------------------------------------------------------------------
	-- Decision MUX for the next PC value
	next_pc_w	<=	(others => '0') WHEN rst_q 				ELSE
					pc_q 			WHEN STRIGGER_w = '1'	ELSE
					redirect_pc_i 	WHEN redirect_i = '1' 	ELSE
					pc_q 			WHEN PCwrite_i = '0' 	ELSE
					pc_plus4_q;		
								
-----------------------------------------------------------------------------------
-- pc_plus4 register
-------------------------------------------------------------------------------------
PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			pc_plus4_q(PC_WIDTH-1 DOWNTO 0) <= (OTHERS => '0') ; 
		ELSIF(clk_i'EVENT  AND clk_i='1') THEN
			pc_plus4_q(PC_WIDTH-1 DOWNTO 0) <= pc_plus4_r;	
		END IF;
END PROCESS;

-----------------------------------------------------------------------------------
-- pc register
-------------------------------------------------------------------------------------
PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			pc_q(PC_WIDTH-1 DOWNTO 0) <= (OTHERS => '0') ; 
		ELSIF(clk_i'EVENT  AND clk_i='1') THEN
			pc_q(PC_WIDTH-1 DOWNTO 0) <= next_pc_w;	
		END IF;
END PROCESS;
-----------------------------------------------------------------------------------
-- BP register
-------------------------------------------------------------------------------------
PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			BPADDR_q 	<= (others => '0'); 
		ELSIF(clk_i'EVENT  AND clk_i='1') THEN
			BPADDR_q	<= BPADDR_i;
		END IF;
END PROCESS;
-----------------------------------------------------------------------------------	
	-- send address to inst. memory address register
	G1: 
	if (WORD_GRANULARITY = True) generate 			-- i.e. each WORD has unike address
		itcm_addr_w <= next_pc_w(PC_WIDTH-1 DOWNTO 2);
	elsif (WORD_GRANULARITY = False) generate 	-- i.e. each BYTE has unike address
		itcm_addr_w <= next_pc_w;
	end generate;
---------------------------------------------------------------------------------------
	pc_o 		<= 	pc_q;
	pc_plus4_o	<= 	pc_plus4_q;	
---------------------------------------------------------------------------------------
	
END behavior;


