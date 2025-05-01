-- manages the filter calculation of the passed audio samples
-- the passed sample is a 24 bit integer. The calculation is done using 64 bit floating point precision.
-- Calculation steps are executed nested.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.filter_pkg.all;
use ieee.math_real.all;


	entity filter is
		generic (
			constant order : integer := 1
		);
		port (
			clk 					: in std_logic;
			res_n 				: in std_logic;
			filter_in 			: in signed (23 downto 0);
			filter_out 			: out signed (23 downto 0);
			finished_reading 	: in std_logic;
			coefficients_addr	: inout std_logic_vector (3 downto 0);
			coefficients		: in std_logic_vector (63 downto 0);
			left_right			: in std_logic
		);
	end entity;


architecture arch of filter is

	type states_array_t is array (1 downto 0) of std_logic_vector(63 downto 0);
	signal left_states, right_states, left_states_nxt, right_states_nxt, left_states_old, right_states_old : states_array_t;

	type res_cache_add_array_t is array (1 downto 0) of std_logic_vector(63 downto 0);
	signal res_cache_add, res_cache_add_nxt : res_cache_add_array_t;

	type res_cache_mult_array_t is array (2 downto 0) of std_logic_vector(63 downto 0);
	signal res_cache_mult, res_cache_mult_nxt : res_cache_mult_array_t;

	signal filter_in_new, filter_out_nxt, filter_out_intern : signed (23 downto 0);
	signal fp_to_int_res : std_logic_vector (23 downto 0);

	signal output_enable : std_logic := '1';
	signal left_right_new : std_logic := '1';

	-- calculation steps for the states and the output
	signal calc_state, calc_state_nxt : integer := 0;
	signal calc_count, calc_count_nxt : integer := 0;

	-- doubles
	signal fp_mult_in_a, fp_mult_in_b, fp_add1_in_a, fp_add1_in_b, fp_add2_in_a, fp_add2_in_b, fp_to_int_in : std_logic_vector (63 downto 0) := (62 => '1', others => '0');	-- 10
	signal fp_mult_res, fp_add1_res, fp_add2_res, int_to_fp_res : std_logic_vector (63 downto 0);
	signal clk_en_MULT, clk_en_ADD1, clk_en_CONV_fp_to_int, clk_en_CONV_int_to_fp : std_logic;




		 component FP_MULT_altfp_mult_3do
			 PORT
			 (
				 clk_en	:	IN  STD_LOGIC;
				 clock	:	IN  STD_LOGIC;
				 dataa	:	IN  STD_LOGIC_VECTOR (63 DOWNTO 0);
				 datab	:	IN  STD_LOGIC_VECTOR (63 DOWNTO 0);
				 result	:	OUT  STD_LOGIC_VECTOR (63 DOWNTO 0)
			 );
		 END component;


		component FP_ADD IS
			PORT
			(
				clk_en	: IN  STD_LOGIC;
				clock		: IN STD_LOGIC ;
				dataa		: IN STD_LOGIC_VECTOR (63 DOWNTO 0);
				datab		: IN STD_LOGIC_VECTOR (63 DOWNTO 0);
				result		: OUT STD_LOGIC_VECTOR (63 DOWNTO 0)
			);
		END component;


		 component  CONVERT_int_to_fp IS
			 PORT
			 (
				 clk_en	:  IN  STD_LOGIC;
				 clock	:	IN  STD_LOGIC;
				 dataa	:	IN  STD_LOGIC_VECTOR (23 DOWNTO 0);
				 result	:	OUT  STD_LOGIC_VECTOR (63 DOWNTO 0)
			 );
		 END component;


		COMPONENT CONVERT_fp_to_int is
		PORT (
				clk_en	: IN  STD_LOGIC;
				clock	: IN STD_LOGIC ;
				dataa	: IN STD_LOGIC_VECTOR (63 DOWNTO 0);
				result	: OUT STD_LOGIC_VECTOR (23 DOWNTO 0)
		);
		END COMPONENT;


