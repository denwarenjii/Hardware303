-------------------------------------------------------------------------------
-- 1-bit Full Adder/Subtracter
--
--  This entity describes a 1-bit full adder/subtracter.

--  Revision History:
--    Date:         Author:    Description:
--    07 Jan 2024   Chris M.   Initial revision; described entity and processes.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- AdderSubtracter entity declaration.
--
-- This entity describes a 1-bit adder subtracter.
--
-- Inputs:
--    A : 1-bit A input
--    B : 1-bit B input
--    Cin : 1-bit Carry input
--    AddBarSub : operation select signal. Add if 0, sub if 1.

-- Ouputs:
--    Cout      : 1-bit carry/borrowbar out
--    S         : 1-bit result 
--
entity AdderSubtracter is
  port(
    A         : in  std_logic;
    B         : in  std_logic;
    Cin       : in  std_logic;
    AddBarSub : in  std_logic;
    Cout      : out std_logic;
    S         : out std_logic
  );
end AdderSubtracter;

architecture concurrent of AdderSubtracter is
begin
  S <= A xor B xor Cin xor AddBarSub;
  Cout <= (A and Cin) or ((B xor AddBarSub) and (A or Cin));
end concurrent;
