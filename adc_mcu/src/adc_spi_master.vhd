library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_spi_master is
  generic (
    G_DATA_WIDTH : integer := 16
  );
  port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;

    reg_adc_ctrl : in  std_logic_vector(31 downto 0);  -- bit31: enable
    reg_clk_div  : in  std_logic_vector(15 downto 0);  -- 분주값

    spi_sclk     : out std_logic;
    spi_mosi     : out std_logic;
    spi_miso     : in  std_logic;
    spi_cs_n     : out std_logic;

    sample_data  : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    sample_valid : out std_logic
  );
end entity;

architecture rtl of adc_spi_master is

  type t_state is (IDLE, ASSERT_CS, SHIFT, DONE);
  signal state       : t_state := IDLE;

  signal bit_cnt     : integer range 0 to G_DATA_WIDTH := 0;
  signal shreg       : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
  signal sclk_reg    : std_logic := '0';
  signal cs_n_reg    : std_logic := '1';
  signal sample_reg  : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
  signal sample_v    : std_logic := '0';

  signal clk_div_cnt : unsigned(15 downto 0) := (others => '0');
  signal sclk_en     : std_logic := '0';

begin

  spi_sclk    <= sclk_reg;
  spi_cs_n    <= cs_n_reg;
  spi_mosi    <= '0';  -- 입력 전용 ADC라 가정
  sample_data <= sample_reg;
  sample_valid<= sample_v;

  -- SCLK 분주기
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      clk_div_cnt <= (others => '0');
      sclk_en     <= '0';
    elsif rising_edge(clk) then
      if clk_div_cnt = unsigned(reg_clk_div) then
        clk_div_cnt <= (others => '0');
        sclk_en     <= '1';
      else
        clk_div_cnt <= clk_div_cnt + 1;
        sclk_en     <= '0';
      end if;
    end if;
  end process;

  -- SPI 상태머신
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      state      <= IDLE;
      sclk_reg   <= '0';
      cs_n_reg   <= '1';
      bit_cnt    <= 0;
      shreg      <= (others => '0');
      sample_reg <= (others => '0');
      sample_v   <= '0';
    elsif rising_edge(clk) then
      sample_v <= '0';

      case state is
        when IDLE =>
          if reg_adc_ctrl(31) = '1' then
            cs_n_reg <= '0';
            bit_cnt  <= G_DATA_WIDTH;
            state    <= ASSERT_CS;
          end if;

        when ASSERT_CS =>
          if sclk_en = '1' then
            sclk_reg <= not sclk_reg;
            state    <= SHIFT;
          end if;

        when SHIFT =>
          if sclk_en = '1' then
            sclk_reg <= not sclk_reg;

            if sclk_reg = '1' then
              -- falling edge에서 샘플링 (모드에 맞게 조정)
              shreg   <= shreg(G_DATA_WIDTH-2 downto 0) & spi_miso;
              bit_cnt <= bit_cnt - 1;
              if bit_cnt = 1 then
                state <= DONE;
              end if;
            end if;
          end if;

        when DONE =>
          cs_n_reg   <= '1';
          sample_reg <= shreg;
          sample_v   <= '1';
          state      <= IDLE;

        when others =>
          state <= IDLE;
      end case;
    end if;
  end process;

end architecture;

