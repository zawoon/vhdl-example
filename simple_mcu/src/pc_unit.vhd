library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pc_unit is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;               -- active-low reset
        inc_en   : in  std_logic;               -- 1이면 PC <= PC + 1
        load_en  : in  std_logic;               -- 1이면 PC <= load_val
        load_val : in  unsigned(3 downto 0);    -- 점프 주소
        pc_out   : out unsigned(3 downto 0)     -- 현재 PC
    );
end entity pc_unit;

architecture rtl of pc_unit is
    signal pc_reg : unsigned(3 downto 0) := (others => '0');
begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            pc_reg <= (others => '0');
        elsif rising_edge(clk) then
            if load_en = '1' then
                pc_reg <= load_val;
            elsif inc_en = '1' then
                pc_reg <= pc_reg + 1;
            end if;
        end if;
    end process;

    pc_out <= pc_reg;
end architecture rtl;

