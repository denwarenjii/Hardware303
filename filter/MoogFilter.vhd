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
use work.CordicConstants.all;

use ANSIEscape.all;
use FixedLib.all;

entity MoogFilter is
  generic(
    R        : positive := 10; -- simualted resistance value (TODO: good enough?)
    wordsize : positive := 16
  );
  port (
    Reset : in std_logic; -- active low
    YIn  : in  std_logic_vector(wordsize - 1 downto 0);
    CLK  : in  std_logic;
    YOut : out std_logic_vector(wordsize - 1 downto 0)
  );
end MoogFilter;

architecture structural of MoogFilter is

  constant R_slv : std_logic_vector(wordsize - 1 downto 0) := 
    std_logic_vector(to_unsigned(R, wordsize));

  -- Time delayed inputs/outputs
  signal Ya_n_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Yb_n_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Yc_n_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Yd_n_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Wa_n_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Wb_n_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Wc_n_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0');

  -- Stage 1 pre
  signal Stage1_Pre_Xin : std_logic_vector(wordsize - 1 downto 0);
  signal Stage1_Pre_Yin : std_logic_vector(wordsize - 1 downto 0);
  signal Stage1_Pre_Out : std_logic_vector(wordsize - 1 downto 0);

  -- STAGE 1 ------------------------------------------------------------------

  -- x[n] ; our input
  signal Stage1_Adder_AIn : std_logic_vector(wordsize - 1 downto 0);
  -- 4*r*y_d[n-1]
  signal Stage1_Adder_BIn : std_logic_vector(wordsize - 1 downto 0);
  -- x[n] - 4*r*y_d[n-1]
  signal Stage1_Adder_Out : std_logic_vector(wordsize - 1 downto 0);
  -- 4*r*y_d[n-1]
  signal Four_R_Yd_Nmin1 : std_logic_vector(wordsize - 1 downto 0);
  signal Stage1_In       : std_logic_vector(wordsize - 1 downto 0);
  signal Stage1_Out      : std_logic_vector(wordsize - 1 downto 0);

  -- STAGE 2 ------------------------------------------------------------------
  -- signal Stage2_Adder1_AIn :
  -- signal Stage2_Adder1_BIn :
  -- signal Stage2_Div_AIn    :
  -- signal Stage2_Div_BIn    :
  -- STAGE 3 ------------------------------------------------------------------

begin

  Stage1_Pre_Xin <= R_slv sll 2;
  Stage1_Pre_Yin <= Yd_n_min_1;

  -- Calculate 4 * r * y_d[n - 1]
  Stage1_pre : entity Cordic
    port map (
      CLK => CLK,
      X => Stage1_Pre_Xin,
      Y => Stage1_Pre_Yin,
      Func  => F_X_MULT_Y,
      R  => Stage1_Pre_Out
    );

  -- NOTE: The first "stage" doesn't use a moogfilterstage (This is a shitty name !!!)
  -- It just does the "W" function but with an input of x[n] - 4*r*y_d[n - 1]

  Stage1 : entity WBlock
    port map (
      YIn    => Stage1_Pre_Out,
      Vt     => RealToQ1_14(0.46),
      CLK    => CLK,
      Ready  => open,
      WOut   => Stage1_Out
    );

  -- Stage1 : entity MoogFilterStage
  --   port map (
  --     Reset => Reset,
  --     a_n   => 
  --     CLK   => CLK,
  --     stage_out => Stage1_Out
  --   )

end structural;
