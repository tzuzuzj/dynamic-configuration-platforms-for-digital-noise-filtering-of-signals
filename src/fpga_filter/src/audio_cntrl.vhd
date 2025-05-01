-- This file instantiates the filter module and handels the communication with the WM8731 Audio-chip.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.audio_cntrl_pkg.all;
use work.i2c_master_pkg.all;
use work.filter_pkg.all;

entity audio_cntrl is
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
end entity;

architecture arch of audio_cntrl is

	signal i2c_ena : STD_LOGIC := '0';
	signal i2c_addr : STD_LOGIC_VECTOR(6 DOWNTO 0);
	signal i2c_rw : STD_LOGIC;
	signal i2c_data_wr : STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal i2c_busy : STD_LOGIC;
	signal sda :  STD_LOGIC;                     	--serial data output of i2c bus
	signal scl :  STD_LOGIC;       	            	--serial clock output of i2c bus

	constant clk_96k_period : integer := 125;		-- 96 kHz
	signal clk_96kHz: std_logic;

	signal clk_96k_cnt, clk_96k_cnt_nxt : integer := 0;
	type state_clk_96k_t is (INIT, LOW_VALUE, HIGH_VALUE);
	signal state_clk_96k, state_clk_96k_nxt : state_clk_96k_t := INIT;
	signal clk_96k_en : STD_LOGIC := '0';

	signal busy_prev : STD_LOGIC := '0';
	signal busy_cnt, busy_cnt_nxt : integer := 0;

	signal pwm_index, pwm_index_nxt : integer := 23;

	signal throughput : std_logic;

	signal filter_in, filter_out, filter_in_nxt : signed (23 downto 0) := (others => '0');

	signal finished_reading : std_logic := '0';

	constant filter_in_test : signed (23 downto 0) := (5 => '1', 4 => '1', 1 => '1', others => '0');



