library ieee;
use ieee.std_logic_1164.all;
use work.const_package.all;
entity HazardUnit is
    generic (
        DATA_BUS_WIDTH: integer := 32
    );
    port (
        ifid_instuction_i   : IN    std_logic_vector(DATA_BUS_WIDTH-1 downto 0);
        idex_rd_i           : IN    std_logic_vector(4 downto 0);
        idex_regwrite_i	    : IN	STD_LOGIC;
		idex_memread_i		: IN	STD_LOGIC;
		idex_mul_i		    : IN    STD_LOGIC;
		stall_o				: OUT   STD_LOGIC;
		PCwrite_o			: OUT   STD_LOGIC;
		IFIDwrite_o			: OUT   STD_LOGIC
    );
end HazardUnit;

architecture rtl of HazardUnit is
    signal opc_w        : std_logic_vector(6 downto 0);
    signal rs1_w        : std_logic_vector(4 downto 0);
    signal rs2_w        : std_logic_vector(4 downto 0);
    signal use_rs1_w    : std_logic;
    signal use_rs2_w    : std_logic;
    signal noForward_w   : std_logic;
begin
    opc_w <= ifid_instuction_i(6 downto 0);
    rs1_w <= ifid_instuction_i(19 downto 15);
    rs2_w <= ifid_instuction_i(24 downto 20);

    use_rs1_w <= '0' when ((opc_w and UTYPE_OPC) = UTYPE_OPC or opc_w = UJTYPE_OPC) else '1';
    use_rs2_w <= '1' when (opc_w = RTYPE_OPC or opc_w = SBTYPE_OPC or opc_w = STYPE_OPC) else '0';

    noForward_w <= idex_regwrite_i AND idex_memread_i;

    stall_o <= '1' when (noForward_w = '1' and idex_rd_i /= "00000" and
                        ((idex_rd_i = rs1_w and use_rs1_w = '1')
                        or (idex_rd_i = rs2_w and use_rs2_w = '1'))) else '0';
                            
    PCwrite_o   <= not stall_o;
    IFIDwrite_o <= not stall_o;

end architecture;