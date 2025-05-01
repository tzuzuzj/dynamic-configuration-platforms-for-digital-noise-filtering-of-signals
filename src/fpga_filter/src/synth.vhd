library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.audio_cntrl_pkg.all;
use work.i2c_master_pkg.all;


entity synth is
	port (
		clk : in std_logic;
		res_n : in std_logic;
		high_time : in std_logic_vector(7 downto 0);
		low_time : in std_logic_vector(7 downto 0);
		play : std_logic;
		pwm : out integer
	);
end entity;


architecture arch of synth is 

	signal pwm_cnt, pwm_cnt_nxt : integer := 0;
	type state_pwm_t is (HIGH_TIME, LOW_TIME, WAIT_TO_PLAY);
	signal state_pwm, state_pwm_nxt : state_pwm_t := HIGH_TIME;
	signal high_time_saved, low_time_saved, high_time_saved_nxt, low_time_saved_nxt : integer := 0;

	begin
	
		sync_state : process(clk, res_n)
		begin
			if not res_n then
				pwm_cnt <= 0;
				state_pwm <= WAIT_TO_PLAY;
				high_time_saved <= 0;
				low_time_saved <= 0;
				
			elsif rising_edge(clk) then
				pwm_cnt <= pwm_cnt_nxt;
				state_pwm <= state_pwm_nxt;
				low_time_saved <= low_time_saved_nxt;
				high_time_saved <= high_time_saved_nxt;
				
			end if;
		end process;
	

		create_pwm : process(all)
		begin
		
		state_pwm_nxt <= state_pwm;		
		low_time_saved_nxt <= low_time_saved;
		high_time_saved_nxt <= high_time_saved;
		
		case state_pwm is
	
			when WAIT_TO_PLAY =>
				pwm_cnt_nxt <= 0;
				pwm <= 0;
				if(cntrl.play = '1') then
					high_time_saved_nxt <= to_integer(unsigned(cntrl.high_time));
					low_time_saved_nxt <= to_integer(unsigned(cntrl.low_time));
					state_pwm_nxt <= HIGH_TIME;
				end if;
		
			when HIGH_TIME =>
				pwm_cnt_nxt <= pwm_cnt + 1;
				pwm <= 1;
				if(cntrl.play = '0') then
					pwm_cnt_nxt <= 0;
					state_pwm_nxt <= WAIT_TO_PLAY;
				elsif pwm_cnt = high_time_saved * 1500 then 
					pwm_cnt_nxt <= 0;
					state_pwm_nxt <= LOW_TIME;
				end if;
				
			when LOW_TIME =>
				pwm_cnt_nxt <= pwm_cnt + 1;
				pwm <= -1;
				if(cntrl.play = '0') then
					pwm_cnt_nxt <= 0;
					state_pwm_nxt <= WAIT_TO_PLAY;
				elsif pwm_cnt = low_time_saved  * 1500 then 
					pwm_cnt_nxt <= 0;
					state_pwm_nxt <= HIGH_TIME;
				end if;
				
		end case;
	end process;

	
end architecture;
