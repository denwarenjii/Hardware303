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
-------------------------------------------------------------------------------

-- libraries
library ieee;
library osvvm;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use ANSIEscape.all;
use work.all
use work.FixedLib.all;

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
    CLK   : in  std_logic
    Ready : out std_logic;
    WOut  : out std_logic_vector(wordsize - 1 downto 0);
  );
end WBlock;

architecture structural of WBlock is
  -- Steps:
  --  - Calculate 1/2*Vt (note that we can just shift Vt to get 2*Vt)
  --  - Scale YIn by it
  --  - Calcualte cosh and sinh concurrently (feed into divider)

  -- function RealToQ1_14 (real_val : real) return std_logic_vector is

  -- TODO: No point in using wordsize generic if this is hardcoded to 16 bits
  constant One_Q1_14 : std_logic_vector(wordsize - 1 downto 0);
  signal DivByVtIn   : std_logic_vector(wordsize - 1 downto 0);
  signal DivByVtOut  : std_logic_vector(wordsize - 1 downto 0);

  signal ScaleYIn  : std_logic_vector(wordsize - 1 downto 0);
  signal ScaleYOut : std_logic_vector(wordsize - 1 downto 0);

  signal CoshIn  : std_logic_vector(wordsize - 1 downto 0);
  signal CoshOut : std_logic_vector(wordsize - 1 downto 0);

  signal SinhIn  : std_logic_vector(wordsize - 1 downto 0);
  signal SinhOut : std_logic_vector(wordsize - 1 downto 0);

begin

  -- Shift Vt left by 1 to get 2*Vt
  DivByVtIn  <= Vt(wordsize -1 downto 1) & '0';

  ScaleYIn <= DivByVtOut;

  -- Calculate 1/2*Vt
  -- NOTE: Cordic calculates y/x when in division mode
  --
  DivByVtCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => DivByVtIn,
      Y     => One_Q1_14,
      Func  => F_Y_DIV_X,
      R     => DivByVtOut
    );

  
  -- Calculate (1/2*Vt) * y[n]
  --
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
  CoshCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => 
      Y     => 
      Func  => 
      R     => 
    
  );

  -- Calculate sinh((1/2*Vt) * y[n])
  --
  SinhCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => 
      Y     => 
      Func  => 
      R     => 
    
  );

  -- Calculate sinh((1/2*Vt) * y[n]) / cosh((1/2*Vt) * y[n])
  --
  SinhCordic : entity Cordic
    port map (
      CLK   => CLK,
      X     => 
      Y     => 
      Func  => 
      R     => 
    
  );

end structural;
