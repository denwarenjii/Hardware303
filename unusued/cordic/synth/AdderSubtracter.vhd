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
