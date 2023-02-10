library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
library work;
library std;
   use std.textio.all;
   
entity testbench_top is
end entity testbench_top;

architecture bhv of testbench_top is

   -- Clock and reset generation
   signal clock_50         : std_logic := '0';
   signal reset_n          : std_logic := '0';  -- Active low reset
   signal reset            : std_logic := '1';  -- Active high reset
   signal kill_clock       : std_logic := '0';
   
     -- Output signals to / from DUT
   signal bcd_input_vector          : std_logic_vector(7 downto 0);
   signal bcd_valid_in              : std_logic;
   signal bcd_ready                 : std_logic;
   signal bcd_0                     : std_logic_vector(3 downto 0);
   signal bcd_1                     : std_logic_vector(3 downto 0);
   signal bcd_2                     : std_logic_vector(3 downto 0);
   signal bcd_valid_out             : std_logic;
  
   procedure pr_write(v_input_str : in string) is
      variable v_line : line;
   begin
      write(v_line,v_input_str);
      writeline(OUTPUT, v_line);
   end procedure pr_write;

   -- An array of bcd values to be used to check outputs
   type t_bcd_array is array(0 to 10) of std_logic_vector(3 downto 0);
   constant c_bcd_array   : t_bcd_array := (
      "0000",
      "0001",
      "0010",
      "0011",
      "0100",
      "0101",
      "0110",
      "0111",
      "1000",
      "1001",
      "1010"
   );

begin

   --=============================================================
   -- p_generate_clock
   -- Process that generates 50 MHz clock signal.
   -- stops clock when the kill_clock signal is set high.
   --=============================================================
   p_generate_clock : process
   begin
      clock_50 <= '0';
      wait for 10 ns;
      while ( kill_clock = '0' ) loop
         clock_50 <= not clock_50;
         wait for 10 ns;
      end loop;
      -- wait forever;
      wait;
   end process p_generate_clock;

   --=============================================================
   -- p_generate_reset
   -- Process that holds active low reset signal active
   -- for some time in the beginning of simulation.
   --=============================================================
   p_generate_reset : process
   begin
      -- Set reset active
      reset_n     <= '0';
      reset       <= '1';  -- Active high reset
      wait for 123 ns;
      -- Set reset inactive
      reset_n     <= '1';
      reset       <= '0';  -- Active low reset
      -- Wait forever
      wait;
   end process p_generate_reset;
   
   --=============================================================
   -- p_main_test_process
   -- Process that controls and runs all tests that shall be done.
   --=============================================================
   p_main_test_process : process
   begin
      -- Startup values
      kill_clock           <= '0';
      bcd_input_vector     <= (others => '0');
      bcd_valid_in         <= '0';
      pr_write("Simulation starts.");
     
      -- wait until reset is released
      wait until reset_n = '1';
      -- Wait another 100 ns
      wait for 100 ns;
      -- wait for clock signal to go high
      wait until clock_50 = '1';
      -- set value 123 to bcd input vector
      bcd_input_vector     <= std_logic_vector(to_unsigned(123,bcd_input_vector'length));
      -- set valid in high
      bcd_valid_in         <= '1';
      
      -- wait for clock signal to go high again
      wait until clock_50 = '1';
      -- set valid in low
      bcd_valid_in         <= '0';

      wait until bcd_valid_out = '1';  -- wait until valid out signal is set high

      -- Check bcd values
      if bcd_0 = "0011" and   -- 3
         bcd_1 = "0010" and   -- 2
         bcd_2 = "0001" then  -- 1
            pr_write("123 decoded OK");
      else
         pr_write("ERROR : 123 decode NOK");
      end if;

      --variable v_test_input   : integer range 0 to 127 := 0;

      for i in 0 to 127 loop -- Generate a new number to be tested.

         --pr_Write("Number to be tested is: ");
         --report integer'image(i); -- Print out the current iteration of the loop as a string.

      -- wait for clock signal to go high
         wait until clock_50 = '1';
         bcd_input_vector     <= std_logic_vector(to_unsigned(i,bcd_input_vector'length));

      -- set valid in high
         bcd_valid_in         <= '1';
      -- wait for clock signal to go high again
         wait until clock_50 = '1';
      -- set valid in low
         bcd_valid_in         <= '0';

         wait until bcd_valid_out = '1';
         
      -- Check the bcd outputs
         if i >= 100 then
            if bcd_2 /= c_bcd_array(1) then
               pr_write("BCD_2 Not 1!"); -- BCD_2 was not 1 when it should have been.
               report integer'image(i);
            end if;
         elsif i >= 10 then
            if bcd_1 /= c_bcd_array(integer((i mod 100) / 10)) then
               pr_write("BCD_1 Not equal to i!"); --
               report integer'image(i);
            end if;
         elsif i < 10 then
            if bcd_1 /= c_bcd_array(0) then
               pr_write("BCD_1 Not 0!"); -- Number is less than 10, BCD_1 should be 0.
               report integer'image(i);

            end if;
            if bcd_0 /= c_bcd_array(i mod 10) then
               pr_write("BCD_0 Not equal to i!"); -- Wrong "ones".
               report integer'image(i);

            end if;
         end if;
         --pr_write("All values between 0 - 127 seem to be correct.");
      end loop;
      

      pr_write("Testbench ends...");
      wait for 100 ns;
      -- Kill clock and wait forever. Enables "run -all" command in modelsim
      kill_clock           <= '1';
      wait;
   end process p_main_test_process;

   i_dut_bcd_decode : entity work.bcd_decode
   port map(
      clk                     => clock_50,
      reset                   => reset,   -- active high reset
      
      -- input data interface
      input_vector            => bcd_input_vector, -- in  std_logic_vector(7 downto 0)
      valid_in                => bcd_valid_in,     -- in  std_logic
      ready                   => bcd_ready,        -- out std_logic

      -- output result
      bcd_0                   => bcd_0,            -- out std_logic_vector(3 downto 0) ones
      bcd_1                   => bcd_1,            -- out std_logic_vector(3 downto 0) tens
      bcd_2                   => bcd_2,            -- out std_logic_vector(3 downto 0) hundreds
      valid_out               => bcd_valid_out);   -- out std_logic, Set high one clock cycle when bcd* is valid



end architecture bhv;