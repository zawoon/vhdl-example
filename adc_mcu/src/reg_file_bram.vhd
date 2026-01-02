library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_file_bram is
  generic (
    G_ADDR_WIDTH : integer := 8;   -- 256 x 32bit
    G_DATA_WIDTH : integer := 32
  );
  port (
    clk     : in  std_logic;
    addr    : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    wr_data : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
    rd_data : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    we      : in  std_logic;
    re      : in  std_logic
  );
end entity;

architecture rtl of reg_file_bram is

  constant C_DEPTH : integer := 2**G_ADDR_WIDTH;

  type ram_type is array (0 to C_DEPTH-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal ram : ram_type := (others => (others => '0'));
  -- 실제 구현에서는 Block RAM + COE 초기화로 대체하고,
  -- 이 부분은 inference 또는 IP로 교체하면 됩니다.

  signal addr_reg : integer range 0 to C_DEPTH-1 := 0;

begin

  process (clk)
  begin
    if rising_edge(clk) then
      addr_reg <= to_integer(unsigned(addr));

      if we = '1' then
        ram(addr_reg) <= wr_data;
      end if;

      if re = '1' then
        rd_data <= ram(addr_reg);
      end if;
    end if;
  end process;

end architecture;

