library ieee;
use ieee.std_logic_1164.all;

entity audio_cntrl_tb is
end entity;


architecture beh of audio_cntrl_tb is

	constant CLK_PERIOD : time := 83 ns;
	signal clk          : std_logic;
	signal stop_clock   : boolean := false;
	signal res_n        : std_logic := '0';
	signal wm8731_adcdat : std_logic := '0';
	signal clk_50MHz : std_logic := '0';

component audio_cntrl is
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
		wm8731_adclrck : out std_logic
	);
end component;

begin

	-----------------------------------------------
	--   Instantiate your top level entity here  --
	-----------------------------------------------
	-- The testbench generates the above singals --
	-- use them as inputs to your system         --
	-----------------------------------------------

	audio_cntrl_inst : audio_cntrl
	port map(
		clk => clk,
		clk_50MHz => clk_50MHz,
		res_n => res_n,
		wm8731_adcdat => wm8731_adcdat
	);


	stimulus : process
	begin
		res_n <= '0';
		wait for 40 ns;
		res_n <= '1';

--		while not stop_clock loop
--			wm8731_adcdat <= '0';		-- LSB
--			wait for CLK_PERIOD;
--			wm8731_adcdat <= '1';
--			wait for CLK_PERIOD;
--			wm8731_adcdat <= '0';
--			wait for CLK_PERIOD;
--			wm8731_adcdat <= '0';
--			wait for CLK_PERIOD;
--			wm8731_adcdat <= '1';
--			wait for CLK_PERIOD;
--			wm8731_adcdat <= '1';
--			wait for CLK_PERIOD;
--			wm8731_adcdat <= '0';
--			wait for 18 * CLK_PERIOD;
--		end loop;

		wm8731_adcdat <= '1';
		
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

end architecture;




