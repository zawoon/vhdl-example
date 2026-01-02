library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity internal_mcu_ctrl is
  generic (
    G_REG_ADDR_WIDTH : integer := 8;
    G_REG_DATA_WIDTH : integer := 32;
    G_SAMPLE_WIDTH   : integer := 16
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;

    -- reg_file 인터페이스
    reg_addr   : out std_logic_vector(G_REG_ADDR_WIDTH-1 downto 0);
    reg_wrdata : out std_logic_vector(G_REG_DATA_WIDTH-1 downto 0);
    reg_rddata : in  std_logic_vector(G_REG_DATA_WIDTH-1 downto 0);
    reg_we     : out std_logic;
    reg_re     : out std_logic;

    -- FIFO 인터페이스 (ADC 샘플 읽기용)
    fifo_rd_en : out std_logic;
    fifo_dout  : in  std_logic_vector(G_SAMPLE_WIDTH-1 downto 0);
    fifo_empty : in  std_logic;

    -- UART 송신 인터페이스
    uart_tx_start : out std_logic;
    uart_tx_data  : out std_logic_vector(7 downto 0);
    uart_tx_busy  : in  std_logic
  );
end entity;

architecture rtl of internal_mcu_ctrl is

  type t_state is (
    S_RESET,
    S_LOAD_CONFIG,
    S_IDLE,
    S_READ_FIFO,
    S_SEND_HIGH_BYTE,
    S_SEND_LOW_BYTE
  );
  signal state      : t_state := S_RESET;

  signal sample_reg : std_logic_vector(G_SAMPLE_WIDTH-1 downto 0) := (others => '0');

  -- 레지스터 주소 상수 (예시)
  constant C_ADDR_ADC_CTRL   : std_logic_vector(G_REG_ADDR_WIDTH-1 downto 0) := x"00";
  constant C_ADDR_ADC_CLKDIV : std_logic_vector(G_REG_ADDR_WIDTH-1 downto 0) := x"04";
  constant C_ADDR_UART_CTRL  : std_logic_vector(G_REG_ADDR_WIDTH-1 downto 0) := x"10";

  -- 내부용 출력 기본값
begin

  process(clk, rst_n)
  begin
    if rst_n = '0' then
      state        <= S_RESET;
      reg_addr     <= (others => '0');
      reg_wrdata  <= (others => '0');
      reg_we     <= '0';
      reg_re      <= '0';
      fifo_rd_en   <= '0';
      uart_tx_start <= '0';
      uart_tx_data <= (others => '0');
      sample_reg   <= (others => '0');
    elsif rising_edge(clk) then

      -- 기본값
      reg_we     <= '0';
      reg_re      <= '0';
      fifo_rd_en   <= '0';
      uart_tx_start <= '0';

      case state is

        -------------------------------------------------------------------
        when S_RESET =>
          -- 필요하면 초기 레지스터 쓰기도 가능
          -- 예: SPI enable 비트 세팅
          reg_addr   <= C_ADDR_ADC_CTRL;
          reg_wrdata <= x"80000000";  -- bit31=1: enable (예시)
          reg_we     <= '1';
          state      <= S_LOAD_CONFIG;

        -------------------------------------------------------------------
        when S_LOAD_CONFIG =>
          -- 예: ADC_CLKDIV, UART_CTRL 등 읽기 (여기선 단순히 읽기 요청만)
          reg_addr <= C_ADDR_ADC_CLKDIV;
          reg_re   <= '1';
          -- reg_rddata는 다음 사이클에서 유효 → 실제로는 별도 레지스터에 저장 가능
          state    <= S_IDLE;

        -------------------------------------------------------------------
        when S_IDLE =>
          -- FIFO에 데이터가 있으면 읽어서 UART로 전송
          if fifo_empty = '0' and uart_tx_busy = '0' then
            fifo_rd_en <= '1';
            state      <= S_READ_FIFO;
          end if;

        -------------------------------------------------------------------
        when S_READ_FIFO =>
          -- 이전 사이클 fifo_rd_en=1 → 지금 fifo_dout 유효하다고 가정
          sample_reg <= fifo_dout;
          state      <= S_SEND_HIGH_BYTE;

        -------------------------------------------------------------------
        when S_SEND_HIGH_BYTE =>
          if uart_tx_busy = '0' then
            uart_tx_data  <= sample_reg(G_SAMPLE_WIDTH-1 downto 8);
            uart_tx_start <= '1';
            state         <= S_SEND_LOW_BYTE;
          end if;

        -------------------------------------------------------------------
        when S_SEND_LOW_BYTE =>
          if uart_tx_busy = '0' then
            uart_tx_data  <= sample_reg(7 downto 0);
            uart_tx_start <= '1';
            state         <= S_IDLE;
          end if;

        -------------------------------------------------------------------
        when others =>
          state <= S_IDLE;

      end case;
    end if;
  end process;

end architecture;

