-------------------------------------------------------------------------------
-- Fixed Point Library Function
--
-- This file declares and defines fixed point functions, procedures, and 
-- constants used in the Cordic implementation and testbench.
--
--  Revision History:
--    Date:         Author:    Description:
--    31 Jan 2024   Chris M.   Initial revision
-------------------------------------------------------------------------------

-- libraries
library  ieee;
use  std.textio.all;
use  ieee.std_logic_1164.all;
use  ieee.numeric_std.all;
use  ieee.math_real.all;

-- Fixed point utility library declaration. Reused in test bench.
package FixedLib is

  -- The number of integer and fractional bits in a Q3.18 fixed point
  constant Q3_18_INTEGER_BITS    : integer := 4;
  constant Q3_18_FRACTIONAL_BITS : integer := 18;

  -- The number of integer and fractional bits in a Q1.14 fixed point
  constant Q1_14_INTEGER_BITS    : integer := 2;
  constant Q1_14_FRACTIONAL_BITS : integer := 14;

  -- Conversion functions. Overloaded to accept signed integers or std_logic_vectors.
  function RealToQ3_18   (real_val : real) return std_logic_vector;
  function RealToQ3_18   (real_val : real) return integer;

  function RealToQ1_14   (real_val : real) return std_logic_vector;
  function RealToQ1_14   (real_val : real) return integer;

  function Q1_14ToReal   (fixed_val : std_logic_vector) return real;
  function Q1_14ToReal   (fixed_val : integer)          return real;

  function Q3_18ToReal   (fixed_val : std_logic_vector) return real;
  function Q3_18ToReal   (fixed_val : integer)          return real;
  
  -- Get the min and max values for arbitrary fixed points.
  function GetUpperRange (IntegerBits : positive; FractionalBits : positive) return real;
  function GetLowerRange (IntegerBits : positive; FractionalBits : positive) return real;
  function GetPrecision  (IntegerBits : positive; FractionalBits : positive) return real;

  procedure PrintQ1_14_Fixed( signal   fixed   : in    std_logic_vector(15 downto 0);
                              variable my_line : inout line);
  
  procedure PrintQ3_18_Fixed( signal   fixed    : in    std_logic_vector(21 downto 0);
                              variable my_line  : inout line);

  -- Convert a Q3.18 fixed point to a Q1.14 fixed point.
  function Q3_18_To_Q1_14(slv : std_logic_vector(21 downto 0)) return std_logic_vector;

end FixedLib;

package body FixedLib is

  -----------------------------------------------------------------------------
  -- Convert real numbers to Q3_18 fixed points
  function RealToQ3_18 (real_val : real) return std_logic_vector is
    variable result  : std_logic_vector(21 downto 0);
    variable tmp     : real;
  begin
    -- Round towards zero.
    if (real_val < 0.0) then
      tmp := ceil(real_val * (2.0 ** Q3_18_FRACTIONAL_BITS));
    else
      tmp := floor(real_val * (2.0 ** Q3_18_FRACTIONAL_BITS));
    end if;
      result := std_logic_vector(to_signed(integer(tmp), 22));
    return result;
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function RealToQ3_18   (real_val : real) return integer is
    variable slv : std_logic_vector(21 downto 0);
  begin
    slv := RealToQ3_18(real_val);
    return to_integer(signed(slv));
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function RealToQ1_14 (real_val : real) return std_logic_vector is
    variable result : std_logic_vector(15 downto 0);
    variable tmp    : real;
  begin
    if (real_val < 0.0) then
      tmp := ceil(real_val * (2.0 ** Q1_14_FRACTIONAL_BITS));
    else
      tmp := floor(real_val * (2.0 ** Q1_14_FRACTIONAL_BITS));
    end if;
      result := std_logic_vector(to_signed(integer(tmp), 16));
      return result;
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function RealToQ1_14   (real_val : real) return integer is
    variable slv : std_logic_vector(15 downto 0);
  begin
    slv := RealToQ1_14(real_val);
    return to_integer(signed(slv));
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function Q1_14ToReal (fixed_val : std_logic_vector) return real is
    variable int_val : integer;
    variable result  : real;
  begin
    int_val := to_integer(signed(fixed_val));
    result  := real(int_val) / (2.0 ** 14);
    return result;
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function Q1_14ToReal   (fixed_val : integer) return real is
  begin
    return Q1_14ToReal (std_logic_vector(to_signed(fixed_val, 16)));
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function Q3_18ToReal   (fixed_val : std_logic_vector) return real is
    variable int_val : integer;
    variable result  : real;
  begin
    int_val := to_integer(signed(fixed_val));
    result  := real(int_val) / (2.0 ** 18);
    return result;
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function Q3_18ToReal   (fixed_val : integer) return real is
    variable slv : std_logic_vector(21 downto 0);
  begin
    slv := std_logic_vector(to_signed(fixed_val, 22));
    return Q3_18ToReal(slv);
  end function;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  function GetUpperRange(IntegerBits : positive; FractionalBits : positive) return real is
    variable TmpDividend  : integer;
    variable TmpDivisor   : integer;
    variable TmpReal      : real;
  begin
    TmpDivisor  := (2 ** (IntegerBits + FractionalBits - 1)) - 1;
    TmpDividend := (2 ** FractionalBits);
    TmpReal := real(TmpDivisor) / real(TmpDivisor);
    return TmpReal;
  end function;
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  function GetLowerRange(IntegerBits : positive; FractionalBits : positive) return real is
    variable TmpDividend : integer;
    variable TmpDivisor  : integer;
    variable TmpReal     : real;
  begin
    TmpDividend  := -(2 ** (IntegerBits + FractionalBits - 1));
    TmpDivisor   := (2 ** FractionalBits);
    TmpReal      := real(TmpDividend) / real(TmpDivisor);
    return TmpReal;
  end function;
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  function GetPrecision(IntegerBits : positive; FractionalBits : positive) return real is
  begin
    return (1.0 / (real (2 ** FractionalBits) ));
  end function;
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Print Q1_14 fixed point numbers
  procedure PrintQ1_14_Fixed(
                      signal   fixed    : in    std_logic_vector(15 downto 0);
                      variable my_line  : inout line) is 
    variable int_val  : integer;
    variable real_val : real;
  begin
    int_val  := to_integer(signed(fixed));
    real_val := real(int_val) / (2.0 ** 14);
    write(my_line, HT);
    write(my_line, real_val, LEFT, 12, 9);
    write(my_line, string'(HT & LF));
  end procedure;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Print Q3_18 fixed point numbers
  procedure PrintQ3_18_Fixed(
                      signal   fixed    : in    std_logic_vector(21 downto 0);
                      variable my_line  : inout line) is 
    variable int_val  : integer;
    variable real_val : real;
  begin
    int_val  := to_integer(signed(fixed));
    real_val := real(int_val) / (2.0 ** 18);
    write(my_line, HT);
    write(my_line, real_val, LEFT, 12, 9);
    write(my_line, HT);
  end procedure;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Convert a Q3.18 fixed point to a Q1.14 fixed point.
  function Q3_18_To_Q1_14(slv : std_logic_vector(21 downto 0)) return std_logic_vector is
  begin
    return slv(21) & slv(18) & slv(17 downto 4);
  end function;
  -----------------------------------------------------------------------------

end package body FixedLib;

