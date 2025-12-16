-- tb_SEG7_COUNTER_SW.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_SEG7_COUNTER is
end tb_SEG7_COUNTER;

architecture sim of tb_SEG7_COUNTER is

    -- DUT 포트와 연결될 신호
    signal rst_l   : std_logic := '0';
    signal clk100m : std_logic := '0';
    signal sw      : std_logic := '0';
    signal seg7    : std_logic_vector(6 downto 0);

    constant CLK_PERIOD : time := 10 ns;  -- 100MHz (10ns 주기)

begin

    --------------------------------------------------------------------
    -- DUT 인스턴스
    --------------------------------------------------------------------
    uut : entity work.SEG7_COUNTER
        port map (
            rst_l   => rst_l,
            clk100m => clk100m,
            sw      => sw,
            seg7    => seg7
        );

    --------------------------------------------------------------------
    -- 100MHz 클록 생성
    --------------------------------------------------------------------
    clk_gen : process
    begin
        while true loop
            clk100m <= '0';
            wait for CLK_PERIOD / 2;
            clk100m <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- 리셋 + 스위치 자극
    --------------------------------------------------------------------
    stim_proc : process
    begin
        -- 초기: 리셋 assert (low), 스위치 OFF
        rst_l <= '0';
        sw    <= '0';
        wait for 200 ns;

        -- 리셋 해제
        rst_l <= '1';

        -- PLL lock 및 내부 초기화 시간 약간 기다리기
        wait for 2 us;

        ----------------------------------------------------------------
        -- 1번째 버튼 클릭 (짧은 펄스)
        ----------------------------------------------------------------
        sw <= '1';
        wait for 200 ns;
        sw <= '0';
        wait for 2 us;

        ----------------------------------------------------------------
        -- 2번째 클릭
        ----------------------------------------------------------------
        sw <= '1';
        wait for 200 ns;
        sw <= '0';
        wait for 2 us;

        ----------------------------------------------------------------
        -- 3번째 클릭
        ----------------------------------------------------------------
        sw <= '1';
        wait for 200 ns;
        sw <= '0';
        wait for 2 us;

        ----------------------------------------------------------------
        -- 4번째 클릭
        ----------------------------------------------------------------
        sw <= '1';
        wait for 200 ns;
        sw <= '0';
        wait for 2 us;

        -- 필요하면 더 눌러보기
        -- ...

        -- 시뮬레이션 종료
        wait;
    end process;

end sim;
