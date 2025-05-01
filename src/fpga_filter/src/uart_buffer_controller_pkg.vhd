library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package uart_buffer_controller_pkg is
	
	Component uart_buffer_controller IS
		PORT
		(
			clk					: in std_logic := '1';
			res_n					: in std_logic;
			get_coefficients 	: inout std_logic := '0';
			coefficients 		: out std_logic_vector (63 downto 0);
			rx_busy 				: in std_logic := '0';
			calculation_finished : in std_logic := '0';
			coefficients_addr 	: in std_logic_vector (3 downto 0);
			recived_uart_data : in std_logic_vector (7 downto 0)
		);
	END Component;
	
end package;

