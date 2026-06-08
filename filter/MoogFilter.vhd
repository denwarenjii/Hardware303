--------------------------------------------------------------------------------
-- MoogFilter.vhd
--
--  This entity describes a Moog ladder filter
--
-- W_{a,b,c} = tanh(y_{a,b,c}[n] / 2*V_t)
--
-- A more efficient implementation would use a single cordic and a finite state
-- machine to cycle through the required operations

--  Revision History:
--    Date:         Author:    Description:
--    29 May 2026   Chris M.   Initial revision; described entity and sketched
--                             architecture structure.
--
-------------------------------------------------------------------------------

-- libraries
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.all;

use ANSIEscape.all;
use FixedLib.all;

entity MoogFilter is
  generic(
    wordsize : positive := 16
  );
  port (
    YIn  : in  std_logic_vector(wordsize - 1 downto 0);
    CLK  : in  std_logic;
    YOut : out std_logic_vector(wordsize - 1 downto 0);
  );
end MoogFilter;

architecture structural of MoogFilter is

  -- Time delayed inputs/outputs
  signal Ya_n_min_1 : std_logic_vector(word_size - 1 downto 0);
  signal Yb_n_min_1 : std_logic_vector(word_size - 1 downto 0);
  signal Yc_n_min_1 : std_logic_vector(word_size - 1 downto 0);
  signal Yd_n_min_1 : std_logic_vector(word_size - 1 downto 0);
  signal Wa_n_min_1 : std_logic_vector(word_size - 1 downto 0);
  signal Wb_n_min_1 : std_logic_vector(word_size - 1 downto 0);
  signal Wc_n_min_1 : std_logic_vector(word_size - 1 downto 0);

  -- STAGE 1 ------------------------------------------------------------------

  -- x[n] ; our input
  signal Stage1_Adder_AIn : std_logic_vector(word_size - 1 downto 0);
  -- 4*r*y_d[n-1]
  signal Stage1_Adder_BIn : std_logic_vector(word_size - 1 downto 0);
  -- x[n] - 4*r*y_d[n-1]
  signal Stage1_Adder_Out : std_logic_vector(word_size - 1 downto 0);
  -- 4*r*y_d[n-1]
  signal Four_R_Yd_Nmin1 : std_logic_vector(word_size - 1 downto 0);
  signal Stage1_Out : std_logic_vector(word_size - 1 downto 0);

  -- STAGE 2 ------------------------------------------------------------------
  signal Stage2_Adder1_AIn :
  signal Stage2_Adder1_BIn :
  signal Stage2_Div_AIn :
  signal Stage2_Div_BIn :


begin
end structural;
