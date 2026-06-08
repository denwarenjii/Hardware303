-- 16-bit Q1.14 Cordic Calculator;
--
--  This entity describes a 16 bit Cordic calculator (1 integer bit and 14
--  decimal bits.) This calculator implements cos, sin, cosh, sinh, division,
--  and multiplication fully parallely. This implementation has three pipeline
--  stages, such that each 4 cordic stages are operating on a different function
--  at a given clock cycle.
--
--  Revision History:
--    Date:         Author:    Description:
--    07 Jan 2024   Chris M.   Initial revision; described entity and processes.
--    24 Jan 2025   Chris M.   Used 22-bit adder subtracters instead of 
--                             directly insantiating them to remove nested 
--                             generate loops.
--    25 Jan 2025   Chris M.   Added mode signal.
--    26 Jan 2025   Chris M.   Added comments.
--    27 Jan 2025   Chris M.   Fixed bug where the initial value of the Y 
--                             adders was being set incorrectly (inital values
--                             go to the A input and not the B input)
--    27 Jan 2025   Chris M.   Changed lookup table to be generated locally.
--    31 Jan 2025   Chris M.   Moved fixed point operation functions to 
--                             seperate file for reuse in test bench.
--    31 Jan 2025   Chris M.   Removed reset signal.
--    18 Feb 2025   Chris M.   Formatted. Add [TODO].
--    18 Feb 2025   Chris M.   Converted to use CordicStage
--    21 Feb 2025   Chris M.   Fixed bugs in linear and hyperbolic functions.
--    21 Feb 2025   Chris M.   Corrected timing.
--    25 Feb 2025   Chris M.   Added 1 pipeline stage.
--    25 Feb 2025   Chris M.   Modified for 3 pipeline stages.
--    25 Feb 2025   Chris M.   Added documentation.
--
-- TODO:
--    - Remove magic numbers from for generate loops.
--    - See if Xilinix supports if/generate
-------------------------------------------------------------------------------

-- libraries
library  ieee;
library osvvm;

use  std.textio.all;
use  ieee.std_logic_1164.all;
use  ieee.numeric_std.all;
use  ieee.math_real.all;
use  work.FixedLib.all;
use  work.CordicConstants.all;
use  work.all;
use  ANSIEscape.all;

use osvvm.RandomPkg.all;          
use osvvm.CoveragePkg.all;
context osvvm.OsvvmContext;

entity Cordic is
  port(
    CLK   : in  std_logic;
    X     : in  std_logic_vector(15 downto 0);
    Y     : in  std_logic_vector(15 downto 0);
    Func  : in  std_logic_vector( 4 downto 0);
    R     : out std_logic_vector(15 downto 0)
  );
end Cordic;

