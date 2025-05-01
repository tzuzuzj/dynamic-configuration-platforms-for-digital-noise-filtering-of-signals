library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity filter_tb is
end entity;


architecture beh of filter_tb is

	constant CLK_PERIOD : time := 83 ns;
	signal clk          : std_logic;
	signal stop_clock   : boolean := false;
	signal res_n        : std_logic := '0';
	signal left_right : std_logic := '0';
	signal filter_in : signed (23 downto 0);
	signal finished_reading : std_logic;
	

	component filter is
		generic (
			constant order : integer := 1
		);
		port (
			clk 					: in std_logic;
			res_n 				: in std_logic;
			filter_in 			: in signed (23 downto 0);
			filter_out 			: out signed (23 downto 0);
			finished_reading 	: in std_logic;
			left_right			: in std_logic
		);
	end component;


begin

	-----------------------------------------------
	--   Instantiate your top level entity here  --
	-----------------------------------------------
	-- The testbench generates the above singals --
	-- use them as inputs to your system         --
	-----------------------------------------------

	filter_inst : filter
	port map(
			clk 					=> clk,
			res_n 				=> res_n,
			filter_in => filter_in,
			filter_out => open,
			finished_reading => finished_reading,
			left_right	=> left_right
	);


	stimulus : process
	begin
		res_n <= '0';
		
		
		wait for 40 ns;
		
		res_n <= '1';
		
		
		
		wait;
	end process;


	generate_clk : process
	begin
		while not stop_clock loop
			clk <= '0', '1' after CLK_PERIOD / 2;
			wait for CLK_PERIOD;
		end loop;
		wait;
	end process;

	generate_96kHz_clk : process
	begin
		while not stop_clock loop
			left_right <= '1';
			filter_in <= (5 => '1', 4 => '1', 1 => '1', others => '0');	
			finished_reading <= '1';
			wait for CLK_PERIOD * 31;
			finished_reading <= '0';
			wait for CLK_PERIOD * 31;
			left_right <= '0';
			filter_in <= (6 => '1', 5 => '1', 2 => '1', others => '0');
			finished_reading <= '1';
			wait for CLK_PERIOD * 31;
			finished_reading <= '0';
			wait for CLK_PERIOD * 31;
		end loop;
		wait;
	end process;

end architecture;




