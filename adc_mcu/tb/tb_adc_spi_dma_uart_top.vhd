library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_adc_spi_dma_uart_top is
end entity;

architecture tb of tb_adc_spi_dma_uart_top is

  --------------------------------------------------------------------
  -- Clock / Reset
  --------------------------------------------------------------------
  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';

  --------------------------------------------------------------------
  -- DUT I/O
  --------------------------------------------------------------------
  signal adc_sclk : std_logic;
  signal adc_mosi : std_logic;
  signal adc_miso : std_logic := '0';
  signal adc_cs_n : std_logic;

  signal uart_tx  : std_logic;
  signal uart_rx  : std_logic := '1';

  --------------------------------------------------------------------
  -- SPI ADC model
  --------------------------------------------------------------------
  constant C_DATA_WIDTH : integer := 16;
  signal adc_shift_reg  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal bit_index      : integer := 0;

  --------------------------------------------------------------------
  -- UART monitor
  --------------------------------------------------------------------
  constant BIT_TIME : time := 8680 ns; -- 115200 baud @ 50MHz

begin

  --------------------------------------------------------------------
  -- Clock generation (50 MHz)
  --------------------------------------------------------------------
  clk <= not clk after 10 ns;

  --------------------------------------------------------------------
  -- Reset
  --------------------------------------------------------------------
  process
  begin
    rst_n <= '0';
    wait for 300 ns;
    rst_n <= '1';
    wait;
  end process;

  --------------------------------------------------------------------
  -- DUT (TB Wrapper »ç¿ë)
  --------------------------------------------------------------------
  dut : entity work.adc_spi_dma_uart_top_tbwrap
    port map (
      clk       => clk,
      rst_n     => rst_n,
      adc_sclk  => adc_sclk,
      adc_mosi  => adc_mosi,
      adc_miso  => adc_miso,
      adc_cs_n  => adc_cs_n,
      uart_tx   => uart_tx,
      uart_rx   => uart_rx
    );

  --------------------------------------------------------------------
  -- SPI ADC behavior model (FINAL / NO INDEX ERROR)
  --------------------------------------------------------------------
  process
    variable sample_cnt : integer := 0;
    variable bit_idx    : integer := 0;
    variable shift_reg  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  begin
    wait until rst_n = '1';

    while true loop
      --------------------------------------------------------------
      -- Frame start
      --------------------------------------------------------------
      wait until adc_cs_n = '0';

      shift_reg :=
        std_logic_vector(to_unsigned(16#1000# + sample_cnt, C_DATA_WIDTH));
      sample_cnt := sample_cnt + 1;
      bit_idx := 0;

      --------------------------------------------------------------
      -- Shift exactly N bits
      --------------------------------------------------------------
      while bit_idx < C_DATA_WIDTH loop
        wait until falling_edge(adc_sclk);

        exit when adc_cs_n = '1';

        adc_miso <= shift_reg(C_DATA_WIDTH-1-bit_idx);
        bit_idx := bit_idx + 1;
      end loop;

      adc_miso <= '0';
      wait until adc_cs_n = '1';
      wait for 200 ns;
    end loop;
  end process;

 

  --------------------------------------------------------------------
  -- UART TX Monitor
  --------------------------------------------------------------------
  process
    variable rx_byte : std_logic_vector(7 downto 0);
  begin
    wait until rst_n = '1';

    loop
      wait until uart_tx = '0'; -- start bit
      wait for BIT_TIME + BIT_TIME/2;

      for i in 0 to 7 loop
        rx_byte(i) := uart_tx;
        wait for BIT_TIME;
      end loop;

      report "UART TX DATA = "
        & integer'image(to_integer(unsigned(rx_byte)))
        severity note;
    end loop;
  end process;

end architecture;
