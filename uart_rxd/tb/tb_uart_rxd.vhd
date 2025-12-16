-- tb_uart_rxd.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_rxd is
end tb_uart_rxd;

architecture sim of tb_uart_rxd is

    --------------------------------------------------------------------
    -- DUT 포트와 연결될 신호
    --------------------------------------------------------------------
    signal rst_l    : std_logic := '0';
    signal clk100m  : std_logic := '0';
    signal rxd      : std_logic := '1';  -- UART 라인은 기본적으로 idle=1
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    --------------------------------------------------------------------
    -- 클록/비트 타이밍 설정
    --------------------------------------------------------------------
    constant CLK100_PERIOD : time := 10 ns;   -- 100MHz
    constant CLK40_PERIOD  : time := 25 ns;   -- 40MHz (Clock Wizard 출력 가정)
    constant BAUD_DIV_TB   : integer := 347;  -- 설계와 동일
    -- 1비트 기간 (40MHz 기준 347클록)
    constant BIT_TIME      : time := CLK40_PERIOD * BAUD_DIV_TB;

begin

    --------------------------------------------------------------------
    -- DUT 인스턴스
    --------------------------------------------------------------------
    uut : entity work.uart_rxd
        port map (
            rst_l    => rst_l,
            clk100m  => clk100m,
            rxd      => rxd,
            rx_data  => rx_data,
            rx_valid => rx_valid
        );

    --------------------------------------------------------------------
    -- 100MHz 클록 생성
    --------------------------------------------------------------------
    clk_gen : process
    begin
        while true loop
            clk100m <= '0';
            wait for CLK100_PERIOD / 2;
            clk100m <= '1';
            wait for CLK100_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- UART 프레임을 만들어주는 간단한 procedure
    -- 8N1, LSB first
    --------------------------------------------------------------------
    send_byte_proc : process
        -- 테스트용 상수: 'A' = x"41" = 0b0100_0001
        constant TEST_BYTE1 : std_logic_vector(7 downto 0) := x"41"; -- 'A'
        constant TEST_BYTE2 : std_logic_vector(7 downto 0) := x"42"; -- 'B'
    begin
        ----------------------------------------------------------------
        -- 1) 초기: reset assert
        ----------------------------------------------------------------
        rst_l <= '0';
        rxd   <= '1';  -- idle
        wait for 5 us;

        ----------------------------------------------------------------
        -- 2) reset 해제
        ----------------------------------------------------------------
        rst_l <= '1';

        -- PLL lock + 내부 초기화 여유
        wait for 50 us;

        ----------------------------------------------------------------
        -- 3) 첫 번째 바이트 전송 : 'A'
        ----------------------------------------------------------------
        -- idle 구간
        rxd <= '1';
        wait for BIT_TIME;

        -- Start bit (0)
        rxd <= '0';
        wait for BIT_TIME;

        -- 데이터 비트 (LSB first)
        for i in 0 to 7 loop
            rxd <= TEST_BYTE1(i);
            wait for BIT_TIME;
        end loop;

        -- Stop bit (1)
        rxd <= '1';
        wait for BIT_TIME;

        -- 바이트 간 여유
        wait for 5 * BIT_TIME;

        ----------------------------------------------------------------
        -- 4) 두 번째 바이트 전송 : 'B'
        ----------------------------------------------------------------
        -- Start bit
        rxd <= '0';
        wait for BIT_TIME;

        -- 데이터 비트
        for i in 0 to 7 loop
            rxd <= TEST_BYTE2(i);
            wait for BIT_TIME;
        end loop;

        -- Stop bit
        rxd <= '1';
        wait for BIT_TIME;

        -- 이후 idle 유지
        wait for 10 * BIT_TIME;

        ----------------------------------------------------------------
        -- 5) 시뮬레이션 종료
        ----------------------------------------------------------------
        wait;
    end process;

end sim;
