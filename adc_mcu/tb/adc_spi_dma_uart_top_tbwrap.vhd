library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_spi_dma_uart_top_tbwrap is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    adc_sclk  : out std_logic;
    adc_mosi  : out std_logic;
    adc_miso  : in  std_logic;
    adc_cs_n  : out std_logic;

    uart_tx   : out std_logic;
    uart_rx   : in  std_logic
  );
end entity;

architecture tbwrap of adc_spi_dma_uart_top_tbwrap is
begin

  u_dut : entity work.adc_spi_dma_uart_top
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

end architecture;

