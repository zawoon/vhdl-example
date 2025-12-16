library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    port (
        clk        : in  std_logic;                 -- 40MHz 시스템 클록
        rst        : in  std_logic;                 -- High active reset

        -- 전송 제어
        tx_start   : in  std_logic;                 -- 1 → 전송 시작
        tx_data    : in  std_logic_vector(7 downto 0); -- 전송할 8비트 데이터
        tx_busy    : out std_logic;                 -- 전송 중 = 1

        -- 수신 데이터
        rx_data    : out std_logic_vector(7 downto 0);
        rx_valid   : out std_logic;

        -- SPI 신호
        sclk       : out std_logic;
        mosi       : out std_logic;
        miso       : in  std_logic;
        ss_n       : out std_logic                  -- Slave Select (active low)
    );
end entity spi_master;

architecture rtl of spi_master is

    --------------------------------------------------------------------
    -- SPI 클록 분주기 (40MHz → 1MHz)
    -- SCLK_HALF = 20
    -- SCLK = 40MHz / (2 * SCLK_HALF) = 1MHz
    --------------------------------------------------------------------
    constant SCLK_HALF : integer := 20;
    signal div_cnt     : unsigned(7 downto 0) := (others => '0');

    signal sclk_reg  : std_logic := '0';
    signal sclk_div  : std_logic := '0';

    --------------------------------------------------------------------
    -- SPI FSM
    --------------------------------------------------------------------
    type state_t is (IDLE, LOAD, TRANSFER, DONE);
    signal state : state_t := IDLE;

    signal bit_cnt  : unsigned(3 downto 0) := (others => '0');
    signal tx_shift : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_shift : std_logic_vector(7 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- SCLK 분주기 (Mode 0: idle=Low)
    --------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            div_cnt  <= (others => '0');
            sclk_reg <= '0';
        elsif rising_edge(clk) then
            if state = TRANSFER then
                if div_cnt = SCLK_HALF-1 then
                    div_cnt  <= (others => '0');
                    sclk_reg <= not sclk_reg;    -- toggle SCLK
                else
                    div_cnt <= div_cnt + 1;
                end if;
            else
                sclk_reg <= '0';                 -- IDLE 시 Low
                div_cnt  <= (others => '0');
            end if;
        end if;
    end process;

    sclk <= sclk_reg;

    --------------------------------------------------------------------
    -- SPI 상태기 (4단계)
    --------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state    <= IDLE;
            ss_n     <= '1';
            tx_busy  <= '0';
            rx_valid <= '0';
            bit_cnt  <= (others => '0');
            tx_shift <= (others => '0');
            rx_shift <= (others => '0');

        elsif rising_edge(clk) then

            rx_valid <= '0';  -- 기본값

            case state is

                --------------------------------------------------------
                -- 1) IDLE : tx_start를 기다림
                --------------------------------------------------------
                when IDLE =>
                    ss_n    <= '1';
                    tx_busy <= '0';

                    if tx_start = '1' then
                        state <= LOAD;
                    end if;

                --------------------------------------------------------
                -- 2) LOAD : 전송 준비
                --------------------------------------------------------
                when LOAD =>
                    ss_n     <= '0';                 -- Slave 선택
                    tx_shift <= tx_data;             -- MOSI 시프트 레지스터 로드
                    rx_shift <= (others => '0');
                    bit_cnt  <= (others => '0');
                    tx_busy  <= '1';
                    state    <= TRANSFER;

                --------------------------------------------------------
                -- 3) TRANSFER : Mode 0
                --   - SCLK falling edge: MOSI 갱신
                --   - SCLK rising edge:  MISO 샘플링
                --------------------------------------------------------
                when TRANSFER =>
                    -- Falling edge: MOSI 출력 갱신
                    if sclk_reg = '0' and div_cnt = 0 then
                        mosi <= tx_shift(7);
                    end if;

                    -- Rising edge: MISO 샘플
                    if sclk_reg = '1' and div_cnt = 0 then
                        rx_shift <= rx_shift(6 downto 0) & miso;

                        if bit_cnt = 7 then
                            state <= DONE;
                        else
                            bit_cnt <= bit_cnt + 1;
                            tx_shift <= tx_shift(6 downto 0) & '0';
                        end if;
                    end if;

                --------------------------------------------------------
                -- 4) DONE : 1바이트 완료
                --------------------------------------------------------
                when DONE =>
                    ss_n    <= '1';
                    tx_busy <= '0';
                    rx_valid <= '1';
                    rx_data <= rx_shift;
                    state   <= IDLE;

            end case;
        end if;
    end process;

end architecture rtl;
