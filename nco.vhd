----------------------------------------------------------------------------
-- nco.vhd	
--
-- This is a digital implementation of the VCO in the Roland TB-303 synthesizer
-- it uses an NCO to generate a square or sawtooth wave.
--
--  Revision History:
--		28 April 25		Chris M. Initial reivision.
--
-- [TODO]:
--
----------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

package NCOConstants is
  constant WaveSel_SQUARE   : std_logic := '0';
  constant WaveSel_SAWTOOTH : std_logic := '1';
end package NCOConstants;


library ieee;
library std;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NCOConstants.all;

-- 
--                    +------+                           +------+      +---------+          +-----------+       
-- Frequency     n  + |      |        n                  |      |  n   |         |    m     | Phase to  |       
-- Control    ---/--->| Sum  +--------/-----------O----->| Sum  +--/-->|Truncater+----/---->| Amplitude +---/-->
-- Word (f_i)         |      |                    |      |      |      |         |          | Converter |       
--                    |      |                    |      |      |      |         |          +-----------+       
--                    +------+                    |      +---^--+      +---------+                              
--                      + ^                       |          |                                                  
--                        |         +-------+     |          |                                                  
--                        |         |   -1  |     |          |                                                  
--                        +---------|  z    +-----+       Phase                                                 
--                                  |       |             Control                                               
--                                  +-------+             Word (phi_i)                                          


entity NCO is
  generic (
    input_wordsize  : integer;  -- Word size for Frequency and phase control words.
    output_wordsize : integer   -- Word size for output.
  );
  port (
    FreqControlWord  : in std_logic_vector(input_wordsize - 1 downto 0);
    -- PhaseControlWord : in std_logic_vector(input_wordsize - 1 downto 0);
    WaveSel          : in std_logic;
    Clk              : in std_logic;
    Reset            : in std_logic; -- Remove for synthesis;
    DigitalOut       : out std_logic_vector(output_wordsize - 1 downto 0)
  );
end entity;

architecture Dataflow of NCO is

  constant MAX_VAL : std_logic_vector(output_wordsize - 1 downto 0) :=
    (others => '1');

  constant MIN_VAL : std_logic_vector(output_wordsize - 1 downto 0) :=
    (others => '0');

  -- The phase accumulation threshold for a square wave with a duty cycle
  -- of 50 %.
  constant SQUARE_THRESHOLD : std_logic_vector(input_wordsize - 1 downto 0) :=
    -- std_logic_vector(to_unsigned(((2**input_wordsize) / 2 - 1)), input_wordsize);
    std_logic_vector(to_unsigned( ((2**input_wordsize) / 2 - 1), input_wordsize  ));


  signal STARTING_PHASE_OFFSET : std_logic_vector(input_wordsize - 1 downto 0) :=
    (others => '0');
    -- SQUARE_THRESHOLD;

  signal PhaseAccumulator : std_logic_vector(input_wordsize - 1 downto 0);

  signal SawtoothOutput : std_logic_vector(output_wordsize - 1 downto 0);
  signal SquareOutput   : std_logic_vector(output_wordsize - 1 downto 0);
  signal DigitalOutMux  : std_logic_vector(output_wordsize - 1 downto 0);

begin

  SumPhase : process (Clk)
  begin
    if rising_edge(Clk) then
      if (Reset = '0') then
        -- PhaseAccumulator <= (others => '0');
        PhaseAccumulator <= STARTING_PHASE_OFFSET;
      else

        if (unsigned(MAX_VAL) - unsigned(FreqControlWord) <
            unsigned(PhaseAccumulator)) then

          PhaseAccumulator <= STARTING_PHASE_OFFSET;
          -- report "wtf !!!!!!!!!!"
          -- severity WARNING;

        else
          PhaseAccumulator <= std_logic_vector(
                                unsigned(FreqControlWord) + 
                                unsigned(PhaseAccumulator)
                              );
        end if;
      end if;
    end if;
    
  end process SumPhase;

  SquareOutput <= MAX_VAL when (unsigned(PhaseAccumulator) > unsigned(SQUARE_THRESHOLD)) else
                  MIN_VAL;

  SawtoothOutput <= PhaseAccumulator(input_wordsize - 1 downto input_wordsize - output_wordsize);

  DigitalOutMux <= SquareOutput   when (WaveSel = WaveSel_SQUARE) else
                   SawtoothOutput when (WaveSel = WaveSel_SAWTOOTH) else
                   DigitalOutMux;

  DigitalOut <= DigitalOutMux;

end Dataflow;