begin

	sync_state : process(clk, res_n)
	begin
		if not res_n then
			left_states <= (others => (others => '0'));
			right_states <= (others => (others => '0'));
			calc_count <= 0;
			calc_state <= 0;
			res_cache_mult <= (others => (others => '0'));
			res_cache_add <= (others => (others => '0'));
			filter_out_intern <= (others => '0');
			filter_out <= (others => '0');
			left_states_old <= (others => (others => '0'));
			right_states_old <= (others => (others => '0'));

		elsif rising_edge(clk) then
			if finished_reading and output_enable then
				filter_in_new <= filter_in;
				filter_out <= filter_out_intern;
				left_right_new <= left_right;
				output_enable <= '0';
				left_states_old <= left_states;
				right_states_old <= right_states;
				calc_state <= 0;
				calc_count <= 0;
			else
				calc_count <= calc_count_nxt;
				calc_state <= calc_state_nxt;
				res_cache_mult <= res_cache_mult_nxt;
				res_cache_add <= res_cache_add_nxt;
				filter_out_intern <= filter_out_nxt;
				left_states <= left_states_nxt;
				right_states <= right_states_nxt;
			end if;

			if finished_reading = '0' then
				output_enable <= '1';
			end if;

		end if;
	end process;


	filtering : process(all)
	begin

		left_states_nxt <= left_states;
		right_states_nxt <= right_states;
		filter_out_nxt <= filter_out_intern;
		calc_count_nxt <= calc_count;
		calc_state_nxt <= calc_state;
		res_cache_mult_nxt <= res_cache_mult;
		res_cache_add_nxt <= res_cache_add;

		fp_mult_in_a <= (others => '0');
		fp_mult_in_b <= (others => '0');
		fp_add1_in_a <= (others => '0');
		fp_add1_in_b <= (others => '0');
		fp_to_int_in <= (others => '0');

		calc_count_nxt <= calc_count + 1;

		clk_en_MULT <= '0';
		clk_en_ADD1 <= '0';
		clk_en_CONV_fp_to_int <= '0';
		clk_en_CONV_int_to_fp <= '0';

		coefficients_addr <= (others => '0');

	case order is

		-- Bandpassfilter 2nd order:
		--
		-- X = A * X_old + B * U = |a11, a12| * |x1| + |b1| * u
		--						   |a21, a22|   |x2|   |b2|
		--
		-- Y = C * X_old + D * U = |c1, c2| * |x1| + d * u
		--									  |x2|
		--
		when 1 =>

			if left_right_new = '1' then

				-- left signal
				case calc_state is

					-- a11 * x1
					when 0 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_CONV_int_to_fp <= '1'; 			-- enable int to fp CONV

						fp_mult_in_a <= left_states_old(0);		-- x1
						fp_mult_in_b <= coefficients;			-- a11

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(1, 4));

					-- a12 * x2
					when 1 =>
						clk_en_MULT <= '1';
						clk_en_CONV_int_to_fp <= '1';

						fp_mult_in_a <= left_states_old(1);			-- x2
						fp_mult_in_b <= coefficients;				-- a12

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(3, 4));

					-- a21 * x1
					when 2 =>
						clk_en_MULT <= '1';
						clk_en_CONV_int_to_fp <= '1';

						fp_mult_in_a <= left_states_old(0);			-- x1
						fp_mult_in_b <= coefficients;				-- a21

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(4, 4));

					-- a22 * x2
					when 3 =>
						clk_en_MULT <= '1';
						clk_en_CONV_int_to_fp <= '1';

						fp_mult_in_a <= left_states_old(1);			-- x2
						fp_mult_in_b <= coefficients;				-- a22

						if calc_count = 1 then						-- wait one clock cycle
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
							coefficients_addr <= std_logic_vector(to_unsigned(7, 4));
						end if;

					-- c2 * x2
					when 4 =>
						clk_en_MULT <= '1';
						clk_en_CONV_int_to_fp <= '1';

						fp_mult_in_a <= left_states_old(1);					-- x2 |
						fp_mult_in_b <= coefficients;						-- c2 | = y

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						res_cache_mult_nxt(0) <= fp_mult_res;				-- result of a11 * x1

					-- a11 * x1 + a12 * x2
					when 5 =>
						clk_en_MULT <= '1';
						clk_en_ADD1 <= '1';

						fp_add1_in_a <= res_cache_mult(0);					-- a11 * x1
						fp_add1_in_b <= fp_mult_res;						-- a12 * x2

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;

					when 6 =>
						clk_en_MULT <= '1';
						clk_en_ADD1 <= '1';

						calc_state_nxt <= calc_state + 1;
						res_cache_mult_nxt(0) <= fp_mult_res;				-- result of a21 * x1
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(2, 4));

					-- u * b1, a21 * x1 + a22 * x2
					when 7 =>
						clk_en_MULT <= '1';
						clk_en_ADD1 <= '1';

						fp_mult_in_a <= int_to_fp_res;						-- u
						fp_mult_in_b <= coefficients;						-- b1

						fp_add1_in_a <= res_cache_mult(0);					-- a21 * x1
						fp_add1_in_b <= fp_mult_res;						-- a22 * x2

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;

					when 8 =>
						clk_en_MULT <= '1';
						clk_en_ADD1 <= '1';
						clk_en_CONV_fp_to_int <= '1';			-- enable fp_to_int_CONV

						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;
						coefficients_addr <= std_logic_vector(to_unsigned(5, 4));

					-- b2 * u
					when 9 =>
						clk_en_MULT <= '1';
						clk_en_ADD1 <= '1';
						clk_en_CONV_fp_to_int <= '1';

						fp_mult_in_a <= int_to_fp_res;						-- u
						fp_mult_in_b <= coefficients;						-- b2

						fp_to_int_in <= fp_mult_res;						-- (uint24_t) y

						if calc_count = 2 then
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
						end if;

					-- a11 * x1 + a12 * x2 + b1 * u = x1_new
					when 10 =>
						clk_en_MULT <= '1';
						clk_en_ADD1 <= '1';
						clk_en_CONV_fp_to_int <= '1';

						fp_add1_in_a <= fp_mult_res;
						fp_add1_in_b <= fp_add1_res;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;

					when 11 =>
						clk_en_ADD1 <= '1';
						clk_en_CONV_fp_to_int <= '1';
						clk_en_MULT <= '1';

						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					-- a21 * x1 + a22 * x2 + b2 * u = x2_new
					when 12 =>
						clk_en_ADD1 <= '1';
						clk_en_CONV_fp_to_int <= '1';
						clk_en_MULT <= '1';

						fp_add1_in_a <= fp_mult_res;
						fp_add1_in_b <= fp_add1_res;

						if calc_count = 1 then
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
							filter_out_nxt <= to_signed(to_integer(signed(fp_to_int_res)) * 2, 24);
						end if;

					when 13 =>
						clk_en_ADD1 <= '1';

						if calc_count = 2 then
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
						end if;

					when 14 =>
						clk_en_ADD1 <= '1';

						left_states_nxt(0) <= fp_add1_res;		-- save x1_new
						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					when 15 =>
						clk_en_ADD1 <= '1';

						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					when 16 =>
						clk_en_ADD1 <= '1';

						left_states_nxt(1) <= fp_add1_res;		-- save x2_new
						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					when others =>
						calc_count_nxt <= 0;

				end case;


			else

				-- Same as before, but for the right signal.
				case calc_state is

					when 0 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_CONV_int_to_fp <= '1'; 	-- enable int to fp CONV

						fp_mult_in_a <= right_states_old(0);
						fp_mult_in_b <= coefficients;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(1, 4));

					when 1 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_CONV_int_to_fp <= '1'; 	-- enable int to fp CONV

						fp_mult_in_a <= right_states_old(1);
						fp_mult_in_b <= coefficients;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(3, 4));

					when 2 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_CONV_int_to_fp <= '1'; 	-- enable int to fp CONV

						fp_mult_in_a <= right_states_old(0);
						fp_mult_in_b <= coefficients;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(4, 4));

					when 3 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_CONV_int_to_fp <= '1'; 	-- enable int to fp CONV

						fp_mult_in_a <= right_states_old(1);
						fp_mult_in_b <= coefficients;

						if calc_count = 1 then
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
							coefficients_addr <= std_logic_vector(to_unsigned(7, 4));
						end if;

					when 4 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_CONV_int_to_fp <= '1'; 	-- enable int to fp CONV

						fp_mult_in_a <= right_states_old(1);				-- output
						fp_mult_in_b <= coefficients;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;
						res_cache_mult_nxt(0) <= fp_mult_res;				-- Term 1

					when 5 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD

						fp_add1_in_a <= res_cache_mult(0);
						fp_add1_in_b <= fp_mult_res;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;

					when 6 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD

						calc_state_nxt <= calc_state + 1;
						res_cache_mult_nxt(0) <= fp_mult_res;
						calc_count_nxt <= 0;
						coefficients_addr <= std_logic_vector(to_unsigned(2, 4));

					when 7 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD

						fp_mult_in_a <= int_to_fp_res;
						fp_mult_in_b <= coefficients;

						fp_add1_in_a <= res_cache_mult(0);
						fp_add1_in_b <= fp_mult_res;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;

					when 8 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD
						clk_en_CONV_fp_to_int <= '1';			-- enable fp_to_int_CONV

						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;
						coefficients_addr <= std_logic_vector(to_unsigned(5, 4));

					when 9 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD
						clk_en_CONV_fp_to_int <= '1';			-- enable fp_to_int_CONV

						fp_mult_in_a <= int_to_fp_res;
						fp_mult_in_b <= coefficients;

						fp_to_int_in <= fp_mult_res;

						if calc_count = 2 then
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
						end if;

					when 10 =>
						clk_en_MULT <= '1'; 					-- enable fp_MULT
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD
						clk_en_CONV_fp_to_int <= '1';			-- enable fp_to_int_CONV

						fp_add1_in_a <= fp_mult_res;
						fp_add1_in_b <= fp_add1_res;

						calc_state_nxt <= calc_state + 1;
						calc_count_nxt <= 0;

					when 11 =>
						clk_en_ADD1 <= '1'; 						-- enable fp_ADD
						clk_en_CONV_fp_to_int <= '1';			-- enable fp_to_int_CONV
						clk_en_MULT <= '1'; 						-- enable fp_MULT

						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					when 12 =>
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD
						clk_en_CONV_fp_to_int <= '1';			-- enable fp_to_int_CONV
						clk_en_MULT <= '1'; 						-- enable fp_MULT

						fp_add1_in_a <= fp_mult_res;
						fp_add1_in_b <= fp_add1_res;

						if calc_count = 1 then
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
							filter_out_nxt <= to_signed(to_integer(signed(fp_to_int_res)) * 2, 24);
						end if;

					when 13 =>
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD

						if calc_count = 2 then
							calc_count_nxt <= 0;
							calc_state_nxt <= calc_state + 1;
						end if;

					when 14 =>
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD

						right_states_nxt(0) <= fp_add1_res;
						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					when 15 =>
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD

						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					when 16 =>
						clk_en_ADD1 <= '1'; 					-- enable fp_ADD

						right_states_nxt(1) <= fp_add1_res;
						calc_count_nxt <= 0;
						calc_state_nxt <= calc_state + 1;

					when others =>
						calc_count_nxt <= 0;

				end case;

			end if;


		-- no filtering
		when others =>
			filter_out_nxt <= to_signed(to_integer(filter_in_new) * 2, 24);

		end case;
	end process;



	-- instantiation of a floating point multiplication module
	FP_MULT_inst : FP_MULT_altfp_mult_3do
	port map (
		clk_en => clk_en_MULT,
		clock	=> clk,
		dataa => fp_mult_in_a,
		datab => fp_mult_in_b,
		result => fp_mult_res
	);

	-- instantiation of a floating point addition module
	FP_ADD_inst : FP_ADD
	PORT MAP(
		clk_en => clk_en_ADD1,
		clock	=> clk,
		dataa => fp_add1_in_a,
		datab => fp_add1_in_b,
		result => fp_add1_res
	);

	-- instantiation of a integer to floating point convertion module
	int_to_fp_inst : CONVERT_int_to_fp
	PORT MAP (
		clk_en => clk_en_CONV_int_to_fp,
		clock	 => clk,
		dataa	 => std_logic_vector(filter_in_new),
		result => int_to_fp_res
	);

	-- instantiation of a floating point to integer convertion module
	fp_to_int_inst : CONVERT_fp_to_int
	PORT MAP (
		clk_en => clk_en_CONV_fp_to_int,
		clock	 => clk,
		dataa	 => fp_to_int_in,
		result => fp_to_int_res
	);



end architecture;
