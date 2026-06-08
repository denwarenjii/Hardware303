---------------------------------------------------------------------------------------------------
-- 16-bit Q1.14 Cordic Calculator Testbench
--
--  This entity implements a test bench for a 16-bit Q1.14 Cordic calculator.
--  Test values are compared against standard library functions

--  Revision History:
--    Date:         Author:    Description:
--    07 Jan 2024   Chris M.   Initial revision; described entity and processes.
--    18 Feb 2025   Chris M.   Converted to OSVVM.
--    21 Feb 2025   Chris M.   Restructured tests to include function type in bin
--  TODO:
--    - Decrease error in hyperbolic functions.
--    - Make tests actually random (maybe make all bins pick X and Y and then repick based on the
--      function to make sure it won't overflow...)
---------------------------------------------------------------------------------------------------

-- libraries
library ieee;
library std;
library osvvm;
library work;

use ieee.std_logic_1164.all;      -- For std_logic operations
use ieee.std_logic_unsigned.all;  -- For unsigned operations
use ieee.numeric_std.all;         --
use ieee.std_logic_textio.all;    -- For std_logic IO
use std.textio.all;               -- For text IO
use std.env.all;                  
use ieee.math_real.all;           -- For trig and arithmetic functions.

use osvvm.RandomPkg.all;          
use osvvm.CoveragePkg.all;
use osvvm.TranscriptPkg.all ;
context osvvm.OsvvmContext;
 
use work.CordicConstants.all;     -- Cordic constants.
use work.FixedLib.all;            -- Fixed point conversion and printing libs
use work.all;                     
use ANSIEscape.all;               -- ANSI Escape sequences for printing color.

entity Cordic_TB is
end Cordic_TB;

architecture TestBench of Cordic_TB is

  constant WORD_SIZE : positive := 16;

  signal ClkEn    : std_logic := '1';
  signal Clk_Tb   : std_logic;
  signal X_Tb     : std_logic_vector(15 downto 0);
  signal Y_Tb     : std_logic_vector(15 downto 0);
  signal Func_Tb  : std_logic_vector(4  downto 0);
  signal R_Tb     : std_logic_vector(15 downto 0);


  -- Convert std_logic_vectors to unsigned ints
  function slv_to_uint(slv : std_logic_vector) return integer is
  begin
    return to_integer(unsigned(slv));
  end function;

  -- Repeat a char n times and return a string.
  function RepeatChar(c : character; n : positive) return string is 
    variable Result : string(1 to n) := (others => ' ');
  begin
    for i in 1 to n loop
      Result(i) := c; 
    end loop;
    return Result;
  end function;

  -- Convert signed ints to std_logic_vectors.
  function int_to_slv(i : integer; width : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(i, width));
  end function;

  -- Convert std_logic_vectors to signed ints.
  function slv_to_int(slv : std_logic_vector) return integer is
  begin
    return to_integer(signed(slv));
  end function;

  -- Convert unsigned ints to std_logic_vectors.
  function uint_to_slv(i : natural; width : positive) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, width));
  end function;

  -- Convert std_logic to bit. (Unusued.)
  -- function ToBit(sl : std_logic) return bit is
  -- begin
  --   if ((sl /= '1') and (sl /= '0')) then
  --     return '0';
  --   elsif (sl = '0') then
  --     return '0';
  --   else
  --     return '1';
  --   end if;
  -- end function;

  -- Convert bit to std_logic. (Unused.)
  -- function ToStdLogic(b : bit) return std_logic is
  -- begin
  --   if (b = '0') then
  --     return '0';
  --   else
  --     return '1';
  --   end if;
  -- end function;
  
  -- Period for a 1GHz clock
  constant CLK_PERIOD : time  := (1 sec / (1e9));

  -- The min and max Q1.14 fixed point values represented as reals.
  constant MIN_REAL_VAL : real := -2.0;
  constant MAX_REAL_VAL : real := 1.9999;

  -- The min and max angles such that trig functions converge represented as reals.
  constant MIN_REAL_ANGLE : real := 0.0;
  constant MAX_REAL_ANGLE : real := MATH_PI / 2.0;

  -- The min and max Q1.14 fixed point values represented as Q1.14 fixed points.
  constant MIN_FIXED_VAL : std_logic_vector(WORD_SIZE - 1 downto 0) := RealToQ1_14(MIN_REAL_VAL);
  constant MAX_FIXED_VAL : std_logic_vector(WORD_SIZE - 1 downto 0) := RealToQ1_14(MAX_REAL_VAL);

  -- The min and max angles such that trig functions converge represented as Q1.14 fixed points.
  constant MIN_FIXED_ANGLE : std_logic_vector(WORD_SIZE - 1 downto 0) := RealToQ1_14(MIN_REAL_ANGLE);
  constant MAX_FIXED_ANGLE : std_logic_vector(WORD_SIZE - 1 downto 0) := RealToQ1_14(MAX_REAL_ANGLE);

  -- Hyperbolic functions do not converge for x > +- 1.11 (the sum of the hyperbolic constansts) 
  -- see Walther, 1971. Ours converges within the minimum preicsion for x <= +-1.09 (why?)
  constant MAX_HYPERBOLIC_ARG : std_logic_vector(WORD_SIZE - 1 downto 0) := RealToQ1_14(1.06);
  constant MIN_HYPERBOLIC_ARG : std_logic_vector(WORD_SIZE - 1 downto 0) := RealToQ1_14(-1.06);

  -- Integer and fractional bits for a Q1.14 fixed point.
  constant INTEGER_BITS    : positive := 2;
  constant FRACTIONAL_BITS : positive := 14;

  -- The precision of a Q1.14 fixed point.
  constant PRECISION : real := (1.0 / (2.0 ** FRACTIONAL_BITS));

  -- Checks if a a function will overflow (ie, be more than the range representable by a Q1.14
  -- fixed point).
  function WillOverflow(X : real; Y : real; 
                        Func : std_logic_vector) return boolean is 
  begin
    case (Func) is
      when F_COS_X =>
        if ((cos(x) > MAX_REAL_VAL) or (cos(x) < MIN_REAL_VAL)) then
          return true;
        end if;
      when F_SIN_X =>
        if ((sin(x) > MAX_REAL_VAL) or (sin(x) < MIN_REAL_VAL)) then
          return true;
        end if;
      when F_X_MULT_Y =>
        if (((x * y) > MAX_REAL_VAL) or ((x * y) < MIN_REAL_VAL)) then
          return true;
        end if;
      when F_COSH_X =>
        if ((cosh(x) > MAX_REAL_VAL) or (cosh(x) < MIN_REAL_VAL)) then
          return true;
        end if;
      when F_SINH_X =>
        if ((sinh(x) > MAX_REAL_VAL) or (sinh(x) < MIN_REAL_VAL)) then
          return true;
        end if;
      when F_Y_DIV_X =>
        if (x = 0.0) then
          -- Anything divided by zero is undefined
          return true;
        elsif ( ((y / x) > MAX_REAL_VAL) or ( (y/x) < MIN_REAL_VAL)) then
          return true;
        end if;
      when others =>
        report "Unknown operation"
        severity ERROR;
    end case;
    return false;
  end function;

  constant ZERO : std_logic_vector(WORD_SIZE - 1 downto 0) := (others => '0');

  constant SPECIAL_CASE   : integer := RealToQ1_14(0.75);
  constant SPECIAL_CASE_1 : integer := RealToQ1_14(0.25);

  -- Bins for the function select lines.
  constant TRIG_FUNC_BIN : CovBinType :=
    GenBin(slv_to_uint(F_COS_X)) & GenBin(slv_to_uint(F_SIN_X));

  constant LINEAR_FUNC_BIN : CovBinType :=
    GenBin(slv_to_uint(F_X_MULT_Y)) & GenBin(slv_to_uint(F_Y_DIV_X));

  constant HYPERBOLIC_FUNC_BIN : CovBinType :=
    GenBin(slv_to_uint(F_COSH_X)) & GenBin(slv_to_uint(F_SINH_X));

  -- Bins for trig function inputs. The test strategy for trig functions is to have 7 bins total.
  -- 4 bins consist of the range of valid inputs for trig functions, divided into 4 sections, and
  -- the other three are likely edge cases (min, max, and zero).
  constant TRIG_X_BIN : CovBinType :=
    GenBin(slv_to_int(MIN_FIXED_ANGLE), slv_to_int(MAX_FIXED_ANGLE), 4) &
    GenBin(slv_to_int(MIN_FIXED_ANGLE)) & GenBin(slv_to_int(MAX_FIXED_ANGLE)) & 
    GenBin(slv_to_int(ZERO));

  -- Bins for hyperbolic functions. The test strategy is the same as trig functions but with
  -- different upper/lower limits.
  constant HYPER_X_BIN : CovBinType :=
    GenBin(slv_to_int(MIN_HYPERBOLIC_ARG), slv_to_int(MAX_HYPERBOLIC_ARG), 4) &
    GenBin(slv_to_int(MIN_HYPERBOLIC_ARG)) & GenBin(slv_to_int(MAX_HYPERBOLIC_ARG)) &
    GenBin(slv_to_int(ZERO));

  -- Bins for linear functions. They consists of the range of our fixed points divided into 4 
  -- sections. Note that we do not include bins for max and min values because cross binning would
  -- generate bins that will overflow and thus never be covered (such as 2.0 * 2.0, etc).
  constant LINEAR_X_BIN : CovBinType :=
    GenBin(slv_to_int(MIN_FIXED_VAL), slv_to_int(MAX_FIXED_VAL), 4);

  constant LINEAR_Y_BIN : CovBinType :=
    GenBin(slv_to_int(MIN_FIXED_VAL), slv_to_int(MAX_FIXED_VAL), 4);

  -- Coverage IDs
  signal CordicTrigCovID   : CoverageIdType := NewId("Trig Cordic Coverage");
  signal CordicLinearCovID : CoverageIdType := NewId("Linear Cordic Coverage");
  signal CordicHyperCovID  : CoverageIdType := NewId("Hyperbolic Cordic Coverage");

  -- Log ID
  signal CordicTBLogID       : AlertLogIDType := GetAlertLogID("Cordic_TB");
 

  -- A 3-tuple of 7 char strings
  type String3Tup is array(0 to 2) of string(1 to 7);

  -- subtype UnsignedWordInt is integer range 0 to 2**WORD_SIZE - 1;
  subtype SignedWordInt   is integer range -(2 ** (WORD_SIZE - 1)) to (2 ** (WORD_SIZE - 1)) - 1;

  -- A 3-tuple of integers
  type Int3Tup is array(0 to 2) of SignedWordInt;

  -- Print the current function to the debug stream
  procedure PrintFunc(X : integer; Y : SignedWordInt; Func : SignedWordInt) is
  begin
    case int_to_slv(Func, Func_TB'length) is
      when F_COS_X =>
        Log("Picked:" & HT & "cos(" & to_string(Q1_14ToReal(X)) & ")", DEBUG);
      when F_SIN_X =>
        Log("Picked:" & HT & "sin(" & to_string(Q1_14ToReal(X)) & ")", DEBUG);
      when F_COSH_X =>
        Log("Picked:" & HT & "cosh(" & to_string(Q1_14ToReal(X)) & ")", DEBUG);
      when F_SINH_X =>
        Log("Picked:" & HT & "sinh(" & to_string(Q1_14ToReal(X)) & ")", DEBUG);
      when F_X_MULT_Y =>
        LOG("Picked:" & HT & to_string(Q1_14ToReal(X)) & " * " & 
                  to_string(Q1_14ToReal(Y)), DEBUG);
      when F_Y_DIV_X =>
        Log("Picked:" & HT & to_string(Q1_14ToReal(Y)) & " / " & 
                  to_string(Q1_14ToReal(X)), DEBUG);
      when others =>
        Log("Unknown function: " & to_string(Func), DEBUG);
    end case;
  end procedure;

begin

  -- Wire the entity
  UUT : entity Cordic
  port map (
    CLK   => CLK_TB,
    X     => X_TB,
    Y     => Y_TB,   
    Func  => Func_TB,
    R     => R_TB
  );

  -- Generate the clock
  GenClk : process
  begin
    if    (ClkEn = '1') then
      Clk_TB <= '0';
      wait for CLK_PERIOD / 2;
      Clk_TB <= '1';
      wait for CLK_PERIOD / 2;
    else
      wait until ClkEn = '1';
    end if;
  end process;

  SetTestName("CORDIC Tests");

  SetLogEnable(PASSED, true);
  SetLogEnable(DEBUG,  false);
  SetLogEnable(INFO,   false);

  -- AddCross(<ID : CoverageIdType>, <CovGoal : integer>, <Bins : CovBinType>, ... );

  -- Cross the bins.
  AddCross(CordicTrigCovID,   4, TRIG_FUNC_BIN,       TRIG_X_BIN);
  AddCross(CordicLinearCovID, 4, LINEAR_FUNC_BIN,     LINEAR_X_BIN, LINEAR_Y_BIN);
  AddCross(CordicHyperCovID,  4, HYPERBOLIC_FUNC_BIN, HYPER_X_BIN);

  -- CheckEdge : process
  -- begin
  --   if rising_edge(Clk_TB) then
  --     Log (CordicTBLogID, "Rising Edge ", ALWAYS);
  --     Log (CordicTBLogID, HT & "R: " & to_string(R_TB), ALWAYS);
  --   end if;
  -- end process;

  RunTest : process(Clk_TB)

    -- The random variable
    variable RV : RandomPType;

    -- The current Function, X, and Y as (unsigned) integers
    variable CurrentFunc : SignedWordInt;
    variable CurrentX    : SignedWordInt;
    variable CurrentY    : SignedWordInt;

    -- The expected result as an unsigned integer.
    variable ExpectedResult    : SignedWordInt := 0;

    -- The current function as a string.
    variable CurrentFuncString : string(1 to 7) := (others => ' ');

    -- The past 3 functions, X, and Y as unsigned integers.
    variable PrevFuncSync : Int3Tup := ( 0, 0, 0 ) ;
    variable PrevXSync    : Int3Tup := ( 0, 0, 0 );
    variable PrevYSync    : Int3Tup := ( 0, 0, 0 );

    -- The past 3 functions as strings.
    variable PrevFuncStringSync     : String3Tup := 
      ( (others => ' '), (others => ' '), (others => ' ') );

    -- The past 3 results as unsigned integers.
    variable PrevExpectedResultSync : Int3Tup := ( 0, 0, 0 );

    -- Check if the RV has been seeded
    variable Seeded : boolean := false;

    -- The number of rising edges that have occurred.
    variable EdgeCount : integer := 0;

    variable Cond : boolean;
    variable Color : string(1 to 5) := (others => ' ');

    variable TmpFunc : SignedWordInt := 0;
    variable TmpX    : SignedWordInt := 0;
    variable TmpY    : SignedWordInt := 0;

    variable Diff : real := 0.0;

    variable TrigDone   : boolean := false;
    variable LinearDone : boolean := false;
    variable HyperDone  : boolean := false;

    -- variable test_int  : integer := 0;
    -- variable test_real : real    := 0.0;

  begin

    if (not Seeded) then

      Log("Seeding Random Variable ..." ,  ALWAYS);
      Log("Min Fixed Val is      " & to_string(Q1_14ToReal(MIN_FIXED_VAL)) & 
          " (" & to_string(slv_to_int(MIN_FIXED_VAL)) & ")", ALWAYS);
      Log("Max Fixed Val is      " & to_string(Q1_14ToReal(MAX_FIXED_VAL)) &
          " (" & to_string(slv_to_int(MAX_FIXED_VAL)) & ")", ALWAYS);
      Log("Min Fixed Angle is    " & to_string(Q1_14ToReal(MIN_FIXED_ANGLE)) &
          " (" & to_string(slv_to_int(MIN_FIXED_ANGLE)) & ")", ALWAYS);
      Log("Max Fixed Angle is    " & to_string(Q1_14ToReal(MAX_FIXED_ANGLE)) &
          " (" & to_string(slv_to_int(MAX_FIXED_ANGLE)) & ")", ALWAYS);
      Log("Min Hyperbolic Arg is " & to_string(Q1_14ToReal(MIN_HYPERBOLIC_ARG)) &
          " (" & to_string(slv_to_int(MIN_HYPERBOLIC_ARG)) & ")", ALWAYS);
      Log("Max Hyperbolic Arg is " & to_string(Q1_14ToReal(MAX_HYPERBOLIC_ARG)) &
          " (" & to_string(slv_to_int(MAX_HYPERBOLIC_ARG)) & ")", ALWAYS);

      -- Seed the random variable
      RV.InitSeed(RV'instance_name);
      Seeded := true;

      if  (IsLogEnabled(DEBUG))  then Log("Logging Enabled", DEBUG);  end if;
      if  (IsLogEnabled(PASSED)) then Log("Logging Enabled", PASSED); end if;

    elsif (falling_edge(Clk_TB)) then

      Log(YELLOW & "Falling Edge" & ANSI_RESET, DEBUG);

      -- Skip the first 2 checks while we wait for the results to come in
      if (EdgeCount < 2) then
        EdgeCount  := EdgeCount + 1;
        Log("Skipping...", DEBUG);
      else

        -- The test has passed if the result is within the precision allowed by a Q1.14 fixed point
        Diff  := Q1_14ToReal(R_TB) - Q1_14ToReal(PrevExpectedResultSync(0));
        Cond  := (abs(Diff) <= PRECISION);

        -- Highlight green if passes, red if failed.
        if (Cond) then 
          Color := GREEN; 
        else 
          Color := RED; 
        end if;

        -- Log prev functions and inputs.
        Log(to_string(LF), DEBUG);
        Log(          "PrevFuncStringSync(2): " & PrevFuncStringSync(2) , DEBUG);
        Log(          "PrevFuncStringSync(1): " & PrevFuncStringSync(1) , DEBUG);
        Log(MAGENTA & "PrevFuncStringSync(0): " & PrevFuncStringSync(0) & ANSI_RESET, DEBUG);
        Log(to_string(LF), DEBUG);
        Log(          "PrevXSync(2): "           & to_string(Q1_14ToReal(PrevXSync(2))) , DEBUG);
        Log(          "PrevXSync(1): "           & to_string(Q1_14ToReal(PrevXSync(1))) , DEBUG);
        Log(MAGENTA & "PrevXSync(0): " & to_string(Q1_14ToReal(PrevXSync(0))) & ANSI_RESET, DEBUG);
        Log(to_string(LF), DEBUG);
        Log(          "PrevYSync(2): "           & to_string(Q1_14ToReal(PrevYSync(2))) , DEBUG);
        Log(          "PrevYSync(1): "           & to_string(Q1_14ToReal(PrevYSync(1))) , DEBUG);
        Log(MAGENTA & "PrevYSync(0): " & to_string(Q1_14ToReal(PrevYSync(0))) & ANSI_RESET, DEBUG);
        Log(to_string(LF), DEBUG);

        -- AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage : string ;
        --           ExpectedMessage : string ; Enable : boolean := FALSE) ;
        AffirmIf (
          CordicTBLogID,
          Cond,

          -- Received message
          Color & 
          PrevFuncStringSync(0) & 
          " X: " & to_string(Q1_14ToReal(PrevXSync(0)), 6) & 
          " ("   & to_string(int_to_slv(PrevXSync(0), WORD_SIZE)) & ") " &
          " Y: " & to_string(Q1_14ToReal(PrevYSync(0)), 6) & " " &
          " ("   & to_string(int_to_slv(PrevYSync(0), WORD_SIZE)) & ") " &
          HT & "Received: " & to_string (Q1_14ToReal(R_TB), 6) & " ( " & to_string(R_TB) & " ) " & ANSI_RESET,

          -- Expected message
          HT & Color & "PrevExpectedResult(0) is " & to_string(Q1_14ToReal(PrevExpectedResultSync(0)), 6) &
          " (" & to_string(int_to_slv(PrevExpectedResultSync(0), WORD_SIZE)) & ")" & ANSI_RESET & 
          " Diff: " & to_string(Diff)
        );
      end if;

      -- We only want to print these messages once - the first time we see that they are covered.
      if (IsCovered(CordicTrigCovID) and not TrigDone) then
        Log(MAGENTA & "All trig tests finished." & ANSI_RESET, ALWAYS);
        TrigDone := true;
      end if;

      if (IsCovered(CordicLinearCovID) and not LinearDone) then
        Log(MAGENTA & "All linear tests finished." & ANSI_RESET, ALWAYS);
        LinearDone := true;
      end if;

      if (IsCovered(CordicHyperCovID) and not HyperDone) then
        Log(MAGENTA & "All hyperbolic tests finished." & ANSI_RESET, ALWAYS);
        HyperDone := true;
      end if;

      if (IsCovered(CordicTrigCovID) and IsCovered(CordicLinearCovID) and
          IsCovered(CordicHyperCovID)) 
      then
        Log("All tests finished.", ALWAYS);
        ReportAlerts;
        finish;
      else
       
        -- Test trig, linear, then hyperbolic.
        if    (not IsCovered(CordicTrigCovID)) then

          -- Loop until we have found a value that won't overflow
          while (true) loop

            -- Pick a random point. Note that we only set the Current values to these
            -- values once we are sure they won't overflow.
            (TmpFunc, TmpX) := GetRandPoint(CordicTrigCovID);

            case uint_to_slv(TmpFunc, Func_TB'length) is

              when F_COS_X    =>

                if ( WillOverflow( X => Q1_14ToReal(TmpX), 
                                   Y => 0.0,
                                   Func => uint_to_slv(TmpFunc, Func_TB'length)))
                then
                  Log(HT & "cos(" & to_string(Q1_14ToReal(TmpX)) & ")" & 
                           " will overflow, aborting test...", INFO);
                else

                  -- Store the prev values and set the current ones.
                  PrevFuncSync(1 to 2) := PrevFuncSync(0 to 1);
                  PrevFuncSync(0)      := CurrentFunc;
                  CurrentFunc          := TmpFunc;
                  
                  PrevXSync(1 to 2)    := PrevXSync(0 to 1);
                  PrevXSync(0)         := CurrentX;
                  CurrentX             := TmpX;
                  
                  PrevYSync(1 to 2)    := PrevYSync(0 to 1);
                  PrevYSync(0)         := CurrentY;
                  
                  PrevFuncStringSync(1 to 2) := PrevFuncStringSync(0 to 1);
                  PrevFuncStringSync(0)      := CurrentFuncString;
                  CurrentFuncString          := "cos(x) ";
                  
                  PrevExpectedResultSync(1 to 2) := PrevExpectedResultSync(0 to 1);
                  PrevExpectedResultSync(0)      := ExpectedResult;
                  
                  -- Calculate the expected result.
                  ExpectedResult  := RealToQ1_14( cos (Q1_14ToReal(CurrentX)));

                  -- Set the inputs.
                  Func_TB         <= uint_to_slv(CurrentFunc, Func_TB'length);
                  X_TB            <= int_to_slv(CurrentX, WORD_SIZE);
                  Y_TB            <= (others => '0');
                  
                  -- Mark the test as covered.
                  ICover(CordicTrigCovID, (CurrentFunc, CurrentX));
                  Log(CordicTBLogID, " (Trig is " & to_string(GetCov(CordicTrigCovID), 3) & "% covered) ", INFO);

                  -- Stop looping.
                  exit;

                end if; -- WillOverflow(...)

              when F_SIN_X    =>

                if ( WillOverflow( X => Q1_14ToReal(TmpX), 
                                   Y => 0.0, 
                                   Func => uint_to_slv(TmpFunc, Func_TB'length)))
                then
                  Log(HT & "sin(" & to_string(Q1_14ToReal(TmpX)) & ") " & 
                           "will overflow, aborting test...", INFO);
                else

                  -- Store the prev values and set the current ones.
                  PrevFuncSync(1 to 2) := PrevFuncSync(0 to 1);
                  PrevFuncSync(0)      := CurrentFunc;

                  CurrentFunc          := TmpFunc;
                  PrevXSync(1 to 2)    := PrevXSync(0 to 1);
                  PrevXSync(0)         := CurrentX;

                  PrevYSync(1 to 2)    := PrevYSync(0 to 1);
                  PrevYSync(0)         := CurrentY;
                  CurrentX             := TmpX;

                  PrevFuncStringSync(1 to 2) := PrevFuncStringSync(0 to 1);
                  PrevFuncStringSync(0)      := CurrentFuncString;
                  CurrentFuncString          := "sin(x) ";

                  PrevExpectedResultSync(1 to 2) := PrevExpectedResultSync(0 to 1);
                  PrevExpectedResultSync(0)      := ExpectedResult;

                  -- Calculate the expected result.
                  ExpectedResult      := RealToQ1_14( sin (Q1_14ToReal(CurrentX)) );

                  -- Set the inputs.
                  Func_TB             <= uint_to_slv(CurrentFunc, Func_TB'length);
                  X_TB                <= int_to_slv(CurrentX, WORD_SIZE);
                  Y_TB                <= (others => '0');

                  -- Mark the test as covered.
                  ICover(CordicTrigCovID, (CurrentFunc, CurrentX));
                  Log(CordicTBLogID, " (Trig is " & to_string(GetCov(CordicTrigCovID), 3) & "% covered) ", INFO);
                  -- Stop looping.
                  exit;

                end if; -- WillOverflow(...)

                when others =>
                  Alert("Unknown function " & to_string(uint_to_slv(TmpFunc, Func_TB'length)) & 
                      " in trig tests.", ERROR);
              end case; -- uint_to_slv(TmpFunc, Func_TB'length)
            end loop;  -- while (true)

          -- Log Debug info.
          Log(RepeatChar('-', 100), DEBUG);
          PrintFunc(CurrentX, CurrentY, CurrentFunc);
          Log("Current X: " & to_string(Q1_14ToReal(CurrentX), 4), DEBUG);
          Log("Current Y: " & to_string(Q1_14ToReal(CurrentY), 4), DEBUG);
          Log("Expected:  " & to_string(Q1_14ToReal(ExpectedResult), 4), DEBUG);
          Log(RepeatChar('-', 100), DEBUG);


        elsif (not IsCovered(CordicLinearCovID)) then

          -- All trig tests done, test linear.

          -- Loop until we have found a value that won't overflow.
          while (true) loop

            -- Pick a random point. Note that we only set the Current values to these
            -- values once we are sure they won't overflow.
            (TmpFunc, TmpX, TmpY) := GetRandPoint(CordicLinearCovID);

            case uint_to_slv(TmpFunc, Func_TB'length) is

              when F_X_MULT_Y =>

                if (WillOverflow(X => Q1_14ToReal(TmpX), 
                                 Y => Q1_14ToReal(TmpY), 
                                 Func => uint_to_slv(TmpFunc, Func_TB'length)))
                then
                  Log(HT & "(" & to_string(Q1_14ToReal(TmpX)) & " * " & 
                                  to_string(Q1_14ToReal(TmpY)) & ")" & 
                          "will overflow, aborting test...", INFO);
                else

                  -- Store the prev values and set the current ones.
                  PrevFuncSync(1 to 2) := PrevFuncSync(0 to 1);
                  PrevFuncSync(0)      := CurrentFunc;
                  CurrentFunc          := TmpFunc;

                  PrevXSync(1 to 2)    := PrevXSync(0 to 1);
                  PrevXSync(0)         := CurrentX;

                  PrevYSync(1 to 2)    := PrevYSync(0 to 1);
                  PrevYSync(0)         := CurrentY;

                  CurrentX := TmpX;
                  CurrentY := TmpY;

                  PrevFuncStringSync(1 to 2) := PrevFuncStringSync(0 to 1);
                  PrevFuncStringSync(0)      := CurrentFuncString;
                  CurrentFuncString          := "x*y    ";

                  PrevExpectedResultSync(1 to 2) := PrevExpectedResultSync(0 to 1);
                  PrevExpectedResultSync(0)      := ExpectedResult;

                  -- Calculate the expected result.
                  ExpectedResult  := RealToQ1_14(Q1_14ToReal(CurrentX) * Q1_14ToReal(CurrentY));

                  -- Set the inputs.
                  Func_TB         <= uint_to_slv(CurrentFunc, Func_TB'length);
                  X_TB            <= int_to_slv(CurrentX, WORD_SIZE);
                  Y_TB            <= int_to_slv(CurrentY, WORD_SIZE);

                  -- Mark the test as covered.
                  ICover (CordicLinearCovID, (CurrentFunc, CurrentX, CurrentY));
                  Log(CordicTBLogID, " (Linear is " & to_string(GetCov(CordicLinearCovID), 3) & 
                                     "% covered) ", INFO);
                  exit;

                end if; -- WillOverflow(...)


              when F_Y_DIV_X  =>

                if (WillOverflow(X => Q1_14ToReal(TmpX), 
                                 Y => Q1_14ToReal(TmpY), 
                                 Func => uint_to_slv(TmpFunc, Func_TB'length)))
                then
                  Log(HT & "(" & to_string(Q1_14ToReal(TmpY)) & " / " & 
                                 to_string(Q1_14ToReal(TmpX)) & 
                      ") will overflow, aborting test...", INFO);
                else

                  -- Store the prev values and set the current ones.
                  PrevFuncSync(1 to 2) := PrevFuncSync(0 to 1);
                  PrevFuncSync(0)      := CurrentFunc;
                  CurrentFunc          := TmpFunc;

                  PrevXSync(1 to 2) := PrevXSync(0 to 1);
                  PrevXSync(0)      := CurrentX;

                  PrevYSync(1 to 2) := PrevYSync(0 to 1);
                  PrevYSync(0)      := CurrentY;

                  CurrentX := TmpX;
                  CurrentY := TmpY;

                  PrevFuncStringSync(1 to 2) := PrevFuncStringSync(0 to 1);
                  PrevFuncStringSync(0)      := CurrentFuncString;
                  CurrentFuncString          := "y/x    ";

                  PrevExpectedResultSync(1 to 2) := PrevExpectedResultSync(0 to 1);
                  PrevExpectedResultSync(0)      := ExpectedResult;

                  -- Calculate the expected result.
                  ExpectedResult := RealToQ1_14(Q1_14ToReal(CurrentY) / Q1_14ToReal(CurrentX));

                  -- Set the inputs.
                  Func_TB        <= uint_to_slv(CurrentFunc, Func_TB'length);
                  X_TB           <= int_to_slv(CurrentX, WORD_SIZE);
                  Y_TB           <= int_to_slv(CurrentY, WORD_SIZE);

                  -- Mark the test as covered.
                  ICover (CordicLinearCovID, (CurrentFunc, CurrentX, CurrentY));
                  Log(CordicTBLogID, " (Linear is " & to_string(GetCov(CordicLinearCovID), 3) & 
                                    "% covered) ", INFO);
                  exit;
                end if; -- WillOverflow(...)

              when others => 
                Alert("Unknown function " & to_string(uint_to_slv(TmpFunc, Func_TB'length)) & 
                    " in linear tests.", ERROR);
                stop(1);

            end case;  -- uint_to_slv(TmpFunc)
          end loop; -- while (true)

         Log(RepeatChar('-', 100), DEBUG);
         PrintFunc(CurrentX, CurrentY, CurrentFunc);
         Log("Current X: " & to_string(Q1_14ToReal(CurrentX), 4), DEBUG);
         Log("Current Y: " & to_string(Q1_14ToReal(CurrentY), 4), DEBUG);
         Log("Expected:  " & to_string(Q1_14ToReal(ExpectedResult), 4), DEBUG);
         Log(RepeatChar('-', 100), DEBUG);


        elsif (not IsCovered(CordicHyperCovID)) then
          -- All trig and linear tests done, test hyperbolic.

          -- Loop until we have found a value that won't overflow
          while (true) loop

            -- Pick a random point. Note that we only set the Current values to these
            -- values once we are sure they won't overflow.
            (TmpFunc, TmpX) := GetRandPoint(CordicHyperCovID);

            case uint_to_slv(TmpFunc, Func_TB'length) is

              when F_COSH_X   =>

                if ( WillOverflow( X    => Q1_14ToReal(TmpX), 
                                   Y    => 0.0, 
                                   Func => uint_to_slv(TmpFunc, Func_TB'length)))
                then
                  Log(HT & "cosh(" & to_string(Q1_14ToReal(TmpX)) & ") will overflow, aborting test...", INFO);
                else

                  -- Store the prev values and set the current ones.
                  PrevFuncSync(1 to 2) := PrevFuncSync(0 to 1);
                  PrevFuncSync(0)      := CurrentFunc;
                  CurrentFunc          := TmpFunc;

                  PrevXSync(1 to 2)    := PrevXSync(0 to 1);
                  PrevXSync(0)         := CurrentX;
                  CurrentX             := TmpX;

                  PrevYSync(1 to 2)    := PrevYSync(0 to 1);
                  PrevYSync(0)         := CurrentY;

                  PrevFuncStringSync(1 to 2) := PrevFuncStringSync(0 to 1);
                  PrevFuncStringSync(0)      := CurrentFuncString;
                  CurrentFuncString          := "cosh(x)";

                  PrevExpectedResultSync(1 to 2) := PrevExpectedResultSync(0 to 1);
                  PrevExpectedResultSync(0)      := ExpectedResult;

                  -- Calculate the expected result.
                  ExpectedResult      := RealToQ1_14( cosh (Q1_14ToReal(CurrentX)));

                  -- Set the inputs.
                  Func_TB             <= uint_to_slv(CurrentFunc, Func_TB'length);
                  X_TB                <= int_to_slv(CurrentX, WORD_SIZE);
                  Y_TB                <= (others => '0');

                  -- Mark the test as covered.
                  ICover(CordicHyperCovID, (CurrentFunc, CurrentX));
                  Log(CordicTBLogID, " (Hyperbolic is " & to_string(GetCov(CordicHyperCovID), 3) & 
                                     "% covered) ", INFO);
                  exit;
                end if; -- WillOverflow(...)

              when F_SINH_X   =>

                if ( WillOverflow( X    => Q1_14ToReal(TmpX), 
                                   Y    => 0.0, 
                                   Func => uint_to_slv(TmpFunc, Func_TB'length)))
                then
                  Log(HT & "sinh(" & to_string(Q1_14ToReal(TmpX)) & ") will overflow, aborting test...", INFO);
                else
                  -- Store the prev values and set the current ones.
                  PrevFuncSync(1 to 2) := PrevFuncSync(0 to 1);
                  PrevFuncSync(0)      := CurrentFunc;
                  CurrentFunc          := TmpFunc;

                  PrevXSync(1 to 2)    := PrevXSync(0 to 1);
                  PrevXSync(0)         := CurrentX;
                  CurrentX             := TmpX;

                  PrevYSync(1 to 2)    := PrevYSync(0 to 1);
                  PrevYSync(0)         := CurrentY;

                  PrevFuncStringSync(1 to 2) := PrevFuncStringSync(0 to 1);
                  PrevFuncStringSync(0)      := CurrentFuncString;
                  CurrentFuncString          := "sinh(x)";

                  PrevExpectedResultSync(1 to 2) := PrevExpectedResultSync(0 to 1);
                  PrevExpectedResultSync(0)      := ExpectedResult;

                  -- Calculate the expected result.
                  ExpectedResult      := RealToQ1_14( sinh (Q1_14ToReal(CurrentX)));

                  -- Set the inputs.
                  Func_TB             <= uint_to_slv(CurrentFunc, Func_TB'length);
                  X_TB                <= int_to_slv(CurrentX, WORD_SIZE);
                  Y_TB                <= (others => '0');

                  -- Mark the test as covered.
                  ICover(CordicHyperCovID, (CurrentFunc, CurrentX));
                  Log(CordicTBLogID, " (Hyperbolic is " & to_string(GetCov(CordicHyperCovID), 3) & 
                                     "% covered) ", INFO);
                  exit;
                end if; -- WillOverflow(...)

              when others =>
                Alert("Unknown function " & to_string(uint_to_slv(TmpFunc, Func_TB'length)) & 
                    " in hyperbolic tests.", ERROR);
                stop(1);

            end case;  -- uint_to_slv(TmpFunc, Func_TB'length)
          end loop; -- while (true)

          Log(RepeatChar('-', 100), DEBUG);
          PrintFunc(CurrentX, CurrentY, CurrentFunc);
          Log("Current X: " & to_string(Q1_14ToReal(CurrentX), 4), DEBUG);
          Log("Current Y: " & to_string(Q1_14ToReal(CurrentY), 4), DEBUG);
          Log("Expected:  " & to_string(Q1_14ToReal(ExpectedResult), 4), DEBUG);
          Log(RepeatChar('-', 100), DEBUG);

        end if; -- (not IsCovered(CordicTrigCovID))
      end if; -- IsCovered (<all three CovIDs>)
    end if; -- rising_edge(Clk)
  end process; -- RunTest

  CheckEdge : process(Clk_Tb)
  begin
    if rising_edge(Clk_TB) then
      -- Log (CordicTBLogID, "Rising edge ", ALWAYS);
      -- Log (CordicTBLogID, HT & "R: " & to_hstring(R_Tb), ALWAYS);
    elsif falling_edge(Clk_Tb) then
      -- Log (CordicTBLogID, "Falling edge", ALWAYS);
      -- Log (CordicTBLogID, HT & "R: " & to_hstring(R_Tb), ALWAYS);
    end if;
  end process;


end TestBench;
