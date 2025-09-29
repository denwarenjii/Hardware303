----------------------------------------------------------------------------
-- nco.vhd
--
-- This is an implementation of a n-bit NCO (numerically controlled oscillator).
-- It can output a square or sawtooth wave whose frqeuency is determnined by 
-- the frequency control word. The frequency control word, f_i, is an n-bit
-- word equal to (f * (2^n - 1)) / F_s, where f is the desired frequency, n is
-- the number of bits in the NCO, and F_s is the sampling frequency (ie, the
-- clock rate). Note that the maximum output frequency must be less than or
-- equal to half of the sampling frequency according to Nyquist's Sampling
-- thereom.
--
--  Revision History:
--    04/28/2025   Chris M.   Initial revision.
--    09/28/2025   Chris M.   Revise documentation.
--
-- TODO:
--  - Add duty cycle input.
--
----------------------------------------------------------------------------

-- Block Diagram:
--
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

entity NCO is
  generic (
    -- If not specified, the word size is 16 bits. 
    input_wordsize  : integer := 16;
    output_wordsize : integer := 16
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

  -- Used to avoid ieee.numeric_std metavalues upon startup. Can be removed
  -- in simulation.
  signal PhaseAccumulatorMux : std_logic_vector(input_wordsize - 1 downto 0) := (others => '0');

begin

  SumPhase : process (Clk)
  begin
    if rising_edge(Clk) then

      if (Reset = '0') then
        -- PhaseAccumulator <= (others => '0');
        PhaseAccumulator <= STARTING_PHASE_OFFSET;
      else

        if (unsigned(MAX_VAL) - unsigned(FreqControlWord) < unsigned(PhaseAccumulator)) then

          PhaseAccumulator <= STARTING_PHASE_OFFSET;

        else
          PhaseAccumulator <= std_logic_vector(
                                unsigned(FreqControlWord) + 
                                unsigned(PhaseAccumulator)
                              );
        end if;
      end if;
    end if;
    
  end process SumPhase;

  PhaseAccumulatorMux <= (STARTING_PHASE_OFFSET) when (Reset = '0') else
                         (PhaseAccumulator);

  SquareOutput <= (others => '0') when (Reset = '0') else
                  MAX_VAL         when (unsigned(PhaseAccumulatorMux) > unsigned(SQUARE_THRESHOLD)) else
                  MIN_VAL;


  SawtoothOutput <= PhaseAccumulatorMux(input_wordsize - 1 downto input_wordsize - output_wordsize);

  DigitalOutMux <= SquareOutput   when (WaveSel = WaveSel_SQUARE) else
                   SawtoothOutput when (WaveSel = WaveSel_SAWTOOTH) else
                   DigitalOutMux;

  DigitalOut <= DigitalOutMux;



end Dataflow;
