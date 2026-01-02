library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx_simple is
  generic (
    G_CLK_FREQ  : integer := 50_000_000;
    G_BAUD_RATE : integer := 115200
  );
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    tx_start : in  std_logic;
    tx_data  : in  std_logic_vector(7 downto 0);
    tx_busy  : out std_logic;
    txd      : out std_logic
  );
end entity;

architecture rtl of uart_tx_simple is

  constant C_DIVISOR : integer := G_CLK_FREQ / G_BAUD_RATE;

  type t_state is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
  signal state    : t_state := IDLE;

  signal bit_cnt  : integer range 0 to 7 := 0;
  signal baud_cnt : integer range 0 to C_DIVISOR := 0;
  signal tx_reg   : std_logic_vector(7 downto 0) := (others => '0');
  signal txd_reg  : std_logic := '1';
  signal busy_reg : std_logic := '0';

begin

  txd   <= txd_reg;
  tx_busy <= busy_reg;

  process(clk, rst_n)
  begin
    if rst_n = '0' then
      state    <= IDLE;
      baud_cnt <= 0;
      bit_cnt  <= 0;
      tx_reg   <= (others => '0');
      txd_reg  <= '1';
      busy_reg <= '0';
    elsif rising_edge(clk) then

      case state is

        when IDLE =>
          busy_reg <= '0';
          txd_reg  <= '1';
          baud_cnt <= 0;
          bit_cnt  <= 0;
          if tx_start = '1' then
            tx_reg   <= tx_data;
            busy_reg <= '1';
            state    <= START_BIT;
          end if;

        when START_BIT =>
          if baud_cnt = C_DIVISOR-1 then
            baud_cnt <= 0;
            txd_reg  <= '0';  -- start bit
            state    <= DATA_BITS;
          else
            baud_cnt <= baud_cnt + 1;
          end if;

        when DATA_BITS =>
          if baud_cnt = C_DIVISOR-1 then
            baud_cnt <= 0;
            txd_reg  <= tx_reg(bit_cnt);
            if bit_cnt = 7 then
              bit_cnt <= 0;
              state   <= STOP_BIT;
            else
              bit_cnt <= bit_cnt + 1;
            end if;
          else
            baud_cnt <= baud_cnt + 1;
          end if;

        when STOP_BIT =>
          if baud_cnt = C_DIVISOR-1 then
            baud_cnt <= 0;
            txd_reg  <= '1';  -- stop bit
            state    <= IDLE;
          else
            baud_cnt <= baud_cnt + 1;
          end if;

        when others =>
          state <= IDLE;

      end case;
    end if;
  end process;

end architecture;

