-- SEG7_COUNTER.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SEG7_COUNTER is
    Port (
        rst_l    : in  STD_LOGIC;                  -- 외부 리셋 (Low active)
        clk100m  : in  STD_LOGIC;                  -- 100MHz 입력 클록
        sw       : in  STD_LOGIC;                  -- 스위치 입력
        seg7     : out STD_LOGIC_VECTOR(6 downto 0) -- a,b,c,d,e,f,g (active-low)
    );
end SEG7_COUNTER;

architecture Behavioral of SEG7_COUNTER is

    --------------------------------------------------------------------
    -- Clock Wizard (PLL) 컴포넌트 선언
    --------------------------------------------------------------------
    component my_clk_wiz
        port (
            clk_out1 : out std_logic;  -- 내부용 클록 (40MHz 등)
            reset    : in  std_logic;  -- Active-high reset
            locked   : out std_logic;  -- PLL lock 플래그
            clk_in1  : in  std_logic   -- 100MHz 입력 클록
        );
    end component;

    signal locked    : std_logic;
    signal clk40m    : std_logic;                  -- 내부 40MHz 클록
    signal rst       : std_logic;                  -- 내부 리셋 (High active)

    -- 0~9 숫자 카운터
    signal digit_cnt : unsigned(3 downto 0)  := (others => '0');

    signal seg_reg   : std_logic_vector(6 downto 0) := (others => '1');

    -- 스위치 동기화 및 edge 검출용 레지스터
    signal sw_sync1  : std_logic := '0';
    signal sw_sync2  : std_logic := '0';
    signal sw_prev   : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- 100MHz → 40MHz 변환 (Clock Wizard 인스턴스)
    -- reset 포트는 active-high 이므로, low-active인 rst_l을 not 해서 연결
    --------------------------------------------------------------------
    i_my_clk_wiz : my_clk_wiz
        port map ( 
            clk_out1 => clk40m,
            reset    => not rst_l,  -- ★ 중요: rst_l이 1일 때 reset=0 이 되도록
            locked   => locked,
            clk_in1  => clk100m
        );

    -- PLL lock 안 되었거나, 외부 reset 이 들어오면 rst=1
    rst <= (not locked) or (not rst_l);

    --------------------------------------------------------------------
    -- 스위치 눌림(0→1 상승 에지)마다 digit_cnt 1 증가
    --------------------------------------------------------------------
    process(clk40m, rst)
    begin
        if rst = '1' then
            sw_sync1  <= '0';
            sw_sync2  <= '0';
            sw_prev   <= '0';
            digit_cnt <= (others => '0');
        elsif rising_edge(clk40m) then
            -- 2단 동기화 (메타 안정성 방지)
            sw_sync1 <= sw;
            sw_sync2 <= sw_sync1;

            -- 0→1 상승 에지 검출
            if (sw_sync2 = '1') and (sw_prev = '0') then
                if digit_cnt = 9 then
                    digit_cnt <= (others => '0');
                else
                    digit_cnt <= digit_cnt + 1;
                end if;
            end if;

            -- 다음 클록에서 비교할 이전 상태 저장
            sw_prev <= sw_sync2;
        end if;
    end process;

    --------------------------------------------------------------------
    -- digit_cnt(0~9)에 따라 7-segment 패턴 생성
    -- 공통 애노드(Common Anode), segment active-low 기준
    -- seg7 = "abcdefg"
    --------------------------------------------------------------------
    process(digit_cnt)
    begin
        case digit_cnt is
            when "0000" =>  -- 0
                seg_reg <= "0000001";  -- a,b,c,d,e,f ON, g OFF
            when "0001" =>  -- 1
                seg_reg <= "1001111";  -- b,c ON
            when "0010" =>  -- 2
                seg_reg <= "0010010";
            when "0011" =>  -- 3
                seg_reg <= "0000110";
            when "0100" =>  -- 4
                seg_reg <= "1001100";
            when "0101" =>  -- 5
                seg_reg <= "0100100";
            when "0110" =>  -- 6
                seg_reg <= "0100000";
            when "0111" =>  -- 7
                seg_reg <= "0001111";
            when "1000" =>  -- 8
                seg_reg <= "0000000";
            when "1001" =>  -- 9
                seg_reg <= "0000100";
            when others =>
                seg_reg <= "1111111";  -- blank
        end case;
    end process;

    seg7 <= seg_reg;

end Behavioral;
