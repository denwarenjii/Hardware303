-------------------------------------------------------------------------------
-- An n-bit Full Adder/Subtracter.
--
--  Revision History:
--    Date:         Author:    Description:                                   
--    24 Jan 2024   Chris M.   Initial revision
--    18 Feb 2025   Chris M.   Removed BypassAEn (input is bypassed in 
--                             CordicStage instead).
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;
use ieee.std_logic_arith.all;

-- AddSub22 entity declaration
--
-- This entity describes a 22-bit adder subtracter. 
--
--  Inputs:
--    A         : n bit input A
--    B         : n bit input B
--    Cin       : carry in
--    AddBarSub : operation select signal. Add if 0, sub if 1.
--
--  Outputs:
--    Cout      : carry/borrowbar out
--    S         : n bit result 
--
entity AddSub is
  generic (
    wordsize : positive := 22
  );
  port (
    A         : in  std_logic_vector(wordsize - 1 downto 0);
    B         : in  std_logic_vector(wordsize - 1 downto 0);
    Cin       : in  std_logic;
    AddBarSub : in  std_logic;
    Cout      : out std_logic;
    S         : out std_logic_vector(21 downto 0)
  );
end AddSub;

architecture concurrent of AddSub is

  -- 1-bit Full Adder / Subtracter
  component AdderSubtracter is
    port (
      A         : in std_logic;
      B         : in std_logic;
      Cin       : in std_logic;
      AddBarSub : in std_logic;
      Cout      : out std_logic;
      S         : out std_logic
    );
  end component;

  signal CarryBus : std_logic_vector(wordsize - 1 downto 0);

  -- An intermediate signal used to mux the 1-bit adder outputs to the 22-bit
  -- adder outputs.
  -- signal S_mux : std_logic_vector(21 downto 0);

begin -- architecture

    -- Note that `if ... generate` statements were added in VHDL-2008
    AddSub_0 :
      AdderSubtracter port map (
        A         => A(0),
        B         => B(0),
        Cin       => Cin,
        AddBarSub => AddBarSub,
        Cout      => CarryBus(0),
        S         => S(0)
      );

  AddSub_gen : 
    for i in 1 to wordsize - 1 generate
      AddSub_x : 
        AdderSubtracter port map (
          A         => A(i),
          B         => B(i),
          Cin       => CarryBus(i-1),
          AddBarSub => AddBarSub,
          Cout      => CarryBus(i),
          S         => S(i)
        );
    end generate;

    Cout <= CarryBus(wordsize - 1);

end concurrent;
