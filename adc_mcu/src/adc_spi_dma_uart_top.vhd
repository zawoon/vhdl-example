library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_spi_dma_uart_top is
  generic (
    G_SAMPLE_WIDTH      : integer := 16;
    G_FIFO_DEPTH        : integer := 1024;
    G_FIFO_ADDR_WIDTH   : integer := 10;   -- 1024 -> 10bit
    G_REG_ADDR_WIDTH    : integer := 8;    -- 256 regs
    G_REG_DATA_WIDTH    : integer := 32
  );
  port (
    clk    : in  std_logic;   -- system clock
    rst_n  : in  std_logic;   -- active-low reset

    -- SPI (ADC)
    adc_sclk  : out std_logic;
    adc_mosi  : out std_logic;
    adc_miso  : in  std_logic;
    adc_cs_n  : out std_logic;

    -- UART
    uart_tx   : out std_logic;
    uart_rx   : in  std_logic
  );
end entity;

architecture rtl of adc_spi_dma_uart_top is

  ---------------------------------------------------------------------------
  -- SPI -> FIFO
  ---------------------------------------------------------------------------
  signal sample_data   : std_logic_vector(G_SAMPLE_WIDTH-1 downto 0);
  signal sample_valid  : std_logic;

  signal fifo_wr_en    : std_logic;
  signal fifo_rd_en    : std_logic;
  signal fifo_din      : std_logic_vector(G_SAMPLE_WIDTH-1 downto 0);
  signal fifo_dout     : std_logic_vector(G_SAMPLE_WIDTH-1 downto 0);
  signal fifo_full     : std_logic;
  signal fifo_empty    : std_logic;

  ---------------------------------------------------------------------------
  -- reg_file signals
  ---------------------------------------------------------------------------
  signal reg_addr      : std_logic_vector(G_REG_ADDR_WIDTH-1 downto 0);
  signal reg_wrdata    : std_logic_vector(G_REG_DATA_WIDTH-1 downto 0);
  signal reg_rddata    : std_logic_vector(G_REG_DATA_WIDTH-1 downto 0);
  signal reg_we        : std_logic;
  signal reg_re        : std_logic;

  ---------------------------------------------------------------------------
  -- internal control signals
  ---------------------------------------------------------------------------
  signal spi_ctrl_word : std_logic_vector(31 downto 0);
  signal spi_clkdiv    : std_logic_vector(15 downto 0);

  signal uart_tx_start : std_logic;
  signal uart_tx_data  : std_logic_vector(7 downto 0);
  signal uart_tx_busy  : std_logic;

begin

  ---------------------------------------------------------------------------
  -- (간단 동작용 기본값)
  -- 필요하면 internal_mcu_ctrl에서 레지스터 읽어서 spi_ctrl_word/spi_clkdiv 갱신하도록 확장 가능
  ---------------------------------------------------------------------------
  spi_ctrl_word <= x"80000000";   -- bit31=1 enable (가정)
  spi_clkdiv    <= x"0009";       -- 분주값 예시

  ---------------------------------------------------------------------------
  -- ADC SPI Master
  ---------------------------------------------------------------------------
  u_adc_spi : entity work.adc_spi_master
    generic map (
      G_DATA_WIDTH => G_SAMPLE_WIDTH
    )
    port map (
      clk          => clk,
      rst_n        => rst_n,

      reg_adc_ctrl => spi_ctrl_word,
      reg_clk_div  => spi_clkdiv,

      spi_sclk     => adc_sclk,
      spi_mosi     => adc_mosi,
      spi_miso     => adc_miso,
      spi_cs_n     => adc_cs_n,

      sample_data  => sample_data,
      sample_valid => sample_valid
    );

  fifo_din   <= sample_data;
  fifo_wr_en <= sample_valid and (not fifo_full);

  ---------------------------------------------------------------------------
  -- DMA FIFO
  ---------------------------------------------------------------------------
  u_dma_fifo : entity work.dma_fifo
    generic map (
      G_DATA_WIDTH => G_SAMPLE_WIDTH,
      G_DEPTH      => G_FIFO_DEPTH,
      G_ADDR_WIDTH => G_FIFO_ADDR_WIDTH
    )
    port map (
      clk     => clk,
      rst_n   => rst_n,

      wr_en   => fifo_wr_en,
      wr_data => fifo_din,

      rd_en   => fifo_rd_en,
      rd_data => fifo_dout,

      empty   => fifo_empty,
      full    => fifo_full
    );

  ---------------------------------------------------------------------------
  -- Register file (optional)
  ---------------------------------------------------------------------------
  u_reg_file : entity work.reg_file_bram
    generic map (
      G_ADDR_WIDTH => G_REG_ADDR_WIDTH,
      G_DATA_WIDTH => G_REG_DATA_WIDTH
    )
    port map (
      clk     => clk,
      addr    => reg_addr,
      wr_data => reg_wrdata,
      rd_data => reg_rddata,
      we      => reg_we,
      re      => reg_re
    );

  ---------------------------------------------------------------------------
  -- Internal MCU control (FIFO -> UART)
  ---------------------------------------------------------------------------
  u_internal_mcu : entity work.internal_mcu_ctrl
    generic map (
      G_REG_ADDR_WIDTH => G_REG_ADDR_WIDTH,
      G_REG_DATA_WIDTH => G_REG_DATA_WIDTH,
      G_SAMPLE_WIDTH   => G_SAMPLE_WIDTH
    )
    port map (
      clk        => clk,
      rst_n      => rst_n,

      reg_addr   => reg_addr,
      reg_wrdata => reg_wrdata,
      reg_rddata => reg_rddata,
      reg_we     => reg_we,
      reg_re     => reg_re,

      fifo_rd_en => fifo_rd_en,
      fifo_dout  => fifo_dout,
      fifo_empty => fifo_empty,

      uart_tx_start => uart_tx_start,
      uart_tx_data  => uart_tx_data,
      uart_tx_busy  => uart_tx_busy
    );

  ---------------------------------------------------------------------------
  -- UART TX
  ---------------------------------------------------------------------------
  u_uart_tx : entity work.uart_tx_simple
    generic map (
      G_CLK_FREQ  => 50_000_000,
      G_BAUD_RATE => 115200
    )
    port map (
      clk      => clk,
      rst_n    => rst_n,
      tx_start => uart_tx_start,
      tx_data  => uart_tx_data,
      tx_busy  => uart_tx_busy,
      txd      => uart_tx
    );

end architecture;