architecture sim of Cordic is

  -- Constants and Types --------------------------------------------------------------------------


  -- Signals and Constants ------------------------------------------------------------------------

  -- The latched inputs
  signal X_temp    : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal Y_temp    : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal Func_temp : std_logic_vector(Func'range);


  -- Pipelined outputs/inputs. Note that these go between the 7th (8th if counting from 1) cordic
  -- stage.

  -- First stage.
  signal XPipeline1 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal YPipeline1 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal ZPipeline1 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);

  signal FuncPipeline1       : std_logic_vector(Func'range);
  signal CordSystemPipeline1 : std_logic_vector(1 downto 0);
  signal ModePipeline1       : std_logic;

  -- Second stage.
  signal XPipeline2 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal YPipeline2 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal ZPipeline2 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);

  signal FuncPipeline2       : std_logic_vector(Func'range);
  signal CordSystemPipeline2 : std_logic_vector(1 downto 0);
  signal ModePipeline2       : std_logic;
  
  -- Third stage.
  signal XPipeline3 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal YPipeline3 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal ZPipeline3 : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);

  signal FuncPipeline3       : std_logic_vector(Func'range);
  signal CordSystemPipeline3 : std_logic_vector(1 downto 0);
  signal ModePipeline3       : std_logic;


  -- Start and end indices for cordic sections. The cordic is divided into 4 sections:
  --    0 - 3, 4 - 7, 8 - 11, and 12 - 15
  -- There is a DFF between each section as well as the first and last section
  -- for I/O.

  constant FIRST_QUARTER_START  : natural := 0;
  constant FIRST_QUARTER_END    : natural := 3;
  constant SECOND_QUARTER_START : natural := 4;
  constant SECOND_QUARTER_END   : natural := 7;
  constant THIRD_QUARTER_START  : natural := 8;
  constant THIRD_QUARTER_END    : natural := 11;
  constant FOURTH_QUARTER_START : natural := 12;
  constant FOURTH_QUARTER_END   : natural := 15;


  -- Cordic modes. Used to change the function of the cordic. In circular
  -- coordinates, rotation mode is used for trig functions and vectoring mode
  -- is used for inverse trig functions. In linear mode, rotation mode is used
  -- to get x*z and vectoring mode is used to get y/x. In hyperbolic mode,
  -- rotation mode is used to find hyperbolic trig functions and vectoring mode
  -- is used to find their inverses.
  signal   Mode      : std_logic;
  constant ROTATION  : std_logic := '0';
  constant VECTORING : std_logic := '1';

  -- Result busses for the 22-bit adders
  signal XResultBus : array_2d;
  signal YResultBus : array_2d;
  signal ZResultBus : array_2d;

  signal ResultComb : std_logic_vector(WORD_SIZE - 1 downto 0);

  -- Wtf ???? This wasn't declared before but it still worked ????
  signal CordSystem : std_logic_vector(1 downto 0);

  -- Input busses for the 22-bit adders. Note that InputBus(k) is just 
  -- ResultBus(k-1). InputBus(0) depends on the function. Also note that all of
  -- the b inputs for the Z-adders are fixed.
  signal XInputBus : array_2d;
  signal YInputBus : array_2d;
  signal ZInputBus : array_2d;

  signal CordicLogID       : AlertLogIDType := GetAlertLogID("Cordic");

  -- The decision variables. If in rotation mode, it implies adding when the 
  -- current angle is less than the target or subtraction when the current 
  -- angle is more than the target. If in vectoring mode, d implies addition
  -- if the sign of y is positive and subtraction if the sign of y is negative.
  signal DBus : std_logic_vector(WORD_SIZE - 1 downto 0);

  signal ZConstantBus : array_2d;

  -- Functions and Procedures ---------------------------------------------------------------------

  -- Repeat a character n times and return a string.
  function RepeatChar(c : character; n : positive) return string is 
    variable Result : string(1 to n) := (others => ' ');
  begin
    for i in 1 to n loop
      Result(i) := c; 
    end loop;
    return Result;
  end function;

  -- Get the MSB of a std_logic_vector.
  function GetMSB(slv : std_logic_vector) return std_logic is
  begin
    return slv(slv'high);
  end function;

  -- Convert a Q3.18 fixed point to a Q1.14 fixed point.
  function Q3_18_To_Q1_14(slv : std_logic_vector(21 downto 0)) return std_logic_vector is
  begin
    return slv(21) & slv(18) & slv(17 downto 4);
  end function;

  -- Print the current function to the debug stream
  procedure PrintFunc(Xin : std_logic_vector(WORD_SIZE - 1 downto 0); 
                      Yin : std_logic_vector(WORD_SIZE - 1 downto 0); 
                      FuncIn : std_logic_vector(Func'range)) is
  begin
    case FuncIn is
      when F_COS_X =>
        Log(CordicLogID, "cos(" & to_string(Q1_14ToReal(XIn)) & ")", DEBUG);
      when F_SIN_X =>
        Log(CordicLogID, "sin(" & to_string(Q1_14ToReal(XIn)) & ")", DEBUG);
      when F_COSH_X =>
        Log(CordicLogID, "cosh(" & to_string(Q1_14ToReal(XIn)) & ")", DEBUG);
      when F_SINH_X =>
        Log(CordicLogID, "sinh(" & to_string(Q1_14ToReal(XIn)) & ")", DEBUG);
      when F_X_MULT_Y =>
        LOG(CordicLogID, to_string(Q1_14ToReal(XIn)) & " * " & to_string(Q1_14ToReal(YIn)), DEBUG);
      when F_Y_DIV_X =>
        Log(CordicLogID, to_string(Q1_14ToReal(YIn)) & " / " & to_string(Q1_14ToReal(XIn)), DEBUG);
      when others =>
        Log(CordicLogID, "Unknown function: " & to_string(FuncIn), DEBUG);
    end case;
  end procedure;

  procedure PrintFuncTemp(FuncIn : std_logic_vector(Func'range)) is
  begin
    case FuncIn is
      when F_COS_X =>
        Log(CordicLogID, "Func_temp: cos", DEBUG);
      when F_SIN_X =>
        Log(CordicLogID, "Func_temp: sin", DEBUG);
      when F_COSH_X =>
        Log(CordicLogID, "Func_temp: cosh", DEBUG);
      when F_SINH_X =>
        Log(CordicLogID, "Func_temp: sinh", DEBUG);
      when F_X_MULT_Y =>
        LOG(CordicLogID,  "Func_temp: x * y", DEBUG);
      when F_Y_DIV_X =>
        Log(CordicLogID,  "Func_temp x / y", DEBUG);
      when others =>
        Log(CordicLogID, "Func_temp: Unknown function: " & to_string(FuncIn), DEBUG);
    end case;
  end procedure;

begin

  SetLogEnable(CordicLogID, DEBUG, true);
  
  -- Load the input and output values based on the operation. The starting
  -- and final X Y Z vectors are based on the following table:
  -- +==================+======================+==============================+
  -- | Coordinate System| Rotation Mode        | Vectoring Mode               |
  -- +==================+======================+==============================+
  -- | Circular         | ╭     ╮    ╭     ╮   | ╭     ╮    ╭      ________ ╮ |
  -- | m = 1            | │ K ⁻¹│    │cos θ│   | │  x  │    │ K⁻¹ √ x² + y² │ |                    
  -- |                  | │ 0   │ => │sin θ│   | │  y  │ => │       0       │ |                        
  -- |                  | │theta│    │  0  │   | │theta│    │ tan⁻¹(y/x)    │ |                    
  -- |                  | ╰     ╯    ╰     ╯   | ╰     ╯    ╰               ╯ |                     
  -- +------------------+----------------------+------------------------------+
  -- | linear           | ╭   ╮    ╭     ╮     | ╭   ╮    ╭     ╮             |
  -- | m = 0            | │ x │    │  x  │     | │ x │    │  x  │             |
  -- |                  | │ 0 │ => │ x*z │     | │ y │ => │  0  │             |                     
  -- |                  | │ z │    │  0  │     | │ 0 │    │ y/x │             |                     
  -- |                  | ╰   ╯    ╰     ╯     | ╰   ╯    ╰     ╯             |                     
  -- +------------------+----------------------+------------------------------|
  -- | Hyperbolic       | ╭     ╮    ╭      ╮  | ╭     ╮    ╭      ________ ╮ |
  -- | m = -1           | │ K⁻¹ │    │cosh θ│  | │  x  │    │ K⁻¹ √ x² + y² │ |                    
  -- |                  | │ 0   │ => │sinh θ│  | │  y  │ => │       0       │ |                        
  -- |                  | │theta│    │  0   │  | │theta│    │ tanh⁻¹(y/x)   │ |                    
  -- |                  | ╰     ╯    ╰      ╯  | ╰     ╯    ╰               ╯ |                     
  -- +------------------+----------------------+------------------------------+
  --
  -- Note that theta is the 'x' input, since we have x and y inputs (these are
  -- not the same as the components of the (x y z) vector).

  -- X adder inputs
  with Func_temp select XInputBus(0) <=
    (K_inv_circular)    when F_COS_X    | F_SIN_X,
    (K_inv_hyperbolic)  when F_COSH_X   | F_SINH_X, 
    (X_temp)            when F_X_MULT_Y | F_Y_DIV_X,
    (XInputBus(0))      when others;

  -- Y adder inputs
  with Func_temp select YInputBus(0) <=
    (others => '0')   when F_COS_X  | F_SIN_X | F_X_MULT_Y | F_COSH_X | F_SINH_X,
    (Y_temp)          when F_Y_DIV_X,
    (others => '0')   when others;

  -- Z adder inputs
  with Func_temp select ZInputBus(0) <=
    (X_temp)          when F_COS_X | F_SIN_X | F_COSH_X | F_SINH_X, 
    (Y_temp)          when F_X_MULT_Y,
    (others => '0')   when F_Y_DIV_X,
    (others => '0')   when others;


  -------------------------------------------------------------------------------------------------
  -- ZConstantBus generation ----------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------
    
  -- Generate the ZConstants for the first quarter of the Cordic. They depend on
  -- Func_temp.
  ZConstantBusGen_FirstQuarter:
  --       0 to 3
  for i in FIRST_QUARTER_START to FIRST_QUARTER_END generate
    with Func_temp select ZConstantBus(i) <=
      Z_CONSTANTS_CIRCULAR(i)   when F_COS_X    | F_SIN_X,
      Z_CONSTANTS_LINEAR(i)     when F_X_MULT_Y | F_Y_DIV_X,
      Z_CONSTANTS_HYPERBOLIC(i) when F_COSH_X   | F_SINH_X,
      (others => '0')           when others;
  end generate;

  -- Generate the ZConstants for the second quarter of the Cordic. They depend on
  -- FuncPipeline1.
  ZConstantBusGen_SecondQuarter:
  --       4 to 7 
  for i in SECOND_QUARTER_START to SECOND_QUARTER_END generate
    with FuncPipeline1 select ZConstantBus(i) <=
      Z_CONSTANTS_CIRCULAR(i)   when F_COS_X    | F_SIN_X,
      Z_CONSTANTS_LINEAR(i)     when F_X_MULT_Y | F_Y_DIV_X,
      Z_CONSTANTS_HYPERBOLIC(i) when F_COSH_X   | F_SINH_X,
      (others => '0')           when others;
  end generate;

  -- Generate the ZConstants for the third quarter of the Cordic. They depend on
  -- FuncPipeline2.
  ZConstantBusGen_ThirdQuarter:
  --       8 to 11
  for i in THIRD_QUARTER_START to THIRD_QUARTER_END generate
    with FuncPipeline2 select ZConstantBus(i) <=
      Z_CONSTANTS_CIRCULAR(i)   when F_COS_X    | F_SIN_X,
      Z_CONSTANTS_LINEAR(i)     when F_X_MULT_Y | F_Y_DIV_X,
      Z_CONSTANTS_HYPERBOLIC(i) when F_COSH_X   | F_SINH_X,
      (others => '0')           when others;
  end generate;

  -- Generate the ZConstants for the fourth quarter of the Cordic. They depend on
  -- FuncPipeline3.
  ZConstantBusGen_FourthQuarter:
  --       12 to 15
  for i in FOURTH_QUARTER_START to FOURTH_QUARTER_END generate
    with FuncPipeline3 select ZConstantBus(i) <=
      Z_CONSTANTS_CIRCULAR(i)   when F_COS_X    | F_SIN_X,
      Z_CONSTANTS_LINEAR(i)     when F_X_MULT_Y | F_Y_DIV_X,
      Z_CONSTANTS_HYPERBOLIC(i) when F_COSH_X   | F_SINH_X,
      (others => '0')           when others;
  end generate;


  -------------------------------------------------------------------------------------------------
  -- DBus Generation ------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------

  -- When we are in vectoring mode, we want to drive y towards zero. Note that the
  -- YAddBarSub signal is just d_i, so we want to pick d_i such that the operation
  -- goes towards zero:
  --
  -- If the YInput is negative, then pick the operation such that the result will
  -- become more positive. The B input for the Y adder is just the XInput 
  -- divided by 2, so the sign must be the same.
  --
  -- +===+===+====+
  -- | Y | X | Op |
  -- +===+===+====+
  -- | - | - |  - |
  -- | - | + |  + |
  -- | + | - |  + |
  -- | + | + |  - |
  -- +------------+
  -- Note that this just results in XORing DBus signal by the sign of XInput

  -- Generate the DBus signals for the first quarter of the Cordic. They depend on
  -- Mode.
  DBusGen_FirstQuarter : 
  --       0 to 3
  for i in FIRST_QUARTER_START to FIRST_QUARTER_END generate
    DBus(i) <=
      -- Add if in vectoring mode and Y is negative and X is positive.
      -- Subtract if in vectoring mode and Y is negative and X is negative. 
      '0' xor GetMSB(XInputBus(i)) when ((Mode = VECTORING) and 
                                         (signed(YInputBus(i)) < signed(ZERO_22))) else

      -- Subtract if in vectoring mode and Y is positive and X is positive.
      -- Add if in vectoring mode and Y is negative and X is positive 
      '1' xor GetMSB(XInputBus(i)) when ((Mode = VECTORING) and (YInputBus(0)(21) = '0')) else

      -- Add if in rotation mode and the input Z is negative
      '1' when ((Mode = ROTATION)  and (signed(ZInputBus(i)) < signed(ZERO_22))) else

      -- Subtract if in rotation mode and the input Z is positive
      '0' when ((Mode = ROTATION) and ZInputBus(0)(21) = '0') else

      -- Set to zero 
      '0';
  end generate;

  -- Generate the DBus signals for the second quarter of the Cordic. They depend on ModePipeline1.
  DBusGen_SecondQuarter : 
  --       4 to 7 
  for i in SECOND_QUARTER_START to SECOND_QUARTER_END generate
    DBus(i) <=
      '0' xor GetMSB(XInputBus(i)) when ((ModePipeline1 = VECTORING) and 
                                         (signed(YInputBus(i)) < signed(ZERO_22))) else

      '1' xor GetMSB(XInputBus(i)) when ((ModePipeline1 = VECTORING) and (YInputBus(0)(21) = '0')) else

      '1' when ((ModePipeline1 = ROTATION)  and (signed(ZInputBus(i)) < signed(ZERO_22))) else

      '0' when ((ModePipeline1 = ROTATION) and ZInputBus(0)(21) = '0') else

      '0';
   end generate;

  -- Generate the DBus signals for the third quarter of the Cordic. They depend on ModePipeline2.
  DBusGen_ThirdQuarter : 
  --       8 to 11
  for i in THIRD_QUARTER_START to THIRD_QUARTER_END generate
    DBus(i) <=
      '0' xor GetMSB(XInputBus(i)) when ((ModePipeline2 = VECTORING) and 
                                         (signed(YInputBus(i)) < signed(ZERO_22))) else

      '1' xor GetMSB(XInputBus(i)) when ((ModePipeline2 = VECTORING) and (YInputBus(0)(21) = '0')) else

      '1' when ((ModePipeline2 = ROTATION)  and (signed(ZInputBus(i)) < signed(ZERO_22))) else

      '0' when ((ModePipeline2 = ROTATION) and ZInputBus(0)(21) = '0') else

      '0';
   end generate;

  -- Generate the DBus signals for the fourth quarter of the Cordic. They depend on ModePipeline3.
  DBusGen_FourthQuarter : 
  --       12 to 15
  for i in FOURTH_QUARTER_START to FOURTH_QUARTER_END generate
    DBus(i) <=
      '0' xor GetMSB(XInputBus(i)) when ((ModePipeline3 = VECTORING) and 
                                         (signed(YInputBus(i)) < signed(ZERO_22))) else

      '1' xor GetMSB(XInputBus(i)) when ((ModePipeline3 = VECTORING) and (YInputBus(0)(21) = '0')) else

      '1' when ((ModePipeline3 = ROTATION)  and (signed(ZInputBus(i)) < signed(ZERO_22))) else

      '0' when ((ModePipeline3 = ROTATION) and ZInputBus(0)(21) = '0') else

      '0';
   end generate;

  -------------------------------------------------------------------------------------------------
  -- Input Bus Generation -------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------

  -- Generate the input bus for the first quarter of the Cordic (0 - 3). Note that
  -- InputBus(0) is set by the function.
  InputBusGen_FirstQuarter :
  --       1 to 3
  for i in FIRST_QUARTER_START + 1 to FIRST_QUARTER_END generate
    XInputBus(i) <= XResultBus(i-1);
    YInputBus(i) <= YResultBus(i-1);
    ZInputBus(i) <= ZResultBus(i-1);
  end generate;


  -- Generate the input bus for the second quarter of the Cordic (4 to 7).
  -- The input to stage 4 for is XPipeline1.
  --        4
  XInputBus(SECOND_QUARTER_START) <= XPipeline1;
  YInputBus(SECOND_QUARTER_START) <= YPipeline1;
  ZInputBus(SECOND_QUARTER_START) <= ZPipeline1;

  InputBusGen_SecondQuarter :
  --       5 to 7
  for i in SECOND_QUARTER_START + 1 to SECOND_QUARTER_END generate 
    XInputBus(i) <= XResultBus(i-1);
    YInputBus(i) <= YResultBus(i-1);
    ZInputBus(i) <= ZResultBus(i-1);
  end generate;


  -- Generate the input bus for the third quarter of the Cordic (8 to 11).
  -- The input to stage 8 for is XPipeline2.
  --        8
  XInputBus(THIRD_QUARTER_START) <= XPipeline2;
  YInputBus(THIRD_QUARTER_START) <= YPipeline2;
  ZInputBus(THIRD_QUARTER_START) <= ZPipeline2;

  InputBusGen_ThirdQuarter :
  --       9 to 11
  for i in THIRD_QUARTER_START + 1 to THIRD_QUARTER_END generate 
    XInputBus(i) <= XResultBus(i-1);
    YInputBus(i) <= YResultBus(i-1);
    ZInputBus(i) <= ZResultBus(i-1);
  end generate;


  -- Generate the input bus for the third quarter of the Cordic (12 to 15).
  -- The input to stage 12 for is XPipeline3.
  --        12
  XInputBus(FOURTH_QUARTER_START) <= XPipeline3;
  YInputBus(FOURTH_QUARTER_START) <= YPipeline3;
  ZInputBus(FOURTH_QUARTER_START) <= ZPipeline3;

  InputBusGen_FourthQuarter :
  --       13 to 15
  for i in FOURTH_QUARTER_START + 1 to FOURTH_QUARTER_END generate 
    XInputBus(i) <= XResultBus(i-1);
    YInputBus(i) <= YResultBus(i-1);
    ZInputBus(i) <= ZResultBus(i-1);
  end generate;


  -------------------------------------------------------------------------------------------------
  -- Cordic Stages Generation ---------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------

  -- Generate the CordicStage instances for the first quarter. 

  -- Note that stage 3 outputs to ResultBus(3), and the pipeline DFFs are set to ResultBus(3) on 
  -- the rising edge of the clock. These CordicStages depend on CordSystem.
  CordicStageGen_FirstQuarter : 
  --       0 to  3.
  for i in FIRST_QUARTER_START to FIRST_QUARTER_END generate
    CordicStage_i : entity CordicStage
      generic map (
        wordsize => INTERMEDIATE_WORD_SIZE,
        i        => i
      )
      port map (
        XIn        => XInputBus(i),
        YIn        => YInputBus(i),
        ZIn        => ZInputBus(i),
        ZConstant  => ZConstantBus(i),
        CordSystem => CordSystem,
        d          => DBus(i),
        XOut       => XResultBus(i),
        YOut       => YResultBus(i),
        ZOut       => ZResultBus(i)
      );
  end generate;



  -- Generate the CordicStage instances for the second quarter.
  -- Note that InputBus(4) is set to the pipeline1 signals on the rising edge of the clock, and
  -- CordicStage7 outputs to pipeline2 signals. These cordic stages depend on CordSystemPipeline1.
  CordicStageGen_SecondQuarter : 
  --       4 to 7.
  for i in SECOND_QUARTER_START to SECOND_QUARTER_END generate
    CordicStage_i : entity CordicStage
      generic map (
        wordsize => INTERMEDIATE_WORD_SIZE,
        i        => i
      )
      port map (
        XIn        => XInputBus(i),
        YIn        => YInputBus(i),
        ZIn        => ZInputBus(i),
        ZConstant  => ZConstantBus(i),
        CordSystem => CordSystemPipeline1,
        d          => DBus(i),
        XOut       => XResultBus(i),
        YOut       => YResultBus(i),
        ZOut       => ZResultBus(i)
      );
  end generate;



  -- Generate the CordicStage instances for the third quarter.
  -- Note that InputBus(8) is set to the pipeline2 signals on the rising edge of the clock, and
  -- CordicStage11 outputs to pipeline3 signals. These cordic stages depend on CordSystemPipeline2.
  CordicStageGen_ThirdQuarter : 
  --       8 to 11.
  for i in THIRD_QUARTER_START to THIRD_QUARTER_END generate
    CordicStage_i : entity CordicStage
      generic map (
        wordsize => INTERMEDIATE_WORD_SIZE,
        i        => i
      )
      port map (
        XIn        => XInputBus(i),
        YIn        => YInputBus(i),
        ZIn        => ZInputBus(i),
        ZConstant  => ZConstantBus(i),
        CordSystem => CordSystemPipeline2,
        d          => DBus(i),
        XOut       => XResultBus(i),
        YOut       => YResultBus(i),
        ZOut       => ZResultBus(i)
      );
  end generate;



  -- Generate the CordicStage instances for the fourth quarter.
  -- Note that InputBus(12) is set to the pipeline3 signals on the rising edge of the clock, and
  -- CordicStage15 outputs to the actual outputs.
  CordicStageGen_FourthQuarter : 
  --       12 to 15.
  for i in FOURTH_QUARTER_START to FOURTH_QUARTER_END generate
    CordicStage_i : entity CordicStage
      generic map (
        wordsize => INTERMEDIATE_WORD_SIZE,
        i        => i
      )
      port map (
        XIn        => XInputBus(i),
        YIn        => YInputBus(i),
        ZIn        => ZInputBus(i),
        ZConstant  => ZConstantBus(i),
        CordSystem => CordSystemPipeline3,
        d          => DBus(i),
        XOut       => XResultBus(i),
        YOut       => YResultBus(i),
        ZOut       => ZResultBus(i)
      );
  end generate;


  -- Note that these internal signals are set in the first half of the cordic and stored for the 
  -- second half of the calculation.
  with Func_temp select Mode <=
    ROTATION        when F_COS_X | F_SIN_X | F_X_MULT_Y | F_COSH_X | F_SINH_X,
    VECTORING       when F_Y_DIV_X,                                            
    '0'             when others;

  with Func_temp select CordSystem <=
    CIRCULAR        when   F_COS_X    | F_SIN_X,
    LINEAR          when   F_X_MULT_Y | F_Y_DIV_X,
    HYPERBOLIC      when   F_COSH_X   | F_SINH_X,
    (others => '0') when   others;

  -- The result is determined by the last quarter of the cordic (FuncPipeline3)
  with FuncPipeline3 select ResultComb <=
    -- Preserve the sign bit
    Q3_18_To_Q1_14(XResultBus(15)) when F_COS_X | F_COSH_X,
    Q3_18_To_Q1_14(YResultBus(15)) when F_SIN_X | F_X_MULT_Y | F_SINH_X,
    Q3_18_To_Q1_14(ZResultBus(15)) when F_Y_DIV_X,
    (others => '0')                when others;


  -- Set the result on the rising edge.
  process(clk)
  begin
    if (rising_edge(clk)) then
      -- SetLogEnable(CordicLogID, DEBUG, true);
      -- SetLogEnable(CordicLogID, DEBUG, false);
      R <= ResultComb;
    end if;
  end process;

  -- Latch the inputs and set the pipelined values.
  process(clk)
  begin
    if rising_edge(clk) then
      -- Latch the inputs
      X_temp    <= X(X'left) & X(X'left) & X & "0000";
      Y_temp    <= Y(Y'left) & Y(Y'left) & Y & "0000";
      Func_temp <= Func;

      -- Set the pipelined values to the previous values.

      -- First quarter
      FuncPipeline1       <= Func_temp;
      CordSystemPipeline1 <= CordSystem;
      ModePipeline1       <= Mode;

      XPipeline1 <= XResultBus(3);
      YPipeline1 <= YResultBus(3);
      ZPipeline1 <= ZResultBus(3);


      -- Second quarter
      FuncPipeline2       <= FuncPipeline1;
      CordSystemPipeline2 <= CordSystemPipeline1;
      ModePipeline2       <= ModePipeline1;

      XPipeline2 <= XResultBus(7);
      YPipeline2 <= YResultBus(7);
      ZPipeline2 <= ZResultBus(7);

      -- Third quarter
      FuncPipeline3       <= FuncPipeline2;
      CordSystemPipeline3 <= CordSystemPipeline2;
      ModePipeline3       <= ModePipeline2;

      XPipeline3 <= XResultBus(11);
      YPipeline3 <= YResultBus(11);
      ZPipeline3 <= ZResultBus(11);

      end if;
  end process;

  -- Log on the rising edge.
  process(clk)
  begin
    if rising_edge(clk) then

      Log (CordicLogID, YELLOW & "Rising Edge" & ANSI_RESET, DEBUG);
      Log (CordicLogID, "Func: "    & to_string(Func), DEBUG);
      Log (CordicLogID, "X: "      & to_string(Q1_14ToReal(X)), DEBUG);
      Log (CordicLogID, "Y: "      & to_string(Q1_14ToReal(Y)), DEBUG);
      Log (CordicLogID, "X_temp: " & to_string(Q1_14ToReal(X_temp)), DEBUG);
      Log (CordicLogID, "Y_temp: " & to_string(Q1_14ToReal(Y_temp)), DEBUG);

      if (Func /= "UUUUU") then
        Log (CordicLogID, to_string(LF), DEBUG);
        Log (CordicLogID, RepeatChar('-', 120), DEBUG);
        PrintFunc(X, Y, Func);

        if (Mode /= 'U') then
          Log (CordicLogID, "Mode: "       & MODE_STRINGS(to_integer(Mode)), DEBUG);
          Log (CordicLogID, "CordSystem: " & CORD_STRINGS(to_integer(unsigned(CordSystem))), DEBUG);
        end if;

      Log(CordicLogID, 
          HT & HT & HT & "X_A" & HT & HT & HT &  "X_B" & HT & HT & HT & "Y_A" & 
          HT & HT & HT & "Y_B" & HT & HT & HT & "Z_A"  & HT & HT & HT & "Z_B" &
          HT & HT & "d_i" & HT 
          , DEBUG);

        for i in 0 to ITERATIONS - 1 loop
          Log(CordicLogID, 
            "i=" & to_string(i) &
            HT & HT & to_string(Q3_18ToReal(XInputBus(i)), 9) & 
            HT & HT & to_string(Q3_18ToReal(std_logic_vector(signed(YInputBus(i)) sra i)), 9) &
            HT & HT & to_string(Q3_18ToReal(YInputBus(i)), 9) & 
            HT & HT & to_string(Q3_18ToReal(std_logic_vector(signed(XInputBus(i)) sra i)), 9) &
            HT & HT & to_string(Q3_18ToReal(ZInputBus(i)), 3) & 
            HT & HT & to_string(Q3_18ToReal(ZConstantBus(i)), 3) &
            HT & HT & to_string(DBus(i)) & HT & HT ,
            DEBUG);
        end loop;

        Log(CordicLogID, "XResultBus(15): " & to_string(Q3_18ToReal(XResultBus(15))), DEBUG);
        Log(CordicLogID, "YResultBus(15): " & to_string(Q3_18ToReal(YResultBus(15))), DEBUG);
        Log(CordicLogID, "ZResultBus(15): " & to_string(Q3_18ToReal(ZResultBus(15))), DEBUG);
        Log(CordicLogID, "Returning: " & to_string(Q1_14ToReal(ResultComb)), DEBUG);
        Log(CordicLogID, "Returning: " & to_string((ResultComb)), DEBUG);
        Log(CordicLogID, RepeatChar('-', 120), DEBUG);
        Log(CordicLogID, to_string(LF), DEBUG);

      end if;
    end if;
  end process;

  -- Log on the falling_edge.
  process(clk)
  begin

    if falling_edge(clk) then
      Log(CordicLogID, YELLOW & "Falling Edge" & ANSI_RESET, DEBUG);
      PrintFunc(X, Y, Func);
      Log (CordicLogID, "X: "      & to_string(Q1_14ToReal(X)), DEBUG);
      Log (CordicLogID, "Y: "      & to_string(Q1_14ToReal(Y)), DEBUG);
      Log (CordicLogID, "X_temp: " & to_string(Q1_14ToReal(X_temp)), DEBUG);
      Log (CordicLogID, "Y_temp: " & to_string(Q1_14ToReal(Y_temp)), DEBUG);

      if (Mode /= 'U') then
        Log(CordicLogID, "Mode: "       & MODE_STRINGS(to_integer(Mode)), DEBUG);
        Log(CordicLogID, "CordSystem: " & CORD_STRINGS(to_integer(unsigned(CordSystem))), DEBUG);
      end if;

      Log(CordicLogID, 
          HT & HT & HT & "X_A" & HT & HT & HT &  "X_B" & HT & HT & HT & "Y_A" & 
          HT & HT & HT & "Y_B" & HT & HT & HT & "Z_A"  & HT & HT & HT & "Z_B" &
          HT & HT & "d_i" & HT , DEBUG);

      for i in 0 to ITERATIONS - 1 loop
        Log(CordicLogID, 
          "i=" & to_string(i) &
          HT & HT &  to_string(Q3_18ToReal(XInputBus(i)), 9) & 
          HT & HT & to_string(Q3_18ToReal(std_logic_vector(signed(YInputBus(i)) sra i)), 9) &
          HT & HT & to_string(Q3_18ToReal(YInputBus(i)), 9) & 
          HT & HT & to_string(Q3_18ToReal(std_logic_vector(signed(XInputBus(i)) sra i)), 9) &
          HT & HT & to_string(Q3_18ToReal(ZInputBus(i)), 9) & 
          HT & HT & to_string(Q3_18ToReal(ZConstantBus(i)), 9) &
          HT & HT & to_string(DBus(i)) & HT & HT ,
          DEBUG);
      end loop;

      Log(CordicLogID, "XResultBus(15): " & to_string(Q3_18ToReal(XResultBus(15))), DEBUG);
      Log(CordicLogID, "YResultBus(15): " & to_string(Q3_18ToReal(YResultBus(15))), DEBUG);
      Log(CordicLogID, "ZResultBus(15): " & to_string(Q3_18ToReal(ZResultBus(15))), DEBUG);
      Log(CordicLogID, RepeatChar('-', 120), DEBUG);
      Log(CordicLogID, to_string(LF), DEBUG);
      Log(CordicLogID, "ZResultBus(15): " & to_string(ZResultBus(15)), DEBUG);
      Log(CordicLogID, "ZResultBus(15) in Q1_14 format: " & to_string(Q3_18_To_Q1_14(ZResultBus(15))), DEBUG);
      Log(CordicLogID, "ZResultBus(15) converted: " & 
        to_string(Q1_14ToReal(Q3_18_To_Q1_14(ZResultBus(15)))), DEBUG);
      Log(CordicLogID, "Returning: " & to_string(Q1_14ToReal(ResultComb)), DEBUG);
      Log(CordicLogID, "Returning: " & to_string((ResultComb)), DEBUG);
      PrintFuncTemp(Func_temp);

    end if;
  end process;

end sim;

