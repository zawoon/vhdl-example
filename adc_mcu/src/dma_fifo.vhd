library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simple single-clock synchronous FIFO (synthesizable)
entity dma_fifo is
  generic (
    G_DATA_WIDTH : integer := 16;
    G_DEPTH      : integer := 1024; -- number of words
    G_ADDR_WIDTH : integer := 10    -- log2(G_DEPTH) (1024 -> 10)
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;  -- active-low synchronous reset

    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);

    rd_en   : in  std_logic;
    rd_data : out std_logic_vector(G_DATA_WIDTH-1 downto 0);

    empty   : out std_logic;
    full    : out std_logic
  );
end entity;

architecture rtl of dma_fifo is
  type ram_t is array (0 to G_DEPTH-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal ram       : ram_t;

  signal wr_ptr    : unsigned(G_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal rd_ptr    : unsigned(G_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal count     : unsigned(G_ADDR_WIDTH downto 0)   := (others => '0'); -- 0..G_DEPTH

  signal empty_i   : std_logic;
  signal full_i    : std_logic;

  signal rd_data_r : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
begin
  rd_data <= rd_data_r;

  -- status (internal)
  empty_i <= '1' when count = 0 else '0';
  full_i  <= '1' when count = to_unsigned(G_DEPTH, count'length) else '0';

  -- status (outputs)
  empty <= empty_i;
  full  <= full_i;

  process(clk)
    variable wr_fire    : boolean;
    variable rd_fire    : boolean;
    variable next_count : integer;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        wr_ptr    <= (others => '0');
        rd_ptr    <= (others => '0');
        count     <= (others => '0');
        rd_data_r <= (others => '0');
      else
        wr_fire := (wr_en = '1') and (full_i  = '0');
        rd_fire := (rd_en = '1') and (empty_i = '0');

        -- write
        if wr_fire then
          ram(to_integer(wr_ptr)) <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end if;

        -- read
        if rd_fire then
          rd_data_r <= ram(to_integer(rd_ptr));
          rd_ptr <= rd_ptr + 1;
        end if;

        -- update count (handles simultaneous read+write)
        next_count := to_integer(count);
        if wr_fire then
          next_count := next_count + 1;
        end if;
        if rd_fire then
          next_count := next_count - 1;
        end if;

        -- safety clamp
        if next_count < 0 then
          next_count := 0;
        elsif next_count > G_DEPTH then
          next_count := G_DEPTH;
        end if;

        count <= to_unsigned(next_count, count'length);
      end if;
    end if;
  end process;

end architecture;

