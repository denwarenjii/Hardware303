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
 
-- use work.CordicConstants.all;     -- Cordic constants.
use work.FixedLib.all;            -- Fixed point conversion and printing libs
use work.all;                     
use ANSIEscape.all;               -- ANSI Escape sequences for printing color.

entity MoogFilter_TB is
end MoogFilter_TB;

architecture sim of MoogFilter_TB is
    constant WORD_SIZE : integer := 16;
    constant CLK_PERIOD : time  := (1 sec / (1e9));
    signal ClkEn : std_logic := '1'; -- Clock enable; active high
    signal Reset_TB : std_logic := '1';
    signal YIn_TB : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal CLK_TB : std_logic;
    signal YOut_TB : std_logic_vector(WORD_SIZE - 1 downto 0);

begin
    YIn_TB <= RealToQ1_14(0.5);

    UUT: entity MoogFilter
        -- generic map (

        -- )
        port map (
            Reset => Reset_TB,
            YIn   => YIn_TB,
            CLK   => CLK_TB,
            YOut  => YOut_TB
        );


    -- Stimulus : process
    -- begin
    --     Reset_TB <= '0';
    --     wait for 10 * CLK_PERIOD;

    --     Reset_TB <= '0';
    --     wait for 100 * CLK_PERIOD;

    --     YIn_TB <= RealToQ1_14(0.5);
    --     wait for 200 * CLK_PERIOD;

    --     YIn_TB <= RealToQ1_14(1.0);
    --     wait for 100 * CLK_PERIOD;

    --     stop;
    -- end process Stimulus;

    GenClk : process
    begin
        -- if (ClkEn = '1') then
            Clk_TB <= '0';
            wait for CLK_PERIOD / 2;
            Clk_TB <= '1';
            wait for CLK_PERIOD / 2;
        -- else
        --     wait until ClkEn = '1';
        -- end if;
    end process GenClk;

end sim;