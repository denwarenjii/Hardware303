---------------------------------------------------------------------------------------------------
-- MoogFilterStage_TB.vhd
--
--  This entity implements a test bench for a single stage in a Moog ladder filter

--  Revision History:
--    Date:         Author:    Description:
--    31 May 2025   Chris M.   Initial revision; described entity and processes.
--
---------------------------------------------------------------------------------------------------

-- libraries
library ieee;
library std;
library osvvm;
library work;

use ieee.std_logic_1164.all;      -- For std_logic operations
use ieee.std_logic_unsigned.all;  -- For unsigned operations
use ieee.numeric_std.all;         --
use ieee.std_logic_textio.all;    -- For std_logic IO
use std.textio.all;               -- For text IO
use std.env.all;                  
use ieee.math_real.all;           -- For trig and arithmetic functions.

use osvvm.RandomPkg.all;          
use osvvm.CoveragePkg.all;
use osvvm.TranscriptPkg.all ;
context osvvm.OsvvmContext;
 
use work.FixedLib.all;            -- Fixed point conversion and printing libs
use work.all;                     
use ANSIEscape.all;               -- ANSI Escape sequences for printing color.

entity MoogFilterStage_TB is
end MoogFilterStage_TB;

architecture sim of MoogFilterStage_TB is
    constant WORD_SIZE : integer := 16;

    -- Period for a 1GHz clock
    constant CLK_PERIOD : time  := (1 sec / (1e9));
    signal ClkEn        : std_logic := '1'; -- Clock enable; active high
    signal CLK_TB       : std_logic := '1';
    signal stage_out_tb : std_logic_vector(WORD_SIZE - 1 downto 0);
begin

    UUT : entity MoogFilterStage
    generic map (
        wordsize => WORD_SIZE
    )
    port map (
        Reset      => '1', -- TODO: Do I need this ?
        a_n        => RealToQ1_14(1.0),
        CLK        => CLK_TB,
        stage_out  => stage_out_tb
    );

    GenClk : process
    begin
        if (ClkEn = '1') then
            Clk_TB <= '0';
            wait for CLK_PERIOD / 2;
            Clk_TB <= '1';
            wait for CLK_PERIOD / 2;
        else
            wait until ClkEn = '1';
        end if;
    end process GenClk;

end sim;

