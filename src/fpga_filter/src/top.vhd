--   Author:		   (c) Stefan Dangl (dangl.stefan@gmx.at)
--   ProjectName:      Dynamic configuration Platforms for digital noise filtering of signals
--   Dependencies:     all files in the "Dynamic configuration Platforms for digital noise filtering of signals" repository
--   Design Software:  Quartus II 64-bit Version 13.1
--
--   This vhdl files are used to configure the FPGA filter instrument.
--
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--                                LIBRARIES                                   --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.audio_cntrl_pkg.all;
use work.uart_pkg.all;
use work.uart_buffer_controller_pkg.all;

--------------------------------------------------------------------------------
--                                 ENTITY                                     --
--------------------------------------------------------------------------------

entity top is
	port (
		-- 50 MHz clock input
		clk      : in  std_logic;
		res_n		: in std_logic;
		uart_button : in std_logic;

		-- audio_cntrl_outputs
		wm8731_xck : out std_logic;
		wm8731_sdat : inout std_logic;
		wm8731_sclk : inout std_logic;
		wm8731_dacdat : out std_logic;
		wm8731_daclrck : out std_logic;
		wm8731_bclk : out std_logic;
		wm8731_adcdat : in std_logic;
		wm8731_adclrck : out std_logic;

		-- uart signals
		uart_rxd	: in std_logic;		-- UART Receiver
		uard_txd	: out std_logic;		-- UART Transmitter
		uart_cts	: in std_logic := '0';		-- UART Clear to Send
		uart_rts	: out std_logic := '0'		-- UART Request to Send
	);
end entity;


--------------------------------------------------------------------------------
--                             ARCHITECTURE                                   --
--------------------------------------------------------------------------------


architecture top_arc of top is

	signal audio_clk, system_clk : std_logic;
	signal audio_res_n : std_logic;
	signal recived_uart_data : std_logic_vector(7 downto 0) := (others => '0');
	signal rx_busy : std_logic;

	signal coefficients : std_logic_vector (63 downto 0);
	signal get_coefficients : std_logic := '0';
	signal calculation_finished : std_logic := '0';
	signal coefficients_addr 	:  std_logic_vector (3 downto 0);



component pll
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0				: OUT STD_LOGIC ;
		c1				: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC
	);
end component;

begin

	calculation_finished <= '0';
	uart_rts <= '0';

	pll_inst : pll
	port map(
		inclk0 => clk,
		c0 => system_clk,			-- 50 MHz clock
		c1 => audio_clk,			-- 12 MHz clock
   	areset => open,
		locked => open
	);


-- AUDIO - CONTROLLING --
	audio_cntrl_inst : audio_cntrl
	port map(
		clk => audio_clk,							-- 12MHz
		clk_50MHz => system_clk,
		res_n => res_n,
		wm8731_xck => wm8731_xck,
		wm8731_sdat => wm8731_sdat,
		wm8731_sclk => wm8731_sclk,
		wm8731_dacdat => wm8731_dacdat,
		wm8731_daclrck => wm8731_daclrck,
		wm8731_bclk => wm8731_bclk,
		wm8731_adcdat => wm8731_adcdat,
		wm8731_adclrck => wm8731_adclrck,
		coefficients_addr => coefficients_addr,
		coefficients => coefficients
	);


-- UART COMMUNICATION --
	uart_inst : uart
	generic map(
		clk_freq		=> 12_000_000,		-- frequency of system clock in Hz
		baud_rate	=> 9_600,			-- data link baud rate in bits/second
		os_rate		=> 16,				-- oversampling rate to find center of receive bits (in samples per baud period)
		d_width		=> 8, 				-- data bus width
		parity		=> 1,					-- 0 for no parity, 1 for parity
		parity_eo	=> '0'				--'0' for even, '1' for odd parity
	)
	port map(
		clk		=> audio_clk,														--system clock
		reset_n	=> res_n,				 											--ascynchronous reset
		tx_ena	=> not uart_button,												--initiate transmission
		tx_data	=> (6 => '1', 0 => '1', others => '0'),  					--data to transmit
		rx			=> uart_rxd,														--receive pin
		rx_busy	=> rx_busy,																--data reception in progress
		rx_error	=> open,																--start, parity, or stop bit error detected
		rx_data	=> recived_uart_data,											--data received, later the coefficients
		tx_busy	=> open,  															--transmission in progress
		tx			=> uard_txd															--transmit pin
	);

	uart_buffer_controller_inst : uart_buffer_controller
	port map(
			clk					=> audio_clk,
			res_n					=> res_n,
			get_coefficients 	=> get_coefficients,
			coefficients 		=> coefficients,
			rx_busy				=> rx_busy,
			calculation_finished => calculation_finished,
			coefficients_addr => coefficients_addr,
			recived_uart_data => recived_uart_data
	);

end architecture;
