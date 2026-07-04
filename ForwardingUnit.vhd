LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
 
ENTITY ForwardingUnit IS
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
END ForwardingUnit;
 
ARCHITECTURE rtl OF ForwardingUnit IS
BEGIN
	forwardA_o <=
		"10" WHEN (exmem_regwrite_i = '1'
				   AND exmem_rd_i /= "00000" AND exmem_rd_i = idex_rs1_i) ELSE
		"01" WHEN (memwb_regwrite_i = '1'
				   AND memwb_rd_i /= "00000" AND memwb_rd_i = idex_rs1_i) ELSE
		"00";
 
	forwardB_o <=
		"10" WHEN (exmem_regwrite_i = '1'
				   AND exmem_rd_i /= "00000" AND exmem_rd_i = idex_rs2_i) ELSE
		"01" WHEN (memwb_regwrite_i = '1'
				   AND memwb_rd_i /= "00000" AND memwb_rd_i = idex_rs2_i) ELSE
		"00";
END rtl;