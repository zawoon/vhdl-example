library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simple_mcu is
    port (
        clk    : in  std_logic;                          -- 시스템 클록
        rst_n  : in  std_logic;                          -- active-low reset
        io_out : out std_logic_vector(7 downto 0)        -- LED 등 외부 출력
    );
end entity simple_mcu;

architecture rtl of simple_mcu is

    --------------------------------------------------------------------
    -- ROM (Block Memory Generator) 컴포넌트 선언
    --------------------------------------------------------------------
    component blk_mem_gen_0
      port (
        clka  : in  std_logic;
        addra : in  std_logic_vector(3 downto 0);
        douta : out std_logic_vector(7 downto 0)
      );
    end component;

    --------------------------------------------------------------------
    -- PC, ALU 컴포넌트 선언
    --------------------------------------------------------------------
    component pc_unit
        port (
            clk      : in  std_logic;
            rst_n    : in  std_logic;
            inc_en   : in  std_logic;
            load_en  : in  std_logic;
            load_val  : in  unsigned(3 downto 0);
            pc_out   : out unsigned(3 downto 0)
        );
    end component;

    component alu8
        port (
            acc_in  : in  unsigned(7 downto 0);
            imm     : in  unsigned(7 downto 0);
            opcode  : in  std_logic_vector(3 downto 0);
            acc_out : out unsigned(7 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- 내부 상태/신호 정의
    --------------------------------------------------------------------
    type state_t is (FETCH, EXECUTE);

    signal state   : state_t := FETCH;

    signal pc          : unsigned(3 downto 0) := (others => '0');  -- PC 출력
    signal instr       : std_logic_vector(7 downto 0) := (others => '0');
    signal acc         : unsigned(7 downto 0) := (others => '0');  -- ACC
    signal acc_next    : unsigned(7 downto 0) := (others => '0');
    signal out_reg     : std_logic_vector(7 downto 0) := (others => '0');

    -- PC 제어용
    signal pc_inc_en   : std_logic := '0';
    signal pc_load_en  : std_logic := '0';
    signal pc_load_val : unsigned(3 downto 0) := (others => '0');

begin

    ----------------------------------------------------------------
    -- 외부 출력
    ----------------------------------------------------------------
    io_out <= out_reg;

    ----------------------------------------------------------------
    -- Instruction ROM 인스턴스
    ----------------------------------------------------------------
    u_prog_rom : blk_mem_gen_0
      port map (
        clka  => clk,
        addra => std_logic_vector(pc),
        douta => instr
      );

    ----------------------------------------------------------------
    -- PC 인스턴스
    ----------------------------------------------------------------
    u_pc : pc_unit
        port map (
            clk      => clk,
            rst_n    => rst_n,
            inc_en   => pc_inc_en,
            load_en  => pc_load_en,
            load_val => pc_load_val,
            pc_out   => pc
        );

    ----------------------------------------------------------------
    -- ALU 인스턴스 (ACC + IMM 연산 전담)
    ----------------------------------------------------------------
    -- imm8: 4비트 operand를 8비트로 zero-extend
    -- opcode: instr(7 downto 4)
    u_alu : alu8
        port map (
            acc_in  => acc,
            imm     => unsigned("0000" & instr(3 downto 0)),
            opcode  => instr(7 downto 4),
            acc_out => acc_next
        );

    ----------------------------------------------------------------
    -- 간단한 2-스테이지 MCU: FETCH → EXECUTE
    ----------------------------------------------------------------
    process (clk, rst_n)
        variable opcode  : std_logic_vector(3 downto 0);
        variable operand : std_logic_vector(3 downto 0);
    begin
        if rst_n = '0' then
            state       <= FETCH;
            acc         <= (others => '0');
            out_reg     <= (others => '0');

            pc_inc_en   <= '0';
            pc_load_en  <= '0';
            pc_load_val <= (others => '0');

        elsif rising_edge(clk) then

            -- 기본값(디폴트 제어) 설정
            pc_inc_en   <= '0';
            pc_load_en  <= '0';
            pc_load_val <= pc_load_val;  -- 유지

            case state is

                ----------------------------------------------------
                -- FETCH 단계
                --  - ROM에서 instr를 읽고
                --  - PC를 1 증가
                ----------------------------------------------------
                when FETCH =>
                    pc_inc_en <= '1';     -- 이번 클록에 PC <= PC + 1
                    state     <= EXECUTE;

                ----------------------------------------------------
                -- EXECUTE 단계
                ----------------------------------------------------
                when EXECUTE =>
                    opcode  := instr(7 downto 4);
                    operand := instr(3 downto 0);

                    case opcode is

                        when "0000" =>  -- NOP
                            -- ACC 변화 없음
                            acc <= acc;  -- (생략 가능)

                        when "0001" =>  -- LDI imm : ACC <= imm
                            acc <= acc_next;  -- ALU가 imm 로드

                        when "0010" =>  -- ADDI imm : ACC <= ACC + imm
                            acc <= acc_next;  -- ALU가 덧셈 결과 반환

                        when "0100" =>  -- OUT : out_reg <= ACC
                            out_reg <= std_logic_vector(acc);

                        when "0110" =>  -- JMP addr : PC <= addr
                            pc_load_en  <= '1';
                            pc_load_val <= unsigned(operand);

                        when others =>
                            -- 정의되지 않은 opcode → NOP
                            null;

                    end case;

                    state <= FETCH;

            end case;
        end if;
    end process;

end architecture rtl;

