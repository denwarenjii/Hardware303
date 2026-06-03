---------------------------------------------------------------------------------------------------
-- WBlock test bench
--
--  This entity implements a test bench for the W block in a Moog ladder filter

--  Revision History:
--    Date:         Author:    Description:
--    30 May 2025   Chris M.   Initial revision; described entity and processes.
--
--  TODO:
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
 
-- use work.CordicConstants.all;     -- Cordic constants.
use work.FixedLib.all;            -- Fixed point conversion and printing libs
use work.all;                     
use ANSIEscape.all;               -- ANSI Escape sequences for printing color.

entity WBlock_TB is
end WBlock_TB;

architecture sim of WBlock_TB is
    constant WORD_SIZE : integer := 16;

    -- Period for a 1GHz clock
    constant CLK_PERIOD : time  := (1 sec / (1e9));

    signal ClkEn : std_logic := '1'; -- Clock enable; active high

    signal YIn_TB    : std_logic_vector(WORD_SIZE - 1 downto 0) := (others => '0');
    signal Vt_TB     : std_logic_vector(WORD_SIZE - 1 downto 0) := (others => '0');
    signal CLK_TB    : std_logic := '1';
    signal Ready_TB  : std_logic;
    signal WOut_TB   : std_logic_vector(WORD_SIZE - 1 downto 0);

begin

    YIn_TB <= RealToQ1_14(0.25);
    Vt_TB <= RealToQ1_14(0.46);

    UUT : entity WBlock
    generic map (
        wordsize => WORD_SIZE
    )
    port map (
        YIn   => YIn_TB,
        Vt    => Vt_TB,
        CLK   => CLK_TB,
        Ready => Ready_TB,
        WOut  => Wout_TB
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
