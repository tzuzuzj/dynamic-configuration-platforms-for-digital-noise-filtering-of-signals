library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package mixer_pkg is

	type pwm_array_t is array (1 downto 0) of integer;
	
	component mixer IS
		generic (
			constant SYNTH_COUNT : integer := 2
		);
		port (
			clk : in std_logic;
			res_n : in std_logic;
			pwm_in : in pwm_array_t;
			pwm_out : out signed (15 downto 0)
		);
	end component;
	
	
	
	
end package;

