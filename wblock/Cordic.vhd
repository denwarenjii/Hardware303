-- 16-bit Q1.14 Cordic Calculator
--
--  This entity describes a 16 bit Cordic calculator (1 integer bit and 14
--  decimal bits.) This calculator implements cos, sin, cosh, sinh, division,
--  and multiplication fully parallely.

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
--    28 May 2025   Chris M.   Make concurrent and fixed bug prevent multiple
--                             instantiations of Cordic (CordSystem was 
--                             unknowingly a shared variable in the
--                             CordicConstants package.
--                             
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

  signal   CordSystem  : std_logic_vector(1 downto 0);

  -- The previous function 
  signal PrevFunc : std_logic_vector(4 downto 0);

  -- The latched inputs
  signal X_temp    : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal Y_temp    : std_logic_vector(INTERMEDIATE_WORD_SIZE - 1 downto 0);
  signal Func_temp : std_logic_vector(Func'range);

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

  -- Input busses for the 22-bit adders. Note that InputBus(k) is just 
  -- ResultBus(k-1). InputBus(0) depends on the function. Also note that all of
  -- the b inputs for the Z-adders are fixed.
  signal XInputBus : array_2d;
  signal YInputBus : array_2d;
  signal ZInputBUs : array_2d;

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

  ZConstantBusGen :
  for i in 0 to ITERATIONS - 1 generate
    with Func_temp select ZConstantBus(i) <=
      Z_CONSTANTS_CIRCULAR(i)   when F_COS_X    | F_SIN_X,
      Z_CONSTANTS_LINEAR(i)     when F_X_MULT_Y | F_Y_DIV_X,
      Z_CONSTANTS_HYPERBOLIC(i) when F_COSH_X   | F_SINH_X,
      (others => '0')           when others;
  end generate;

  -- Note that we always start off adding theta_0
  DBus_gen : 
  for i in 0 to (ITERATIONS - 1) generate
    DBus(i) <=
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

      -- YInput negative     XInput is negative -> do subtraction to add to Y         (1)
      -- YInput is negative, XInput is positive -> do addition to add to Y            (0)
      -- YInput is positive, XInput is negative -> do addition to subtract from Y     (0)
      -- YInput is positive, XInput is positive -> do subtraction to subtract from Y  (1)
      --
      -- Note that this just results in XORing DBus signal by the sign of XInput

      -- Add if in vectoring mode and Y is negative and X is positive.
      -- Subtract if in vectoring mode and Y is negative and X is negative. 
      ('0' xor GetMSB(XInputBus(i))) when ((Mode = VECTORING) and 
                                           (signed(YInputBus(i)) < signed(ZERO_22))) else

      -- Subtract if in vectoring mode and Y is positive and X is positive.
      -- Add if in vectoring mode and Y is positive and X is negative 
      ('1' xor GetMSB(XInputBus(i))) when ((Mode = VECTORING) and (YInputBus(i)(21) = '0')) else

      -- Add if in rotation mode and the input Z is negative
      '1' when ((Mode = ROTATION)  and (signed(ZInputBus(i)) < signed(ZERO_22))) else

      -- Subtract if in rotation mode and the input Z is positive
      '0' when ((Mode = ROTATION) and ZInputBus(0)(21) = '0') else

      -- Set to zero 
      '0';
  end generate;

  InputBus_gen :
  for i in 1 to (ITERATIONS - 1) generate
    XInputBus(i) <= XResultBus(i-1);
    YInputBus(i) <= YResultBus(i-1);
    ZInputBus(i) <= ZResultBus(i-1);
  end generate;

  CordicStage_gen : 
  for i in 0 to ITERATIONS - 1 generate
    CordicStage_i : entity CordicStage
      generic map (
        wordsize => INTERMEDIATE_WORD_SIZE
      )
      port map (
        XIn        => XInputBus(i),
        YIn        => YInputBus(i),
        ZIn        => ZInputBus(i),
        ZConstant  => ZConstantBus(i),
        CordSystem => CordSystem,
        d          => DBus(i),
        i          => i,
        XOut       => XResultBus(i),
        YOut       => YResultBus(i),
        ZOut       => ZResultBus(i)
      );
  end generate;

  with Func_temp select Mode <=
    ROTATION        when F_COS_X | F_SIN_X | F_X_MULT_Y | F_COSH_X | F_SINH_X,
    VECTORING       when F_Y_DIV_X,                                            
    '0'             when others;

  with Func_temp select CordSystem <=
    CIRCULAR        when   F_COS_X    | F_SIN_X,
    LINEAR          when   F_X_MULT_Y | F_Y_DIV_X,
    HYPERBOLIC      when   F_COSH_X   | F_SINH_X,
    (others => '0') when   others;

  with Func_temp select ResultComb <=
    -- Preserve the sign bit
    Q3_18_To_Q1_14(XResultBus(15)) when F_COS_X | F_COSH_X,
    Q3_18_To_Q1_14(YResultBus(15)) when F_SIN_X | F_X_MULT_Y | F_SINH_X,
    Q3_18_To_Q1_14(ZResultBus(15)) when F_Y_DIV_X,
    (others => '0')                when others;



  R <= ResultComb;

  -- Set the result on the falling edge
  -- process(clk)
  -- begin
  --   if (rising_edge(clk)) then
  --     SetLogEnable(CordicLogID, DEBUG, true);
  --     -- SetLogEnable(CordicLogID, DEBUG, false);
  --     R <= ResultComb;
  --   end if;
  -- end process;

  X_temp    <= X(X'left) & X(X'left) & X & "0000";
  Y_temp    <= Y(Y'left) & Y(Y'left) & Y & "0000";
  Func_temp <= Func;

  -- process(clk)
  -- begin
  --   if rising_edge(clk) then
  --     -- Latch the inputs
  --     X_temp    <= X(X'left) & X(X'left) & X & "0000";
  --     Y_temp    <= Y(Y'left) & Y(Y'left) & Y & "0000";
  --     Func_temp <= Func;
  --     end if;
  -- end process;

 StorePrevFunc : 
 process(clk)
  begin
    if rising_edge(clk) then
      PrevFunc <= Func_temp;
    end if;
  end process;

  -- Log on the rising edge.
  process(clk)
  begin
    if rising_edge(clk) then

      Log(CordicLogID, YELLOW & "Rising Edge" & ANSI_RESET, DEBUG);
      Log(CordicLogID, "Setting PrevFunc", DEBUG);
      Log(CordicLogID, "Func: "    & to_string(Func), DEBUG);
      Log (CordicLogID, "X: "      & to_string(Q1_14ToReal(X)), DEBUG);
      Log (CordicLogID, "Y: "      & to_string(Q1_14ToReal(Y)), DEBUG);
      Log (CordicLogID, "X_temp: " & to_string(Q3_18ToReal(X_temp)), DEBUG);
      Log (CordicLogID, "Y_temp: " & to_string(Q3_18ToReal(Y_temp)), DEBUG);

      if (Func /= "UUUUU") then
        Log(CordicLogID, to_string(LF), DEBUG);
        Log(CordicLogID, RepeatChar('-', 120), DEBUG);
        PrintFunc(X, Y, Func);

        if (Mode /= 'U') then
          Log(CordicLogID, "Mode: "       & MODE_STRINGS(to_integer(Mode)), DEBUG);
          Log(CordicLogID, "CordSystem: " & CORD_STRINGS(to_integer(unsigned(CordSystem))), DEBUG);
        end if;

      Log(CordicLogID, 
          HT & HT & HT & "X_A" & 
          HT & HT & HT & "X_B" &
          HT & HT & HT & "Y_A" & 
          HT & HT & HT & "Y_B" &
          HT & HT & HT & "Z_A" &
          HT & HT & HT & "Z_B" &
          HT & HT & "d_i" & HT 
          , DEBUG);

        for i in 0 to ITERATIONS - 1 loop
          Log(CordicLogID, 
            "i=" & to_string(i) &
            HT & HT & to_string(Q3_18ToReal(XInputBus(i)), "%.8f") &                                  -- X_A
            HT & HT & to_string(Q3_18ToReal(std_logic_vector(signed(YInputBus(i)) sra i)), "%.8f") &  -- X_B
            HT & HT & to_string(Q3_18ToReal(YInputBus(i)), "%.8f") &                                  -- Y_A
            HT & HT & to_string(Q3_18ToReal(std_logic_vector(signed(XInputBus(i)) sra i)), "%.8f") &  -- Y_B
            HT & HT & to_string(Q3_18ToReal(ZInputBus(i)), "%.8f") &                                  -- Z_A
            HT & HT & to_string(Q3_18ToReal(ZConstantBus(i)), "%.8f") &                               -- Z_B
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
      Log (CordicLogID, "X_temp: " & to_string(Q3_18ToReal(X_temp)), DEBUG);
      Log (CordicLogID, "Y_temp: " & to_string(Q3_18ToReal(Y_temp)), DEBUG);

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


      -- Log (CordicLogID, "Mode: " & to_string(Mode), DEBUG);

      for i in 0 to ITERATIONS - 1 loop
        Log (
          CordicLogID,
          LF & " DBus(" & to_string(i) & "): " & to_string(DBus(i)) & LF &
          LF & " CordSystem: " & to_string(CordSystem) & LF &
          LF & " FuncTemp: " & to_string(Func_temp) & LF &
          HT & " XResultBus: " & to_string(XResultBus(i)) & LF &
          HT & " XInputBus: " & to_string(XInputBus(i)) & " XInputBus(" & to_string(i) & ") MSB: " & to_string(GetMSB(XInputBus(i))) & LF &
          HT & " YInputBus: " & to_string(YInputBus(i)) & LF &
          HT & " YInputBus(" & to_string(i) & ") < 0: " & to_string(signed(YInputBus(i)) < signed(ZERO_22)) & LF &
          HT & " YInputBus(" & to_string(i) & ")(21) = 0: " & to_string(YInputBus(i)(21) = '0') & LF &
          HT & " (Mode = VECTORING) and (signed(YInputBus(i)) < signed(ZERO_22)):  " & 
          to_string(((Mode = VECTORING) and (signed(YInputBus(i)) < signed(ZERO_22)))) & LF &
          HT & " ((Mode = VECTORING) and (YInputBus(0)(21) = '0')):  " & 
          to_string(((Mode = VECTORING) and (YInputBus(0)(21) = '0'))),
          DEBUG
        );
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

