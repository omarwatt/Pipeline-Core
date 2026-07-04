LIBRARY IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE work.const_package.all;

entity Mul_Stage2 is
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
end Mul_Stage2;
architecture rtl of Mul_Stage2 is
    SIGNAL M_w          : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL MULTI_res_r  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
begin
    M_w <= ('0' & P1_i) + ('0' & P2_i);
    process(all)
    begin
        case MULOp_ctrl_i is
                when  Multi_Mul =>
                    MULTI_res_r <= (X"0000" & P0_i) + ("0000000" & M_w & x"00") + (P3_i & x"0000");
                when others =>
                    MULTI_res_r <= (others => '0');
        end case;
    end process;
    Mul_res_o <= MULTI_res_r;
end architecture;