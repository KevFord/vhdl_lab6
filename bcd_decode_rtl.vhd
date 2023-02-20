library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

--=================================================================
--
-- BCD Decode
--
-- Transforms a 7 bit input vector to 3 BCD values.
-- Valid in shall be set high when input_vector is valid.
-- Valid_out shall be set high when transformed data is ready on
-- the bcd_* outputs
--
--=================================================================
entity bcd_decode is
   port(
      clk                     : in  std_logic;
      reset                   : in  std_logic;   -- active high reset
      
      -- input data interface
      input_vector            : in  std_logic_vector(7 downto 0); -- Was defined as 8 bits but lab assignment says 7?
      valid_in                : in  std_logic;
      ready                   : out std_logic;  -- ready for data when high

      -- output result
      bcd_0                   : out std_logic_vector(3 downto 0); -- ones
      bcd_1                   : out std_logic_vector(3 downto 0); -- tens
      bcd_2                   : out std_logic_vector(3 downto 0); -- hundreds
      valid_out               : out std_logic); -- Set high one clock cycle when bcd* is valid
end entity bcd_decode;

architecture rtl of bcd_decode is

   -- Types and constants
   type t_bcd_transfor_step is (
      bcd_ready,
      bcd_busy,
      bcd_valid_out,
      bcd_reset
   );

   type t_subtraction_step is (
      sub_idle,
      sub_hundred,
      sub_tens,
      sub_ones, 
      sub_done
   );

   -- Signals
   signal s_bcd_transform     : t_bcd_transfor_step := bcd_ready;

   signal s_subtraction_step  : t_subtraction_step := sub_hundred;

   signal s_reset_1r          : std_logic;
   signal s_reset_2r          : std_logic;

   signal s_valid_in_1r       : std_logic;
   signal s_valid_in_2r       : std_logic;

   signal s_input_vector_int  : integer range 0 to 127;

   signal s_tens              : integer range 0 to 9;
   signal s_ones              : integer range 0 to 9;

   signal s_tens_done_flag    : std_logic := '0';
   signal s_ones_done_flag    : std_logic := '0';

   signal s_valid_out_cnt     : integer range 0 to 1 := 0;

begin

   -- Prevent meta values
   p_debounce_inputs          : process(clk) is
   begin
      if rising_edge(clk) then
         s_reset_1r  <= reset;
         s_reset_2r  <= s_reset_1r;

         s_valid_in_1r  <= valid_in;
         s_valid_in_2r  <= s_valid_in_1r;
      end if;
   end process p_debounce_inputs;

-- ///////////////////////////////////////////////
-- Splits the "input_vector" into three separate values, one value for either the hundreds, tens and ones.
--
-- This is done by first converting the "input_vector" into an integer, then compares the integer to 100, 10 and 0
-- and subtracts the corresponding value in a loop-like operation.
-- 
-- Uses two state machines, one to keep track of in and out from the component and one that handles the maths.
-- 
-- Completes a full transform of the 0 - 127 value in 9 clock cycles.
-- 
-- Uses 109 logical elements and 40 registers.
-- ///////////////////////////////////////////////
   p_bcd_decode               : process(clk) is
   begin
      if rising_edge(clk) then
         case s_bcd_transform is
            
            when bcd_ready =>
               ready <= '1'; -- Keep ready high when NOT transforming.
               valid_out <= '0';
               if s_valid_in_2r = '1' then
                  s_input_vector_int <= to_integer(unsigned(input_vector)); -- Convert input into intger.
                  s_bcd_transform <= bcd_busy; -- Go to next state.
               end if;
            
            when bcd_busy => -- Do calculations
               ready <= '0'; -- Keep ready low while busy.
               case s_subtraction_step is -- Compare and subtract 100, 10 and 0.
                  when sub_idle =>
                     s_subtraction_step <= sub_hundred;
                  
                  when sub_hundred =>
                     if s_input_vector_int > 99 then -- Compare
                        s_input_vector_int <= s_input_vector_int - 100; -- Subtract 100
                        bcd_2 <= x"1"; -- As per the specification the maximum input will be 127. This means the first BCD number...
                        else bcd_2 <= x"0"; -- ... will be either a one or a zero, therefor we can hardcode outputs.
                     end if;
                     s_subtraction_step <= sub_tens; -- Go to next step.
                  
                  when sub_tens =>
                     if s_tens_done_flag /= '1' then -- This flag represents if the calculation is done or not.
                        if s_input_vector_int > 9 then -- Compare
                           s_input_vector_int <= s_input_vector_int - 10; -- Subtract 10, this may be repeated multiple times.
                           -- /////// ERROR INTRODUCED TO TEST TESTBENCH ERROR HANDLING////////
                           s_tens <= s_tens + 1; -- Add one for each iteration of the "loop".
                           -- /////// ERROR INTRODUCED TO TEST TESTBENCH ERROR HANDLING////////
                           else -- No longer greater than 10.
                           bcd_1 <= std_logic_vector(to_unsigned(s_tens, 4)); -- Convert the integer value into std_logic_vector form.
                           s_tens_done_flag <= '1'; -- Signal the transformation is done, no more looping.
                           s_subtraction_step <= sub_ones;
                        end if;
                     end if;
                  
                  when sub_ones => -- Largely the same as above state, but subtracts and compares the "ones" place.
                     if s_ones_done_flag /= '1' then
                        if s_input_vector_int > 0 then
                           s_input_vector_int <= s_input_vector_int - 1;
                           s_ones <= s_ones + 1; -- ERROR Overflows to 10 in TB Simulation...
                        else 
                           bcd_0 <= std_logic_vector(to_unsigned(s_ones, 4));
                           s_ones_done_flag <= '1';
                           s_subtraction_step <= sub_done;
                        end if;
                     end if;

                  when sub_done => -- Reset the loop condition flags and variables for tens and ones.
                     s_tens_done_flag <= '0';
                     s_ones_done_flag <= '0';
                     s_tens <= 0;
                     s_ones <= 0;
                     s_subtraction_step <= sub_idle;
                     s_bcd_transform <= bcd_valid_out;
               end case;
            
            when bcd_valid_out => -- Toggle valid out signal high for once clock cycle then go to next step.
               if s_valid_out_cnt = 1 then
                  valid_out <= '1';
                  s_bcd_transform <= bcd_ready;
               else
                  s_valid_out_cnt <= s_valid_out_cnt + 1;
                  valid_out <= '0';
               end if;

            when bcd_reset =>
               -- Reset valid out signal since we cannot be certain the transformation was completed or not
               valid_out <= '0';
               -- Reset outputs. If no reset signal is given the outputs will remain at the value from the last "valid_out" signal.
               bcd_0 <= "0000";
               bcd_1 <= "0000";
               bcd_2 <= "0000";
               -- Reset flags
               s_tens_done_flag <= '0';
               s_ones_done_flag <= '0';
               -- Reset counters
               s_tens <= 0;
               s_ones <= 0;
               -- Reset integer version of input
               s_input_vector_int <= 0;
               -- Reset states
               s_subtraction_step <= sub_idle;
               s_bcd_transform <= bcd_ready;
         end case;
      end if;

      -- Reset
      if s_reset_2r = '1' then
         s_bcd_transform <= bcd_reset;
      end if;
   end process p_bcd_decode;


end architecture rtl;


