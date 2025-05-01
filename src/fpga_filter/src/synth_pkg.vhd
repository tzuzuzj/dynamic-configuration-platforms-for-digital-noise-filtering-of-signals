library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.audio_cntrl_pkg.all;


package synth_pkg is
	
	component synth IS
		port (
			clk : in std_logic;
			res_n : in std_logic;
			high_time : in std_logic_vector(7 downto 0);
			low_time : in std_logic_vector(7 downto 0);
			play : std_logic;
			pwm : out integer
		);
	end component;
	
end package;

