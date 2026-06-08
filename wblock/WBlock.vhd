-- WBlock.vhd
--
--  This entity describes a component used in the calculation of a digital
--  Moog ladder filter, as described in Huovilainen 2004. W_{a,b,c} is
--  defined as
--
-- W_{a,b,c} = tanh(y_{a,b,c}[n] / 2*V_t)
--
-- where V_t is the thermal voltage of a transistor (an arbitrary constant in
-- this case). This block is implemented naively using five CORDICs:
--   one in divison mode to calculate 1/2*Vt
--   one in multiplication mode to calculate (1/2*Vt)*y[n]
--   one in hyperbolic rotation mode to calculate cosh((1/2*V_t) * y[n])
--   one in hyperbolic rotation mode to calculate sinh((1/2*V_t) * y[n])
--   one in division mode to calculate tanh((1/2*V_t) * y[n]) = cosh((1/2*V_t) * y[n])
--                                                              ----------------------
--                                                              sinh((1/2*V_t) * y[n])
--
-- A more efficient implementation would use a single cordic and a finite state
-- machine to cycle through the required operations

--  Revision History:
--    Date:         Author:    Description:
--    28 May 2026   Chris M.   Initial revision; described entity and sketched
--                             architecture structure.
--
-- TODO:
--    Expand range of cordic (-5.0 to 5.0)? Just add more integer bits ?
-------------------------------------------------------------------------------

-- libraries
library ieee;
library osvvm;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.all;

use ANSIEscape.all;
use CordicConstants.all;     -- Cordic constants.
use FixedLib.all;

use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity WBlock is
  generic(
    wordsize : positive := 16
  );

  -- YIn   : input
  -- Vt    : transistor thermal voltage constant
  -- Ready : When the output is ready; active high
  -- WOut  : output
  port (
    YIn   : in  std_logic_vector(wordsize - 1 downto 0);
    Vt    : in  std_logic_vector(wordsize - 1 downto 0);
    CLK   : in  std_logic;
    Ready : out std_logic;
    WOut  : out std_logic_vector(wordsize - 1 downto 0)
  );
end WBlock;

architecture structural of WBlock is
  -- Steps:
  --  - Calculate 1/2*Vt (note that we can just shift Vt to get 2*Vt)
  --  - Scale YIn by it
  --  - Calcualte cosh and sinh concurrently (feed into divider)

  -- function RealToQ1_14 (real_val : real) return std_logic_vector is

  -- TODO: No point in using wordsize generic if this is hardcoded to 16 bits

  constant One_Q1_14 : std_logic_vector(wordsize - 1 downto 0) := RealToQ1_14(1.0);

  constant ALL_U : std_logic_vector(wordsize - 1 downto 0) := (others => 'U');
  constant ALL_X : std_logic_vector(wordsize - 1 downto 0) := (others => 'X');
  
  -- The min and max Q1.14 fixed point values represented as reals.
  constant MIN_REAL_VAL : real := -2.0;
  constant MAX_REAL_VAL : real := 1.9999;


  signal DivByVtIn   : std_logic_vector(wordsize - 1 downto 0);
  signal DivByVtOut  : std_logic_vector(wordsize - 1 downto 0);

  signal ScaleYIn  : std_logic_vector(wordsize - 1 downto 0);
  signal ScaleYOut : std_logic_vector(wordsize - 1 downto 0);

  signal CoshIn  : std_logic_vector(wordsize - 1 downto 0);
  signal CoshOut : std_logic_vector(wordsize - 1 downto 0);

  signal SinhIn  : std_logic_vector(wordsize - 1 downto 0);
  signal SinhOut : std_logic_vector(wordsize - 1 downto 0);

  -- signal DivSinhByCoshIn  : std_logic_vector(wordsize - 1 downto 0);
  -- signal DivSinhByCoshOUt : std_logic_vector(wordsize - 1 downto 0);
  signal SinhDivCosh_XIn : std_logic_vector(wordsize - 1 downto 0);
  signal SinhDivCosh_YIn : std_logic_vector(wordsize - 1 downto 0);
  signal SinhDivCosh_Out : std_logic_vector(wordsize - 1 downto 0);

begin

  -- Shift Vt left by 1 to get 2*Vt
    DivByVtIn  <= (others => '0') when (Vt = ALL_U or Vt = ALL_X) else
                  Vt(wordsize - 2 downto 0) & '0';

  -- Steps:
  --   Calculate 1/2*Vt
  --         |
  --         v
  --   Scale y[n] by 1/2*Vt
  --         |
  --         v
  --   Calculate cosh and sinh
  --         |
  --         v
  --  Div sinh by cosh
  --
  ScaleYIn <= (others => '0') when (DivByVtOut = ALL_U or DivByVtOut = ALL_X) else
              DivByVtOut;

      -- ('0' xor GetMSB(XInputBus(i))) when ((Mode = VECTORING) and 
      --                                      (signed(YInputBus(i)) < signed(ZERO_22))) else

  CoshIn <= (others => '0') when (ScaleYOut = ALL_U or ScaleYOut = ALL_X) else
            ScaleYOut;

  SinhIn <= ScaleYOut;

  -- Calculating y/x
  SinhDivCosh_XIn <= CoshOut;
  SinhDivCosh_YIn <= SinhOut;

  -- Result
  WOut <= SinhDivCosh_Out;

  -- Calculate 1/2*Vt
  -- NOTE: Cordic calculates y/x when in division mode
  -- NOTE: The standard thermal voltage of a BJT is 0.026V. 1.0 / (2.0 * 0.026)
  --       would cause the cordic to "underflow", so we pick an arbitrary Vt
  --
  -- For Vt = 0.46 as in the testbench, we expect 1/0.92 ~= 1.08 as the output
  --
  -- [OK]
  DivByVtCordic : entity Cordic
    port map (
      CLK   => CLK,
      -- X => RealToQ1_14(0.85),
      -- Y => RealToQ1_14(1.00),
      X     => DivByVtIn,
      Y     => One_Q1_14,
      Func  => F_Y_DIV_X,
      R     => DivByVtOut
    );

  
  -- Calculate (1/2*Vt) * y[n]
  --
  -- For ScaleYIn = DivByVtOut = 1.08 as in the test bench, and YIn = 0.25,
  -- we expect ~= 0.27
  -- [OK]
  ScaleYInCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => ScaleYIn,
      Y     => YIn,
      Func  => F_X_MULT_Y,
      R     => ScaleYOut
    );

  -- Calculate cosh((1/2*Vt) * y[n])
  --
  -- For CoshIn = ScaleYOut = 0.27, we expect ~= 1.03
  -- [OK]
  --
  CoshCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => CoshIn,
      Y     => (others => '0'),
      Func  => F_COSH_X,
      R     => CoshOut
  );

  -- Calculate sinh((1/2*Vt) * y[n])
  --
  -- For SinhIn = ScaleYOut = 0.27, we expect ~= 0.27
  -- [OK]
  SinhCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => SinhIn,
      Y     => (others => '0'),
      Func  => F_SINH_X,
      R     => SinhOut
  );

  -- Calculate sinh((1/2*Vt) * y[n]) / cosh((1/2*Vt) * y[n])
  --
  -- For CoshOut = 1.03 and SinhOut = 0.27, we expect ~= 0.26
  --
  SinhDivCoshCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => SinhDivCosh_XIn,
      Y     => SinhDivCosh_YIn,
      Func  => F_Y_DIV_X,
      R     => SinhDivCosh_Out
  );
  
end structural;
