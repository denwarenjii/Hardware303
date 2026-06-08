--------------------------------------------------------------------------------
-- MoogFilterStage.vhd
--
--  This entity describes a single stage of the Moog ladder filter defined as
--  the following operation
--
-- y[n] = y[n - 1] + (i_ctl / C*F_s) * (a[n] - W[n - 1])
--
-- where
--   y[n]   is the output of this stage at time n
--   y[n-1] is the output of this stage at time n - 1
--   i_ctl  is the control current - for us an arbitrary constant
--   C      is the capacitance - for us an arbitrary constant
--   F_s    is the sampling frequency (44.1KHz)
--   a[n]   is the input to this stage at time n
--   W[n-1] is the W block of the output of this stage at time n - 1
--          ( eg, W_a[n - 1] = tanh(y_a[n - 1] / (2 * Vt)) )
--
-- For the first stage, a[n] is equal to tanh((1 / (2 * Vt)) * (x[n] - 4 * r * y_d[n-1] )) 
--   where x[n] is the input to the Moog ladder filter as a whole.
--
-- For all stages but the first and the last, a[n] = the output of the previous stage.
-- Concretely, this means
--
--   y_a[n] = y_a[n-1] + (i_ctl / C*F_s) * (stage_1_out[n] - W_a[n - 1])
---     stage_1_out[n] = tanh((1 / (2 * Vt)) * (x[n] - 4 * r * y_d[n-1] )) 
--
--   y_b[n] = y_b[n-1] + (i_ctl / C*F_s) * (W_a[n] - W_b[n - 1])
--
--   y_c[n] = y_c[n-1] + (i_ctl / C*F_s) * (W_a[n] - W_b[n - 1])
--
--  Revision History:
--    Date:         Author:    Description:
--    30 May 2026   Chris M.   Initial revision; described entity and sketched
--                             architecture structure.
--
-------------------------------------------------------------------------------
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.all;
use work.CordicConstants.all;

use ANSIEscape.all;
use FixedLib.all;

entity MoogFilterStage is
  generic(
    wordsize : positive := 16;
    -- TODO: make i_ctl an input ?
    i_ctl    : real     := 0.01;   -- simulated control voltage = 10mA
    C        : real     := 1.0e-6;   -- simulated capacitance = 1uF
    F_s       : real     := 44.1e3  -- sampling rate
  );
  port (
    Reset     : in  std_logic; -- active low
    a_n       : in  std_logic_vector(wordsize - 1 downto 0);
    CLK       : in  std_logic;
    Yn_out    : out std_logic_vector(wordsize - 1 downto 0);
    stage_out : out std_logic_vector(wordsize - 1 downto 0)
  );
end MoogFilterStage;

architecture structural of MoogFilterStage is


  signal Yn_comb : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Yn      : std_logic_vector(wordsize - 1 downto 0) := (others => '0');
  signal Wn      : std_logic_vector(wordsize - 1 downto 0) := (others => '0');

  signal Wn_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- W[n - 1]
  signal Yn_min_1 : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- y[n - 1]

  -- Adder0_S = a[n] - W[n - 1]
  signal Adder0_A : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- A input
  signal Adder0_B : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- B input
  signal Adder0_S : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- Output

  -- Mul_Out = (i_ctl / C * F_s) * Adder0_S
  --         = (i_ctl / C * F_s) * (a[n] - W[n - 1])
  signal    Mul_In_X : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); 
  constant  Mul_In_Y : std_logic_vector(wordsize - 1 downto 0) := RealToQ1_14(i_ctl / (C * F_s));
  signal    Mul_Out  : std_logic_vector(wordsize - 1 downto 0) := (others => '0');

  -- Adder1_S = Mul_Out + y[n - 1]
  --          = (i_ctl / C * F_s) * (a[n] - W[n - 1]) + y[n - 1]
  signal Adder1_A : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- A input
  signal Adder1_B : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- B input
  signal Adder1_S : std_logic_vector(wordsize - 1 downto 0) := (others => '0'); -- Output

  -- signal std_logic_vector(wordsize - 1 downto 0);
  -- signal std_logic_vector(wordsize - 1 downto 0);
  -- signal std_logic_vector(wordsize - 1 downto 0);
begin
 
  -- W[n]
  Wn_Cordic : entity WBlock
    generic map (
    wordsize => 16
  )
  port map (
    YIn   => Yn,
    Vt    => RealToQ1_14(1.0), -- TODO: More realistic value ? 
    CLK   => CLK,              -- TODO: Don't need - the WBlock is fully synchronous
    Ready => open,
    WOut  => Wn
  );

  Adder0_A <= a_n;
  Adder0_B <= Wn_min_1;

  -- Adder0_S = a[n] - W[n - 1].
  --
  Adder0 : entity AddSub
    generic map (
      wordsize => 16
    )
    port map (
      A           => Adder0_A,
      B           => Adder0_B,
      Cin         => '1',        -- Cin <= 1 when in subtraction mode
      AddBarSub   => '1',
      Cout        => open,
      S           => Adder0_S
    );
 
  Mul_In_X <= Adder0_S;
  -- Mul_In_Y <= RealToQ1_14(i_ctl / (C * F_s));

  -- Mul_Out = (i_ctl / C * F_s) * (a[n] - W[n - 1])
  -- Mul_Out = (i_ctl / C * F_s) * Adder0_S
  Mul : entity Cordic
   port map (
     CLK   => CLK,
     X     => Mul_In_X,
     Y     => Mul_In_Y,
     Func  => F_X_MULT_Y,
     R     => Mul_Out
   );

  -- Adder1_S = Mul_Out + y[n - 1]
  --          = (i_ctl / C * F_s) * (a[n] - W[n - 1]) + y[n - 1]
  Adder1_A <= Mul_Out;
  Adder1_B <= Yn_min_1;

  Adder1 : entity AddSub
    generic map (
      wordsize => 16
    )
    port map (
      A           => Adder1_A,
      B           => Adder1_B,
      Cin         => '1',        -- Cin <= 1 when in subtraction mode
      AddBarSub   => '1',
      Cout        => open,
      S           => Adder1_S
    );

  Yn_comb <= Adder1_S;

  
   -- Assign the delayed values
   process(CLK)
   begin
    if rising_edge(CLK) then
      if (Reset = '0') then
        Yn        <= (others => '0');
        Wn_min_1  <= (others => '0');
        Yn_min_1  <= (others => '0');
        stage_out <= (others => '0');
      else
        Yn        <= Yn_comb;
        Wn_min_1  <= Wn;
        Yn_min_1  <= Yn;
        stage_out <= Wn;
      end if;
    end if;
  end process;


  Yn_out <= Yn;

end structural;
