-- This file is used to manage the UART-communication buffer.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uart_buffer_pkg.all;


ENTITY uart_buffer_controller IS
	PORT
	(
		clk						: in std_logic := '1';
		res_n						: in std_logic;
		get_coefficients 		: inout std_logic := '0';
		coefficients 			: out std_logic_vector (63 downto 0);
		rx_busy 					: in std_logic := '0';
		calculation_finished : in std_logic := '0';
		coefficients_addr 	: in std_logic_vector (3 downto 0);
		recived_uart_data 	: in std_logic_vector (7 downto 0)
	);
END uart_buffer_controller;


ARCHITECTURE arc OF uart_buffer_controller IS

	signal uart_buffer_write_enable : std_logic := '0';
	signal uart_buffer_rdaddress, uart_buffer_rdaddress_nxt : std_logic_vector(3 downto 0);
	signal uart_buffer_wraddress, uart_buffer_wraddress_nxt : std_logic_vector(6 downto 0);
	signal transmittion_in_progress, transmittion_in_progress_nxt : std_logic := '0';

	type uart_write_state_t is (wait_for_input, rx_in_progress, rx_finished);
	signal uart_write_state, uart_write_state_nxt : uart_write_state_t := wait_for_input;


BEGIN

	uart_buffer_rdaddress <= coefficients_addr;

	-- instantiation of the UART-Buffer
	uart_buffer_inst : uart_buffer
		PORT MAP(
			clock		=> clk,
			data		=> recived_uart_data,
			enable	=> '1',
			rdaddress	=> uart_buffer_rdaddress,
			wraddress	=> uart_buffer_wraddress,
			wren		=> uart_buffer_write_enable,
			q			=> coefficients
		);


	sync : process (clk, res_n)
	begin
		if res_n = '0' then
			uart_write_state <= wait_for_input;
			uart_buffer_wraddress <= (others => '0');
			transmittion_in_progress <= '0';

		elsif rising_edge(clk) then
			uart_write_state <= uart_write_state_nxt;
			uart_buffer_wraddress <= uart_buffer_wraddress_nxt;
			transmittion_in_progress <= transmittion_in_progress_nxt;

		end if;
	end process;

	-- storing process
	write_to_uart_buffer : process(all)
	begin

		get_coefficients <= '0';
		uart_buffer_write_enable <= '0';
		uart_write_state_nxt <= uart_write_state;
		uart_buffer_wraddress_nxt <= uart_buffer_wraddress;
		transmittion_in_progress_nxt <= transmittion_in_progress;

		case uart_write_state is

			when wait_for_input => 										-- wait for transmission start
				if rx_busy = '1' then
					uart_write_state_nxt <= rx_in_progress;
				end if;

			when rx_in_progress =>										-- wait until transmission finished
				if rx_busy = '0' then
					uart_write_state_nxt <= rx_finished;
				end if;

			when rx_finished =>											-- write the received byte to the intended address.
				uart_buffer_write_enable <= '1';

				if unsigned(uart_buffer_wraddress) = to_unsigned(63, 6) then			-- if the last byte is written, reset the address.
					uart_buffer_wraddress_nxt <= (others => '0');
				else
					uart_buffer_wraddress_nxt <= std_logic_vector(unsigned(uart_buffer_wraddress) + to_unsigned(1, 6));
				end if;

				uart_write_state_nxt <= wait_for_input;

		end case;
	end process;

END arc;
