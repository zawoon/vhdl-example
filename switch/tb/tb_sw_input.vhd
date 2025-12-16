-- tb_sw_input.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_SW_INPUT is
end tb_SW_INPUT;

architecture sim of tb_SW_INPUT is

    -- DUT 포트와 연결될 신호들
    signal rst_l   : std_logic := '0';
    signal clk100m : std_logic := '0';
    signal sw      : std_logic := '0';
    signal led     : std_logic;

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz (10ns 주기)

begin

    --------------------------------------------------------------------
    -- DUT 인스턴스
    --------------------------------------------------------------------
    uut : entity work.SW_INPUT
        port map (
            rst_l   => rst_l,
            clk100m => clk100m,
            sw      => sw,
            led     => led
        );

    --------------------------------------------------------------------
    -- 100 MHz 클록 생성
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
    -- 리셋 + 버튼 입력 자극
    --------------------------------------------------------------------
    stim_proc : process
    begin
        ----------------------------------------------------------------
        -- 초기값: 리셋 assert(저활성), 스위치 OFF
        ----------------------------------------------------------------
        rst_l <= '0';
        sw    <= '0';
        wait for 200 ns;          -- 리셋 유지

        ----------------------------------------------------------------
        -- 리셋 해제
        ----------------------------------------------------------------
        rst_l <= '1';
        -- PLL lock 될 시간 여유 (대략 1 us 정도 기다려 줌)
        wait for 1 us;

        ----------------------------------------------------------------
        -- 스위치 입력: 짧은 0→1→0 펄스를 여러 번 줘서
        -- LED가 토글되는지 확인
        ----------------------------------------------------------------

        -- 1번째 클릭
        sw <= '1';
        wait for 200 ns;          -- 버튼 눌린 시간
        sw <= '0';
        wait for 2 us;

        -- 2번째 클릭
        sw <= '1';
        wait for 200 ns;
        sw <= '0';
        wait for 2 us;

        -- 3번째 클릭
        sw <= '1';
        wait for 200 ns;
        sw <= '0';
        wait for 2 us;

        -- 여기서 시뮬레이션 종료
        wait;
    end process;

end sim;
