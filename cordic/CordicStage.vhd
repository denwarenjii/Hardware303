------------------------------------------------------------------------------
-- A single stage of a parallel CORDIC calculator.
--
--  This entity describes a single stage of a CORDIC calculator. It includes
--  the X, Y, and Z adders.

--  Revision History:
--    Date:         Author:    Description:
--    18 Feb 25     Chris M.   Initial revision.
-------------------------------------------------------------------------------
library ieee;
use std.textio.all;
use ieee.std_logic_1164.all;
use  ieee.numeric_std.all;
use  ieee.math_real.all;
use  work.FixedLib.all;

-- This must be defined here to avoid circular dependencies.
package CordicConstants is

  -- Function constants. Defined in the spec.
  --   1  = cos(x)
  --   2  = cosh(x)
  --   4  = x*y
  --   5  = sin(x)
  --   6  = sinh(x)
  --  12  = y/x
  constant F_COS_X    : std_logic_vector(4 downto 0) := "00001";
  constant F_SIN_X    : std_logic_vector(4 downto 0) := "00101";
  constant F_X_MULT_Y : std_logic_vector(4 downto 0) := "00100";
  constant F_COSH_X   : std_logic_vector(4 downto 0) := "00010";
  constant F_SINH_X   : std_logic_vector(4 downto 0) := "00110";
  constant F_Y_DIV_X  : std_logic_vector(4 downto 0) := "01100";

  -- Coordinate systems. Trig functions are done in the circular coordinate
  -- system, arithmetic functions are done in the linear coordinate system, and
  -- hyperbolic functions are done in the hyperbolic coordinate system.
  signal   CordSystem  : std_logic_vector(1 downto 0);
  constant CIRCULAR    : std_logic_vector(1 downto 0) := "01"; -- (1)
  constant LINEAR      : std_logic_vector(1 downto 0) := "00"; -- (0)
  constant HYPERBOLIC  : std_logic_vector(1 downto 0) := "11"; -- (-1)

  -- The number of iterations.
  constant ITERATIONS             : positive := 16;
  constant INTERMEDIATE_WORD_SIZE : positive := 22;
  constant WORD_SIZE              : positive := 16;

  -- Starting constants for circular and hyperbolic modes.
  --
  constant K_inv_circular   : std_logic_vector((INTERMEDIATE_WORD_SIZE - 1) downto 0) := 
    RealToQ3_18(0.607252935);

  constant K_inv_hyperbolic : std_logic_vector((INTERMEDIATE_WORD_SIZE - 1) downto 0) := 
    RealToQ3_18(1.20749706776);

  constant ZERO_22 : std_logic_vector((INTERMEDIATE_WORD_SIZE - 1) downto 0) := (others => '0');

  -- 17 x 22 matrix for the generating busses. Note that intermediate operations 
  -- will use Q3.18 fixed points to avoid overflow rounding errors.
  type array_2d is array (0 to (ITERATIONS - 1)) of 
    std_logic_vector((INTERMEDIATE_WORD_SIZE - 1) downto 0);

  -- Constants for the B inputs of the Z adders.
  --
  constant Z_CONSTANTS_CIRCULAR    : array_2d := (
    -- a_i = arctan(2^-i) for 0 <= i <= 15
    RealToQ3_18(  arctan(2.0**(0))   ),
    RealToQ3_18(  arctan(2.0**(-1))  ),
    RealToQ3_18(  arctan(2.0**(-2))  ),
    RealToQ3_18(  arctan(2.0**(-3))  ),
    RealToQ3_18(  arctan(2.0**(-4))  ),
    RealToQ3_18(  arctan(2.0**(-5))  ),
    RealToQ3_18(  arctan(2.0**(-6))  ),
    RealToQ3_18(  arctan(2.0**(-7))  ),
    RealToQ3_18(  arctan(2.0**(-8))  ),
    RealToQ3_18(  arctan(2.0**(-9))  ),
    RealToQ3_18(  arctan(2.0**(-10)) ),
    RealToQ3_18(  arctan(2.0**(-11)) ),
    RealToQ3_18(  arctan(2.0**(-12)) ),
    RealToQ3_18(  arctan(2.0**(-13)) ),
    RealToQ3_18(  arctan(2.0**(-14)) ),
    RealToQ3_18(  arctan(2.0**(-15)) )
  );

  constant Z_CONSTANTS_LINEAR      : array_2d := (
    -- a_i = 2^-i for 0 <= i <= 15
    RealToQ3_18(2.0**(0)),
    RealToQ3_18(2.0**(-1)),
    RealToQ3_18(2.0**(-2)),
    RealToQ3_18(2.0**(-3)),
    RealToQ3_18(2.0**(-4)),
    RealToQ3_18(2.0**(-5)),
    RealToQ3_18(2.0**(-6)),
    RealToQ3_18(2.0**(-7)),
    RealToQ3_18(2.0**(-8)),
    RealToQ3_18(2.0**(-9)),
    RealToQ3_18(2.0**(-10)),
    RealToQ3_18(2.0**(-11)),
    RealToQ3_18(2.0**(-12)),
    RealToQ3_18(2.0**(-13)),
    RealToQ3_18(2.0**(-14)),
    RealToQ3_18(2.0**(-15))
 );

  -- Note that we start at iteration 1 because arctanh(2^0) is undefined, and
 -- we repeat iterations 4 and 13 so that the expression
  --
  --    a_1 - \sum_{k=2}^{k=16} a_n
  -- 
  -- converges to zero. See Walther, 1971 for more details. 
  constant Z_CONSTANTS_HYPERBOLIC  : array_2d :=  (
    -- a_i = arctanh(2^-k) for 0 <= i <= 15 where 
    --
    --     { i + 1   :   i < 4 
    -- k = { i       :   4 <= i <= 13
    --     { i - 1   :   i > 13
    --
    RealToQ3_18(arctanh(2.0**(-1))),   -- a_1
    RealToQ3_18(arctanh(2.0**(-2))),   -- a_2
    RealToQ3_18(arctanh(2.0**(-3))),   -- a_3
    RealToQ3_18(arctanh(2.0**(-4))),   -- a_4
    RealToQ3_18(arctanh(2.0**(-4))),   -- a_5 (repeat)
    RealToQ3_18(arctanh(2.0**(-5))),   -- a_6
    RealToQ3_18(arctanh(2.0**(-6))),   -- a_7
    RealToQ3_18(arctanh(2.0**(-7))),   -- a_8
    RealToQ3_18(arctanh(2.0**(-8))),   -- a_9
    RealToQ3_18(arctanh(2.0**(-9))),   -- a_10
    RealToQ3_18(arctanh(2.0**(-10))),  -- a_11
    RealToQ3_18(arctanh(2.0**(-11))),  -- a_12
    RealToQ3_18(arctanh(2.0**(-12))),  -- a_13
    RealToQ3_18(arctanh(2.0**(-13))),  -- a_14 
    RealToQ3_18(arctanh(2.0**(-13))),  -- a_15 (repeat)
    RealToQ3_18(arctanh(2.0**(-14)))   -- a_16
  );

  type ModeStringType is array(0 to 1) of string;
  constant MODE_STRINGS : ModeStringType := ( "Rotation ", "Vectoring" );

  type CordStringType is array(0 to 3) of string;
  constant CORD_STRINGS : CordStringType := (
    "Linear    ",
    "Circular  ",
    "          ",
    "Hyperbolic"
  );


end package;


library ieee;
use std.textio.all;
use ieee.std_logic_1164.all;
use  ieee.numeric_std.all;
use  ieee.math_real.all;
use  work.FixedLib.all;
use  work.CordicConstants.all;
use  work.all;

entity CordicStage is
  generic (
    wordsize : positive := 22
  );

  port(
    XIn        : in std_logic_vector(wordsize - 1 downto 0);
    YIn        : in std_logic_vector(wordsize - 1 downto 0);
    ZIn        : in std_logic_vector(wordsize - 1 downto 0);
    ZConstant  : in std_logic_vector(wordsize - 1 downto 0);
    CordSystem : in std_logic_vector(1 downto 0);
    d          : in std_logic;
    i          : in positive range 0 to wordsize;

    XOut       : out std_logic_vector(wordsize - 1 downto 0);
    YOut       : out std_logic_vector(wordsize - 1 downto 0);
    ZOut       : out std_logic_vector(wordsize - 1 downto 0)
  );
end CordicStage;

architecture concurrent of CordicStage is

  signal XAddBarSub : std_logic;
  signal YAddBarSub : std_logic;
  signal ZAddBarSub : std_logic;

  signal XOutMux : std_logic_vector(XIn'range);

  alias Mode : std_logic is CordSystem(1);

  signal X_BIn : std_logic_vector(XIn'range);
  signal Y_BIn : std_logic_vector(XIn'range);

begin

  -- Bypass the output when in the linear coordinate system.
  XOut <= XIn     when (CordSystem = LINEAR) else 
          XOutMux;

  -- Determine the AddBarSub signals
  -- m d_i
  -- If d_i = 0 (Add), then we want to subtract
  XAddBarSub <= d xnor Mode;
  YAddBarSub <= d;
  ZAddBarSub <= d xor '1';

  -- Generate the shifted B inputs.
  --  0 -> 1 (+ 1)
  --  1 -> 2
  --  2 -> 3
  --  3 -> 4
  --  4 -> 4  ( 1 : 1 )
  --  5 -> 5
  --  6 -> 6
  --  7 -> 7
  --  8 -> 8
  --  9 -> 9
  --  10 -> 10
  --  11 -> 11
  --  12 -> 12
  --  13 -> 13
  --  14 -> 13 ( - 1)
  --  15 -> 14
  
  -- Generate the B inputs for the adders. Note that we must special case the sequence of indices 
  -- if Cordinate System is hyperbolic. Specifically start at iteration 1 because arctanh(2**0) =
  -- arctanh(1) is undefined. Aditionally, we must repeat iterations 4 and 13 because otherwise 
  --
  --    a_1 - \sum_{k=2}^{k=16} a_n
  --
  -- where a_i are the Z constants for the nth iteration, does not converge to zero. Thus, we obtain
  -- a mapping from i, the number of the adder, and k, the number of shifts we want to do:
  --      
  --        { i + 1   :   i < 4 
  --    k = { i       :   4 <= i <= 13
  --        { i = 1   :   i > 13
  --   
  -- Finally. Note that the ith constant is defined by
  -- 
  --    a_i = arctanh(2^-k)
  -- 
  -- For 0 <= i <= 15
  -- 
  X_BIn <= std_logic_vector((signed(YIn) sra (i + 1))) when ((CordSystem = HYPERBOLIC) and (i < 4))  else
           std_logic_vector((signed(YIn) sra (i - 1))) when ((CordSystem = HYPERBOLIC) and (i > 13)) else
           std_logic_vector((signed(YIn) sra i));

  Y_BIn <= std_logic_vector((signed(XIn) sra (i + 1))) when ((CordSystem = HYPERBOLIC) and (i < 4))  else
           std_logic_vector((signed(XIn) sra (i - 1))) when ((CordSystem = HYPERBOLIC) and (i > 13)) else
           std_logic_vector((signed(XIn) sra i));
 


          -- std_logic_vector((signed(XIn) sra i));

  -- The A input for X adders is the X Input, while the B input is the Y Input
  -- shifted right by i.
  XAdder : entity AddSub
    generic map (wordsize)
    port map (
      A           => XIn,
      B           => X_BIn,
      Cin         => XAddBarSub,
      AddBarSub   => XAddBarSub,
      Cout        => open,
      S           => XOutMux
    );

  -- The A input for Y adders is the Y input, while the B input is the X input
  -- shifted right by i.
  YAdder : entity AddSub
    generic map (wordsize)
    port map (
      A           => YIn,
      B           => Y_BIn,
      Cin         => YAddBarSub,
      AddBarSub   => YAddBarSub,
      Cout        => open,
      S           => YOut
    );

  ZAdder : entity AddSub
    generic map (wordsize)
    port map (
      A           => ZIn,
      B           => ZConstant,
      Cin         => ZAddBarSub,
      AddBarSub   => ZAddBarSub,
      Cout        => open,
      S           => ZOut
    );


end concurrent;
