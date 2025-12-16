library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rxd is
    Port (
        rst_l    : in  STD_LOGIC;                    -- 외부 리셋 (Low active)
        clk100m  : in  STD_LOGIC;                    -- 100MHz 입력 클록
        rxd      : in  STD_LOGIC;                    -- UART RX 입력
        rx_data  : out STD_LOGIC_VECTOR(7 downto 0); -- 수신한 1바이트 데이터
        rx_valid : out STD_LOGIC                     -- 데이터 유효 펄스 (1 클록)
    );
end uart_rxd;

architecture Behavioral of uart_rxd is

    --------------------------------------------------------------------
    -- Clock Wizard (PLL) : 100MHz → 40MHz
    --------------------------------------------------------------------
    component my_clk_wiz
        port (
            clk_out1 : out std_logic;
            resetn   : in  std_logic;
            locked   : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;

    signal clk40m : std_logic;
    signal locked : std_logic;
    signal rst    : std_logic;  -- 내부 리셋 (High active)

    --------------------------------------------------------------------
    -- UART 설정 : 115200 bps, 8N1
    -- 40MHz / 115200 ≒ 347.2
    --------------------------------------------------------------------
    constant BAUD_DIV   : integer := 347;
    constant BAUD_DIV_U : unsigned(15 downto 0)
        := to_unsigned(BAUD_DIV - 1, 16);
    constant HALF_DIV_U : unsigned(15 downto 0)
        := to_unsigned(BAUD_DIV / 2, 16);

    signal sample_cnt : unsigned(15 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- UART 수신 상태기
    --------------------------------------------------------------------
    type rx_state_t is (RX_IDLE, RX_START, RX_DAT, RX_STOP);
    signal state     : rx_state_t := RX_IDLE;

    signal bit_index    : unsigned(2 downto 0) := (others => '0');  -- 0~7
    signal rx_shift     : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_reg       : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid_reg : std_logic := '0';

    --------------------------------------------------------------------
    -- RX 입력 동기화 (메타안정성 방지)
    --------------------------------------------------------------------
    signal rxd_sync1 : std_logic := '1';
    signal rxd_sync2 : std_logic := '1';

begin

    --------------------------------------------------------------------
    -- 100MHz → 40MHz 클록 생성
    --------------------------------------------------------------------
    i_my_clk_wiz : my_clk_wiz
        port map (
            clk_out1 => clk40m,
            resetn   => rst_l,     -- active-low reset
            locked   => locked,
            clk_in1  => clk100m
        );

    -- PLL lock 안 되었거나 외부 reset이 들어오면 rst=1
    rst <= (not locked) or (not rst_l);

    --------------------------------------------------------------------
    -- RX 입력 2단 동기화
    --------------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            rxd_sync1 <= '1';
            rxd_sync2 <= '1';
        elsif rising_edge(clk40m) then
            rxd_sync1 <= rxd;
            rxd_sync2 <= rxd_sync1;
        end if;
    end process;

    --------------------------------------------------------------------
    -- UART 수신 상태기
    --------------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            state        <= RX_IDLE;
            sample_cnt   <= (others => '0');
            bit_index    <= (others => '0');
            rx_shift     <= (others => '0');
            rx_reg       <= (others => '0');
            rx_valid_reg <= '0';

        elsif rising_edge(clk40m) then
            -- 기본값: 매 클록마다 rx_valid_reg는 0
            rx_valid_reg <= '0';

            case state is

                ----------------------------------------------------------------
                -- 1) IDLE: Start bit 대기
                ----------------------------------------------------------------
                when RX_IDLE =>
                    sample_cnt <= (others => '0');

                    if rxd_sync2 = '0' then      -- falling edge 감지
                        state      <= RX_START;
                        sample_cnt <= (others => '0');
                    end if;

                ----------------------------------------------------------------
                -- 2) START: Start bit 중앙에서 재확인
                ----------------------------------------------------------------
                when RX_START =>
                    if sample_cnt = HALF_DIV_U then
                        if rxd_sync2 = '0' then
                            -- 유효한 Start bit
                            state      <= RX_DAT;
                            sample_cnt <= (others => '0');
                            bit_index  <= (others => '0');
                        else
                            -- 노이즈 등 → 다시 IDLE
                            state <= RX_IDLE;
                        end if;
                    else
                        sample_cnt <= sample_cnt + 1;
                    end if;

                ----------------------------------------------------------------
                -- 3) DATA: 각 비트를 비트 중앙에서 샘플링
                ----------------------------------------------------------------
                when RX_DAT =>
                    if sample_cnt = BAUD_DIV_U then
                        sample_cnt <= (others => '0');

                        -- LSB부터 저장
                        rx_shift(to_integer(bit_index)) <= rxd_sync2;

                        if bit_index = "111" then
                            bit_index <= (others => '0');
                            state     <= RX_STOP;
                        else
                            bit_index <= bit_index + 1;
                        end if;
                    else
                        sample_cnt <= sample_cnt + 1;
                    end if;

                ----------------------------------------------------------------
                -- 4) STOP: Stop bit 확인 후 데이터 확정
                ----------------------------------------------------------------
                when RX_STOP =>
                    if sample_cnt = BAUD_DIV_U then
                        sample_cnt   <= (others => '0');
                        -- 필요하면 rxd_sync2 = '1' 검증 추가 가능
                        rx_reg       <= rx_shift;  -- 최종 데이터
                        rx_valid_reg <= '1';       -- 1클록 펄스
                        state        <= RX_IDLE;
                    else
                        sample_cnt <= sample_cnt + 1;
                    end if;

                when others =>
                    state      <= RX_IDLE;
                    sample_cnt <= (others => '0');
            end case;
        end if;
    end process;

    --------------------------------------------------------------------
    -- 출력 연결
    --------------------------------------------------------------------
    rx_data  <= rx_reg;
    rx_valid <= rx_valid_reg;

end Behavioral;
