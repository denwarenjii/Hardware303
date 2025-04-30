----------------------------------------------------------------------------
-- nco_tb.vhd	
--
-- NCO test bench.
--
--  Revision History:
--		28 April 25		Chris M. Initial reivision.
--
-- [TODO]:
--
----------------------------------------------------------------------------

library ieee;
library std;
library work;
library osvvm;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use std.env.all;
use std.textio.all;

use work.NCOConstants.all;
use work.all;

use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;
use osvvm.TranscriptPkg.all;
context osvvm.OsvvmContext;

entity NCO_TB is
end entity;

architecture Testbench of NCO_TB is


  -- Period for a 44.1KHz signal.
  constant CLK_PERIOD : time := 22.7 us;
  constant SAMPLE_RATE : integer := 44100;

  constant INPUT_WORDSIZE : integer := 16;
  constant OUTPUT_WORDSIZE : integer := 16;

  signal FreqControlWord_TB  : std_logic_vector(INPUT_WORDSIZE - 1 downto 0);
  signal WaveSel_TB          : std_logic;
  signal Clk_TB              : std_logic;
  signal Reset_TB            : std_logic;
  signal DigitalOut_TB       : std_logic_vector(OUTPUT_WORDSIZE - 1 downto 0);

  signal UNITIALIZED : std_logic_vector(OUTPUT_WORDSIZE - 1 downto 0);

  file OutputFile : text open write_mode is "out.txt";

  file SquareFile   : text open write_mode is "square.txt";
  file SawtoothFile : text open write_mode is "sawtooth.txt";

  pure function FreqToControlWord (freq : real) return std_logic_vector is
    variable result : real := 0.0;
  begin
    -- f_i = (f * (2^n - 1)) / F_s, f_i <= (1/2) & F_s
    --
    result := (freq * real(2**OUTPUT_WORDSIZE)) / real(SAMPLE_RATE);
    return std_logic_vector(to_unsigned(integer(result), INPUT_WORDSIZE));
  end function;

begin

  UUT : entity NCO
    generic map (
      input_wordsize => INPUT_WORDSIZE,
      output_wordsize => OUTPUT_WORDSIZE
    )
    port map (
      FreqControlWord   =>  FreqControlWord_TB,
      WaveSel           =>  WaveSel_TB,
      Clk               =>  Clk_TB,
      Reset             =>  Reset_TB,
      DigitalOut        =>  DigitalOut_TB      
    );


  GenClk : process
  begin
    Clk_TB <= '1';
    wait for CLK_PERIOD / 2;
    Clk_TB <= '0';
    wait for CLK_PERIOD / 2;
  end process GenClk;

  RunTests : process
  begin

    FreqControlWord_TB <= (others => '0');
    WaveSel_TB <= WaveSel_SAWTOOTH;
    Reset_TB <= '0';

    wait for 3 * CLK_PERIOD;
    Reset_TB <= '1';
    wait for CLK_PERIOD;
    
    FreqControlWord_TB <= FreqToControlWord(200.0);
    wait for 100 ms;


    WaveSel_TB <= WaveSel_SQUARE;
    wait for 100 ms;

    file_close(SquareFile);

    stop;

  end process RunTests;

  OutputValues : process(Clk_TB)
    variable l : line;
  begin
    if rising_edge(Clk_TB) then
      if (DigitalOut_TB /= UNITIALIZED) then

        write(l, to_integer(unsigned(DigitalOut_TB)));

        if (WaveSel_TB = WaveSel_SQUARE) then
          writeline(SquareFile, l);
        elsif (WaveSel_TB = WaveSel_SAWTOOTH) then
          writeline(SawtoothFile, l);
        end if;

      end if;
    end if;
  end process OutputValues;

end Testbench;


