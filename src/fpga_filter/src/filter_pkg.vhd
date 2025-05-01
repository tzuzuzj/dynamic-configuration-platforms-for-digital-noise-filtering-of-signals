library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package filter_pkg is
	
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
			coefficients_addr : out std_logic_vector (3 downto 0);
			coefficients		: in std_logic_vector (63 downto 0);
			left_right			: in std_logic
		);
	end component;
	
end package;

