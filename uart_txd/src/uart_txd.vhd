library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_txd is
    Port (
        rst_l   : in  STD_LOGIC;   -- 외부 리셋 (Low active)
        clk100m : in  STD_LOGIC;   -- 100MHz 보드 클록
        sw      : in  STD_LOGIC;   -- 스위치 입력
        txd     : out STD_LOGIC    -- UART TX 출력
    );
end uart_txd;

architecture Behavioral of uart_txd is

    --------------------------------------------------------------------
    -- Clock Wizard (PLL) 컴포넌트 선언 : 100MHz → 40MHz
    --------------------------------------------------------------------
    component my_clk_wiz
        port (
            clk_out1 : out std_logic;
            resetn   : in  std_logic;
            locked   : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;

    signal clk40m  : std_logic;
    signal locked  : std_logic;
    signal rst     : std_logic;        -- 내부 리셋 (High active)

    --------------------------------------------------------------------
    -- UART 설정 : 115200 bps, 8N1
    -- 40MHz / 115200 ≒ 347.2  → 분주값 347 사용
    --------------------------------------------------------------------
    constant BAUD_DIV : integer := 347;
    signal baud_cnt   : unsigned(15 downto 0) := (others => '0');
    signal baud_tick  : std_logic := '0';

    --------------------------------------------------------------------
    -- UART 송신 상태기
    --------------------------------------------------------------------
    type tx_state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state     : tx_state_t := IDLE;

    signal tx_reg    : std_logic := '1';             -- 실제 TX 선에 나가는 값
    signal tx_shift  : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_index : unsigned(2 downto 0) := (others => '0');  -- 0~7

    constant TX_DATA_CONST : std_logic_vector(7 downto 0) := x"41";  -- 'A'

    --------------------------------------------------------------------
    -- 스위치 동기화 및 눌림(에지) 검출
    --------------------------------------------------------------------
    signal sw_sync1 : std_logic := '0';
    signal sw_sync2 : std_logic := '0';
    signal sw_prev  : std_logic := '0';
    signal sw_pulse : std_logic := '0';  -- 1클럭 폭 버튼 펄스

    --------------------------------------------------------------------
    -- 전송 요청 플래그 (FSM에서만 제어)
    --------------------------------------------------------------------
    signal tx_req   : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- 100MHz → 40MHz 클록 생성
    --------------------------------------------------------------------
    i_my_clk_wiz : my_clk_wiz
        port map (
            clk_out1 => clk40m,
            resetn   => rst_l,
            locked   => locked,
            clk_in1  => clk100m
        );

    -- PLL lock 안 되었거나 외부 reset이 들어오면 rst=1
    rst <= (not locked) or (not rst_l);

    --------------------------------------------------------------------
    -- 스위치 입력 동기화 + rising edge 검출 → sw_pulse
    --------------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            sw_sync1 <= '0';
            sw_sync2 <= '0';
            sw_prev  <= '0';
            sw_pulse <= '0';
        elsif rising_edge(clk40m) then
            -- 2단 동기화
            sw_sync1 <= sw;
            sw_sync2 <= sw_sync1;

            -- 0 -> 1 변하는 순간만 펄스 생성
            if (sw_sync2 = '1') and (sw_prev = '0') then
                sw_pulse <= '1';
            else
                sw_pulse <= '0';
            end if;

            sw_prev <= sw_sync2;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Baud Rate 분주기: 40MHz → 115200bps (baud_tick 생성)
    --------------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            baud_cnt  <= (others => '0');
            baud_tick <= '0';
        elsif rising_edge(clk40m) then
            if baud_cnt = BAUD_DIV - 1 then
                baud_cnt  <= (others => '0');
                baud_tick <= '1';        -- 1 비트 기간마다 1클럭 펄스
            else
                baud_cnt  <= baud_cnt + 1;
                baud_tick <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- UART 송신 상태기 (tx_req가 1이면 1프레임 전송)
    --------------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            state     <= IDLE;
            tx_reg    <= '1';            -- idle 시 TX는 High
            tx_shift  <= (others => '0');
            bit_index <= (others => '0');
            tx_req    <= '0';
        elsif rising_edge(clk40m) then

            -- 버튼 펄스가 들어오면 전송 요청 플래그 세우기
            if sw_pulse = '1' then
                tx_req <= '1';
            end if;

            if baud_tick = '1' then
                case state is
                    when IDLE =>
                        tx_reg <= '1';

                        if tx_req = '1' then
                            tx_shift  <= TX_DATA_CONST;       -- 'A' 로드
                            bit_index <= (others => '0');
                            state     <= START_BIT;
                            tx_req    <= '0';                 -- 요청 소진
                        end if;

                    when START_BIT =>
                        -- Start bit: Low
                        tx_reg <= '0';
                        state  <= DATA_BITS;

                    when DATA_BITS =>
                        -- LSB부터 1비트씩 전송
                        tx_reg   <= tx_shift(0);
                        tx_shift <= '0' & tx_shift(7 downto 1);  -- 오른쪽 시프트

                        if bit_index = "111" then   -- 8비트 전송 끝
                            bit_index <= (others => '0');
                            state     <= STOP_BIT;
                        else
                            bit_index <= bit_index + 1;
                        end if;

                    when STOP_BIT =>
                        -- Stop bit: High
                        tx_reg <= '1';
                        state  <= IDLE;

                    when others =>
                        state  <= IDLE;
                        tx_reg <= '1';
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- TX 출력
    --------------------------------------------------------------------
    txd <= tx_reg;

end Behavioral;

