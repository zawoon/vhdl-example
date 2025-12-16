library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SW_INPUT is
    Port (
        rst_l   : in  STD_LOGIC;  -- 외부 리셋 (Low active)
        clk100m : in  STD_LOGIC;  -- 보드 기본 100MHz 클록
        sw      : in  STD_LOGIC;  -- 스위치 입력
        led     : out STD_LOGIC   -- LED 출력
    );
end SW_INPUT;

architecture Behavioral of SW_INPUT is

    -- Clock Wizard (PLL) 컴포넌트 선언
    component my_clk_wiz
        port (
            clk_out1 : out std_logic;
            resetn   : in  std_logic;
            locked   : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;

    signal locked   : std_logic;
    signal clk40m   : std_logic;
    signal rst      : std_logic;

    -- 스위치 동기화 및 토글용 신호
    signal sw_sync1 : std_logic := '0';
    signal sw_sync2 : std_logic := '0';
    signal sw_prev  : std_logic := '0';
    signal led_reg  : std_logic := '0';

begin

    -- 100MHz → 40MHz 클록 생성
    i_my_clk_wiz : my_clk_wiz
        port map (
            clk_out1 => clk40m,
            resetn   => rst_l,     -- 외부 리셋 low → resetn=0
            locked   => locked,
            clk_in1  => clk100m
        );

    -- PLL lock 안 됐거나 외부 reset 이 들어오면 rst=1
    rst <= (not locked) or (not rst_l);

    ----------------------------------------------------------------
    -- 스위치 입력 동기화 & 버튼 눌림 감지 → LED 토글
    ----------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            sw_sync1 <= '0';
            sw_sync2 <= '0';
            sw_prev  <= '0';
            led_reg  <= '0';
        elsif rising_edge(clk40m) then
            -- 2단 동기화(메타 안정성 방지)
            sw_sync1 <= sw;
            sw_sync2 <= sw_sync1;

            -- 이전 상태와 비교해서 "앞에서 뒤로" 0→1 변하는 순간 검출
            if (sw_sync2 = '1') and (sw_prev = '0') then
                led_reg <= not led_reg;   -- 스위치를 한번 누를 때마다 LED 토글
            end if;

            -- 다음 클록에서 비교할 이전 값 저장
            sw_prev <= sw_sync2;
        end if;
    end process;

    -- LED 출력 연결
    led <= led_reg;

end Behavioral;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SW_INPUT is
    Port (
        rst_l   : in  STD_LOGIC;  -- 외부 리셋 (Low active)
        clk100m : in  STD_LOGIC;  -- 보드 기본 100MHz 클록
        sw      : in  STD_LOGIC;  -- 스위치 입력
        led     : out STD_LOGIC   -- LED 출력
    );
end SW_INPUT;

architecture Behavioral of SW_INPUT is

    -- Clock Wizard (PLL) 컴포넌트 선언
    component my_clk_wiz
        port (
            clk_out1 : out std_logic;
            resetn   : in  std_logic;
            locked   : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;

    signal locked   : std_logic;
    signal clk40m   : std_logic;
    signal rst      : std_logic;

    -- 스위치 동기화 및 토글용 신호
    signal sw_sync1 : std_logic := '0';
    signal sw_sync2 : std_logic := '0';
    signal sw_prev  : std_logic := '0';
    signal led_reg  : std_logic := '0';

begin

    -- 100MHz → 40MHz 클록 생성
    i_my_clk_wiz : my_clk_wiz
        port map (
            clk_out1 => clk40m,
            resetn   => rst_l,     -- 외부 리셋 low → resetn=0
            locked   => locked,
            clk_in1  => clk100m
        );

    -- PLL lock 안 됐거나 외부 reset 이 들어오면 rst=1
    rst <= (not locked) or (not rst_l);

    ----------------------------------------------------------------
    -- 스위치 입력 동기화 & 버튼 눌림 감지 → LED 토글
    ----------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            sw_sync1 <= '0';
            sw_sync2 <= '0';
            sw_prev  <= '0';
            led_reg  <= '0';
        elsif rising_edge(clk40m) then
            -- 2단 동기화(메타 안정성 방지)
            sw_sync1 <= sw;
            sw_sync2 <= sw_sync1;

            -- 이전 상태와 비교해서 "앞에서 뒤로" 0→1 변하는 순간 검출
            if (sw_sync2 = '1') and (sw_prev = '0') then
                led_reg <= not led_reg;   -- 스위치를 한번 누를 때마다 LED 토글
            end if;

            -- 다음 클록에서 비교할 이전 값 저장
            sw_prev <= sw_sync2;
        end if;
    end process;

    -- LED 출력 연결
    led <= led_reg;

end Behavioral;
