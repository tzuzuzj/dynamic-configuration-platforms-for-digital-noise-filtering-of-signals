library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package uart_buffer_pkg is
	
	Component uart_buffer IS
		PORT
		(
			clock		: IN STD_LOGIC  := '1';
			data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			enable		: IN STD_LOGIC  := '1';
			rdaddress		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			wraddress		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
			wren		: IN STD_LOGIC  := '0';
			q		: OUT STD_LOGIC_VECTOR (63 DOWNTO 0)
		);
	END Component;
	
end package;

