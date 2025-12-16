library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_spi_master is
end tb_spi_master;

architecture sim of tb_spi_master is

    --------------------------------------------------------------------
    -- DUT와 연결될 신호 선언
    --------------------------------------------------------------------
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';  -- High active reset

    signal tx_start  : std_logic := '0';
    signal tx_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_busy   : std_logic;

    signal rx_data   : std_logic_vector(7 downto 0);
    signal rx_valid  : std_logic;

    signal sclk      : std_logic;
    signal mosi      : std_logic;
    signal miso      : std_logic := '0';
    signal ss_n      : std_logic;

    --------------------------------------------------------------------
    -- SPI Slave 모델용 신호 (TB 내부)
    --------------------------------------------------------------------
    signal slave_shift : std_logic_vector(7 downto 0) := "10101100";  -- 예제 패턴

    constant CLK_PERIOD : time := 25 ns;  -- 40MHz 시스템 클록

begin

    --------------------------------------------------------------------
    -- DUT 인스턴스
    --------------------------------------------------------------------
    uut : entity work.spi_master
        port map (
            clk      => clk,
            rst      => rst,
            tx_start => tx_start,
            tx_data  => tx_data,
            tx_busy  => tx_busy,
            rx_data  => rx_data,
            rx_valid => rx_valid,
            sclk     => sclk,
            mosi     => mosi,
            miso     => miso,
            ss_n     => ss_n
        );

    --------------------------------------------------------------------
    -- 40MHz 시스템 클록 생성
    --------------------------------------------------------------------
    clk_gen : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- 간단한 SPI Slave 모델
    --  - ss_n이 1 → idle 상태, 다음 전송을 위해 패턴 로드
    --  - ss_n이 0이고 sclk의 rising edge마다 MSB부터 한 비트씩 전송
    --------------------------------------------------------------------
    slave_model : process(sclk, ss_n)
    begin
        if ss_n = '1' then
            -- Slave가 비선택 상태로 돌아가면 다음 전송 패턴 로드
            slave_shift <= "10101100";   -- 원하는 패턴 (예: 0xAC)
            miso        <= '0';
        elsif rising_edge(sclk) then
            -- MSB부터 한 비트씩 내보내기
            miso        <= slave_shift(7);
            slave_shift <= slave_shift(6 downto 0) & '0';
        end if;
    end process;

    --------------------------------------------------------------------
    -- Stimulus 프로세스: 전송 요청 만들기
    --------------------------------------------------------------------
    stim_proc : process
    begin
        -- 1) 초기 리셋 활성
        rst      <= '1';
        tx_start <= '0';
        tx_data  <= (others => '0');
        wait for 1 us;

        -- 2) 리셋 해제
        rst <= '0';
        wait for 1 us;

        ----------------------------------------------------------------
        -- 첫 번째 전송: 0x3C 전송 요청
        ----------------------------------------------------------------
        tx_data  <= x"3C";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        -- 전송 완료까지 기다림 (rx_valid가 1 되는 시점까지 대충 여유)
        wait for 500 us;

        ----------------------------------------------------------------
        -- 두 번째 전송: 0xA5 전송 요청
        ----------------------------------------------------------------
        tx_data  <= x"A5";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        -- 또 한 번 완료 대기
        wait for 500 us;

        -- 시뮬레이션 종료
        wait;
    end process;

end architecture sim;
