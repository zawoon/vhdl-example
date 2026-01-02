library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LED_BLINK is
    Port ( rst_l   : in  STD_LOGIC;
           clk100m : in  STD_LOGIC;
           led     : out STD_LOGIC);
end LED_BLINK;

architecture Behavioral of LED_BLINK is

component my_clk_wiz
port (
   clk_out1 : out std_logic;
   resetn   : in  std_logic;
   locked   : out std_logic;
   clk_in1  : in  std_logic
 );
end component;

signal locked   : std_logic;
signal clk40m   : std_logic;
signal rst      : std_logic;
signal cnt_vect : unsigned(31 downto 0) := (others => '0');

begin

i_my_clk_wiz : my_clk_wiz
   port map (
     clk_out1 => clk40m,
     resetn   => rst_l,
     locked   => locked,
     clk_in1  => clk100m
   );

-- PLL lock 안 됐거나 외부 reset 이 들어오면 rst=1
rst <= (not locked) or (not rst_l);

process(rst, clk40m)
begin
   if rst = '1' then
        cnt_vect <= (others => '0');
   elsif rising_edge(clk40m) then
        cnt_vect <= cnt_vect + 1;
   end if;
end process;

-- 24분주 cnt_vect(23) 연결
led <= cnt_vect(23);

end Behavioral;
