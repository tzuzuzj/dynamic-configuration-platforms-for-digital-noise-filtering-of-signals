library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package audio_cntrl_pkg is

	component audio_cntrl IS
		port (
			clk : in std_logic;
			clk_50MHz : in std_logic;
			res_n : in std_logic;
			wm8731_xck : out std_logic;
			wm8731_sdat : inout std_logic;
			wm8731_sclk : inout std_logic;
			wm8731_dacdat : out std_logic;
			wm8731_daclrck : out std_logic;
			wm8731_bclk : out std_logic;
			wm8731_adcdat : in std_logic;
			wm8731_adclrck : out std_logic;
			coefficients_addr : out std_logic_vector (3 downto 0);
			coefficients : in std_logic_vector (63 downto 0)
		);
	end component;

end package;

