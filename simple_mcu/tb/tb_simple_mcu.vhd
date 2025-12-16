library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_simple_mcu is
end tb_simple_mcu;

architecture sim of tb_simple_mcu is

    -- DUT 포트와 연결될 신호
    signal clk    : std_logic := '0';
    signal rst_n  : std_logic := '0';  -- active-low reset
    signal io_out : std_logic_vector(7 downto 0);

    -- 40MHz 시스템 클록 (간단히 25ns 주기)
    constant CLK_PERIOD : time := 25 ns;

begin

    --------------------------------------------------------------------
    -- DUT 인스턴스
    --------------------------------------------------------------------
    uut : entity work.simple_mcu
        port map (
            clk    => clk,
            rst_n  => rst_n,
            io_out => io_out
        );

    --------------------------------------------------------------------
    -- 40MHz 클록 생성
    --------------------------------------------------------------------
    clk_gen : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- 리셋 + 관찰용 시퀀스
    --------------------------------------------------------------------
    stim_proc : process
    begin
        -- 처음에는 reset assert (rst_n = 0)
        rst_n <= '0';
        wait for 200 ns;

        -- reset 해제
        rst_n <= '1';

        -- 충분히 오래 돌려서 LED(io_out)를 관찰
        -- (Simulation에서 수십~수백 us 정도 보면 ACC가 1,2,3,... 올라가는 게 보임)
        wait for 500 us;

        wait;  -- 시뮬레이션 종료
    end process;

end architecture sim;
