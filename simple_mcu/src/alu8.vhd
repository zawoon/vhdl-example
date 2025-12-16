-- alu8.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu8 is
    port (
        acc_in  : in  unsigned(7 downto 0);      -- 현재 ACC
        imm     : in  unsigned(7 downto 0);      -- 즉시값(확장된 4비트)
        opcode  : in  std_logic_vector(3 downto 0);
        acc_out : out unsigned(7 downto 0)       -- 연산 결과
    );
end entity alu8;

architecture rtl of alu8 is
begin
    process(acc_in, imm, opcode)
        variable result_v : unsigned(7 downto 0);
    begin
        result_v := acc_in;  -- 기본값: ACC 유지

        case opcode is
            when "0001" =>      -- LDI imm
                result_v := imm;
            when "0010" =>      -- ADDI imm
                result_v := acc_in + imm;
            when others =>
                -- NOP, OUT, JMP 등은 ACC 변화 없음
                null;
        end case;

        acc_out <= result_v;
    end process;
end architecture rtl;

