library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity uart_tb is
end entity;


architecture beh of uart_tb is

	constant CLK_PERIOD : time := 83 ns;
	signal clk          : std_logic;
	signal stop_clock   : boolean := false;
	signal res_n        : std_logic := '0';
	signal calculation_finished : std_logic := '1';
	signal recived_uart_data : std_logic_vector (7 downto 0);
	signal rx_busy : std_logic := '0';
	signal calc_state : integer := 0;
	signal coefficients_addr : std_logic_vector (3 downto 0) := (others => '0');


	Component uart_buffer_controller IS
		PORT
		(
		clk			: in std_logic := '1';
		res_n			: in std_logic;
		get_coefficients 	: inout std_logic := '0';
		coefficients 		: out std_logic_vector (63 downto 0);
		rx_busy 		: in std_logic := '0';
		calculation_finished 	: in std_logic := '0';
		coefficients_addr 	: in std_logic_vector (3 downto 0);
		recived_uart_data 	: in std_logic_vector (7 downto 0)
		);
	END Component;


begin

	uart: uart_buffer_controller
	port map(
			clk 	=> clk,
			res_n 	=> res_n,
			rx_busy => rx_busy,
			calculation_finished => calculation_finished,
			coefficients_addr => coefficients_addr,
			recived_uart_data => recived_uart_data
	);


	stimulus : process
	begin
		res_n <= '0';
		wait for 40 ns;
		res_n <= '1';

		-- fill the buffer
		for I in 0 to 63 loop
			rx_busy <= '1';
			recived_uart_data <= std_logic_vector(to_unsigned(I, 8));
			wait for 2 * CLK_PERIOD;
			rx_busy <= '0';
			wait for 2 * CLK_PERIOD;
		end loop;

		wait for 20 ns;

		-- read from buffer
		for I in 0 to 7 loop
			calc_state <= calc_state + 1;
			coefficients_addr <= std_logic_vector(unsigned(coefficients_addr) + to_unsigned(1, 4));
			wait for 1 * CLK_PERIOD;
		end loop;

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
