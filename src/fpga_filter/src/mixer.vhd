library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.audio_cntrl_pkg.all;
use work.i2c_master_pkg.all;
use work.mixer_pkg.all;



entity mixer is
	generic (
		constant SYNTH_COUNT : integer := 2
	);
	port (
		clk : in std_logic;
		res_n : in std_logic;
		pwm_in : in pwm_array_t;
		pwm_out : out signed (15 downto 0)
	);
end entity;


architecture arch of mixer is 

	signal mix_cnt, mix_cnt_nxt : integer := 0;
	signal pwm_sum, pwm_sum_nxt : integer := 0;
	type state_mix_t is (ADD, DIVIDE);
	signal state_mix, state_mix_nxt : state_mix_t := ADD;
	signal pwm_out_signal, pwm_out_nxt : signed (15 downto 0) := (others => '0');
	
	type pwm_array_t is array (1 downto 0) of integer;
	
begin

	pwm_out <= pwm_out_signal;


	sync_state : process(clk, res_n)
	begin
		if not res_n then
			pwm_out_signal <= (others => '0');
			state_mix <= ADD;
			mix_cnt <= 0;
			pwm_sum <= 0;
			
		elsif rising_edge(clk) then
			pwm_out_signal <= pwm_out_nxt;
			state_mix <= state_mix_nxt;
			mix_cnt <= mix_cnt_nxt;
			pwm_sum <= pwm_sum_nxt;
			
		end if;
	end process;

	
	
	create_pwm : process(all)
	begin
	
	state_mix_nxt <= state_mix;
	pwm_out_nxt <= pwm_out_signal;
	mix_cnt_nxt <= mix_cnt;
	
	case state_mix is
	
		when ADD =>
			pwm_sum_nxt <= pwm_sum + pwm_in(mix_cnt);
			mix_cnt_nxt <= mix_cnt + 1;
				
			if (mix_cnt = SYNTH_COUNT - 1) then
				mix_cnt_nxt <= 0;
				state_mix_nxt <= DIVIDE;
			end if;
				
				
		when DIVIDE =>
			pwm_out_nxt <= to_signed(pwm_sum * 16384, 16);
			
			state_mix_nxt <= ADD;
			pwm_sum_nxt <= 0;

		end case;
	end process;


end architecture;