begin
	wm8731_xck <= clk;
	wm8731_bclk <= clk;
	i2c_rw <= '0';
	i2c_addr <= "0011010";

	wm8731_dacdat <= throughput;
	wm8731_daclrck <= clk_96kHz;
	wm8731_adclrck <= clk_96kHz;


	sync_state : process(clk, res_n)
	begin
		if not res_n then
			busy_cnt <= 0;
			pwm_index <= 23;
			filter_in <= (others => '0');

		elsif rising_edge(clk) then
			busy_cnt <= busy_cnt_nxt;

		elsif falling_edge(clk) then
			clk_96k_cnt <= clk_96k_cnt_nxt;
			state_clk_96k <= state_clk_96k_nxt;
			pwm_index <= pwm_index_nxt;
			filter_in <= filter_in_nxt;

		end if;
	end process;


	/* configuration of the WM8731 audio chip...
	register values at WM8731 manual page 50 */
	init_FSM : process(all)
	begin

		busy_cnt_nxt <= busy_cnt;
		clk_96k_en <= '0';

		case busy_cnt is


		-- deaktivating the audio chip

			when 0 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');								-- data
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 1 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00010010";										-- reg addr
					busy_cnt_nxt <= busy_cnt + 1;

			when 2 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010010";										-- reg addr
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 3 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000000";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 4 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000000";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 5 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;



			-- analog path control:
				-- disable ADC Mute
				-- select Line Input as input
				-- don't bypass (bypass: take the line input directly to the output)
				-- don't enable side tone (side tone: takes the mic input directly to the output)

			when 6 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00001000";
					busy_cnt_nxt <= busy_cnt + 1;

			when 7 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00001000";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 8 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010001";					-- 00011000 to enable bypass
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 9 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010001";					-- 00011000 to enable bypass
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 10 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;



			-- digital audio path control
				-- don't enable digital high pass filter
				-- because otherway it leads to distortion
				-- of the audio-signal

			when 11 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00001010";
					busy_cnt_nxt <= busy_cnt + 1;

			when 12 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00001010";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 13 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000001";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 14 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000001";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 15 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;





			when 16 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00001100";
					busy_cnt_nxt <= busy_cnt + 1;

			when 17 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00001100";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 18 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000010";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 19 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000010";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 20 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;



			-- MSB right justified mode
			-- 24 bit input

			when 21 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00001110";
					busy_cnt_nxt <= busy_cnt + 1;

			when 22 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00001110";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 23 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00001001";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 24 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00001001";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 25 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;



			-- sampling control
				-- 96kHz sampling rate (in-, and output)

			when 26 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00010000";
					busy_cnt_nxt <= busy_cnt + 1;

			when 27 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010000";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 28 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00011101";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 29 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00001101";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 30 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;



			-- Left Line In
				-- disable mute

			when 31 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00000000";
					busy_cnt_nxt <= busy_cnt + 1;

			when 32 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000000";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 33 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010111";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 34 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010111";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 35 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;




			-- Right Line In
				-- disable mute

			when 36 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00000010";
					busy_cnt_nxt <= busy_cnt + 1;

			when 37 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000010";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 38 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010111";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 39 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010111";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 40 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;




			-- activade audio device

			when 41 =>
					i2c_ena <= '0';
					i2c_data_wr <= "00010010";
					busy_cnt_nxt <= busy_cnt + 1;

			when 42 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00010010";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 43 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000001";
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 44 =>
					i2c_ena <= '1';
					i2c_data_wr <= "00000001";
					IF(i2c_busy = '1') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;

			when 45 =>
					i2c_ena <= '0';
					i2c_data_wr <= (others => '0');
					IF(i2c_busy = '0') THEN
						busy_cnt_nxt <= busy_cnt + 1;
					END IF;


			when others =>
				i2c_ena <= '0';
				i2c_data_wr <= (others => '0');
				clk_96k_en <= '1';

		end case;
	end process;



	/* Reads serially the samples from the WM8731 and passes them to the filter module.
	Takes also the output from the filter module and sends it serially to the WM8731.
	And It generates the 96 kHz audio sampling clock.*/
	clk_96k : process(all)
	begin

		clk_96k_cnt_nxt <= clk_96k_cnt;
		state_clk_96k_nxt <= state_clk_96k;
		pwm_index_nxt <= pwm_index;
		filter_in_nxt <= filter_in;

		case state_clk_96k is

			-- wait in this state until the initialization of the WM8731 has finished.
			when INIT =>
				if(clk_96k_en = '1') then
					state_clk_96k_nxt <= HIGH_VALUE;
				end if;
				clk_96kHz <= '0';
				throughput <= '0';
				finished_reading <= '0';


			-- high part of the 96 kHz clock (left side of the stereo audio signal)
			when HIGH_VALUE =>
				clk_96k_cnt_nxt <= clk_96k_cnt + 1;
				clk_96kHz <= '1';

				-- read the sequentially passed data recived from the wm8731 and buffer it.
				-- also take the filter output and send it sequentially to the wm8731.
				if(pwm_index >= 0) then
					filter_in_nxt(pwm_index) <= wm8731_adcdat;
					throughput <= filter_out(pwm_index);

					pwm_index_nxt <= pwm_index - 1;
					finished_reading <= '0';

				else
					throughput <= '0';
					finished_reading <= '1';

				end if;

				if clk_96k_cnt = clk_96k_period / 2 - 1 then
					clk_96k_cnt_nxt <= 0;
					state_clk_96k_nxt <= LOW_VALUE;
					pwm_index_nxt <= 23;
				end if;


			-- low part of the 96 kHz clock (right side of the stereo audio signal)
			when LOW_VALUE =>
				clk_96k_cnt_nxt <= clk_96k_cnt + 1;
				clk_96kHz <= '0';

				-- read the sequentially passed data recived from the wm8731 and buffer it.
				-- also take the filter output and send it sequentially to the wm8731.
				if(pwm_index >= 0) then
					filter_in_nxt(pwm_index) <= wm8731_adcdat;
					throughput <= filter_out(pwm_index);

					pwm_index_nxt <= pwm_index - 1;
					finished_reading <= '0';

				else
					throughput <= '0';
					finished_reading <= '1';

				end if;

				if clk_96k_cnt = clk_96k_period / 2 - 1 then
					clk_96k_cnt_nxt <= 0;
					state_clk_96k_nxt <= HIGH_VALUE;
					pwm_index_nxt <= 23;

				end if;

		end case;
	end process;


	-- filter module... used for the filter calculation.
	filter_inst : filter
	generic map (
		 order => 1 	--Order of the TP and HP filters -> Order of the Band pass filter = order * 2
	)
	port map (
		clk => clk,
		res_n => res_n,
		filter_in => filter_in_nxt,
		filter_out => filter_out,
		finished_reading => finished_reading,
		coefficients_addr => coefficients_addr,
		coefficients		=> coefficients,
		left_right => clk_96kHz
	);

	-- i2c master... used for the initialization of the wm8731
	i2c_inst : i2c_master
	generic map (
		 input_clk => 12_000_000, 	--input clock speed from user logic in Hz
		 bus_clk => 400_000   		--speed the i2c bus (scl) will run at in Hz
	)
	port map (
		clk => clk,
		reset_n => res_n,
		ena => i2c_ena,
		addr => i2c_addr,
		rw => i2c_rw,
		data_wr => i2c_data_wr,

		busy => i2c_busy,
		data_rd => open,
		ack_error => open,
		sda => wm8731_sdat,
		scl => wm8731_sclk
	);


end architecture;
