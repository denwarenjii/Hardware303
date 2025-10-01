----------------------------------------------------------------------------
-- nco_tb.vhd
--
--  Revision History:
--    04/28/2025   Chris M.   Initial revision.
--    09/28/2025   Chris M.   Revise documentation.
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

  -- Unconstrained integer array type.
  type real_array is array (natural range <>) of real;

  -- The frequencies we will test. E1 - D4
  constant TEST_FREQS : real_array := (
    41.20344,   -- E1
    43.65353,   -- F1
    46.24930,   -- F♯1/G♭1
    48.99943,   -- G1
    51.91309,   -- G♯1/A♭1
    55.00000,   -- A1
    58.27047,   -- A♯1/B♭1
    61.73541,   -- B1
    65.40639,   -- C2
    69.29566,   -- C♯2/D♭2
    73.41619,   -- D2
    77.78175,   -- D♯2/E♭2
    82.40689,   -- E2
    87.30706,   -- F2
    92.49861,   -- F♯2/G♭2
    97.99886,   -- G2
    103.8262,   -- G♯2/A♭2
    110.0000,   -- A2
    116.5409,   -- A♯2/B♭2
    123.4708,   -- B2
    130.8128,   -- C3
    138.5913,   -- C♯3/D♭3
    146.8324,   -- D3
    155.5635,   -- D♯3/E♭3
    164.8138,   -- E3
    174.6141,   -- F3
    184.9972,   -- F♯3/G♭3
    195.9977,   -- G3
    207.6523,   -- G♯3/A♭3
    220.0000,   -- A3
    233.0819,   -- A♯3/B♭3
    246.9417,   -- B3
    261.6256,   -- C4
    277.1826,   -- C♯4/D♭4
    293.6648    -- D4
  );

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
    -- f_i = (f * (2^n - 1)) / F_s.
    -- REMEMBER: f_i <= (1/2) * F_s or we get aliasing!
    --
    result := (freq * real(2 ** OUTPUT_WORDSIZE)) / real(SAMPLE_RATE);
    return std_logic_vector(to_unsigned(integer(result), INPUT_WORDSIZE));
  end function;

  signal ClockEn : boolean := true;

begin

  -- Instantiate the Unit Under Test
  --
  UUT : entity NCO
    generic map (
      input_wordsize  => INPUT_WORDSIZE,
      output_wordsize => OUTPUT_WORDSIZE
    )
    port map (
      FreqControlWord   =>  FreqControlWord_TB,
      WaveSel           =>  WaveSel_TB,
      Clk               =>  Clk_TB,
      Reset             =>  Reset_TB,
      DigitalOut        =>  DigitalOut_TB
    );


  -- Generate a 44.1 KHz clock signal
  --
  GenClk : process
      variable l : line;
  begin

    if (ClockEn) then

      Clk_TB <= '1';
      wait for CLK_PERIOD / 2;
      Clk_TB <= '0';
      wait for CLK_PERIOD / 2;

    else

      wait;

      file_close(SquareFile);
      file_close(SawtoothFile);

    end if;
  end process GenClk;


  -- Run the tests, we will sweep the audible range (20Hz - 20KHz) and
  -- create an output file for each each frequency and each waveform.
  RunTests : process
    variable l : line;
  begin

    -- Reset the NCO for a few clock cycles. Reset is active low.
    FreqControlWord_TB <= (others => '0');

    -- Test sawtooth outputs first.
    WaveSel_TB <= WaveSel_SAWTOOTH;
    Reset_TB <= '0';

    wait for 3 * CLK_PERIOD;

    Reset_TB <= '1';
    wait for CLK_PERIOD;

    for i in 0 to (TEST_FREQS'length  - 1) loop

      write(l, "Testing sawtooth @ " & to_string(TEST_FREQS(i), "%7.4f") & " Hz" & LF);
      writeline(SawtoothFile, l);

      WaveSel_TB <= WaveSel_SAWTOOTH;
      FreqControlWord_TB <= FreqToControlWord(TEST_FREQS(i));
      wait for 100 ms;

      write(l, "Testing square @ " & to_string(TEST_FREQS(i), "%7.4f") & " Hz" & LF);
      writeline(SquareFile, l);

      WaveSel_TB <= WaveSel_SQUARE;
      wait for 100 ms;

    end loop;

    write(l, string'("Sim completed with no failures" & LF));
    writeline(output, l);

    ClockEn <= false;

    -- Wait forever so that the simulation ends
    wait;

  end process RunTests;

  OutputValues : process(Clk_TB)
    variable l : line;
  begin

    if (rising_edge(Clk_TB)) then

      if ((DigitalOut_TB /= UNITIALIZED)) then

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
