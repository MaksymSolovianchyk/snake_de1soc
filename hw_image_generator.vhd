LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

ENTITY hw_image_generator IS
GENERIC (
    pixels_y : INTEGER := 480; -- screen height
    pixels_x : INTEGER := 640  -- screen width
);
PORT (
    disp_ena : IN STD_LOGIC; -- display enable ('1' = display time, '0' = blanking time)
    row : IN INTEGER; -- row pixel coordinate
    column : IN INTEGER; -- column pixel coordinate
    ps2_code : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- keys for movement
    ps2_code_new : IN STD_LOGIC;
    clock : IN STD_LOGIC;
    ps2_clk : IN STD_LOGIC;
    red : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- red magnitude output
    green : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- green magnitude output
    blue : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0') -- blue magnitude output
);
END hw_image_generator;

ARCHITECTURE behavior OF hw_image_generator IS
    -- Game area definitions
    CONSTANT game_space_x_start : INTEGER := 0;
    CONSTANT game_space_x_end : INTEGER := 480;
    CONSTANT game_space_y_start : INTEGER := 0;
    CONSTANT game_space_y_end : INTEGER := 480;
    CONSTANT wall_thickness : INTEGER := 10;
	 
    CONSTANT fruit_x_bound : INTEGER := game_space_x_end - game_space_x_start - 20;
    CONSTANT fruit_y_bound : INTEGER := game_space_y_end - game_space_y_start - 20;

    -- Movement parameters
    CONSTANT step_size : INTEGER := 10;

    -- Snake and fruit parameters
    TYPE position_array IS ARRAY (0 TO 255) OF INTEGER RANGE 0 TO 470;
    SIGNAL snake_x : position_array := (100, OTHERS => 0);
    SIGNAL snake_y : position_array := (250, OTHERS => 0);
    SIGNAL snake_length : INTEGER := 1;
    SIGNAL fruit_x_start : INTEGER := 200;
    SIGNAL fruit_y_start : INTEGER := 250;
    SIGNAL fruit_width : INTEGER := 10;
    SIGNAL fruit_height : INTEGER := 10;
    -- Direction control
    SIGNAL direction : INTEGER RANGE 0 TO 3;
    SIGNAL next_direction : INTEGER RANGE 0 TO 3;
    SIGNAL local_next_direction : INTEGER RANGE 0 TO 3;

    -- Score tracking
    SIGNAL score : INTEGER := 0;
	 CONSTANT MAX_LENGTH : INTEGER := 10;
    -- Random seed
    SIGNAL random_seed : INTEGER := 1;

BEGIN
    -- Direction control logi
process(ps2_clk, ps2_code, ps2_code_new)
  begin
    if rising_edge(ps2_clk) then
      -- Default: Maintain current direction
      local_next_direction <= direction;

      if ps2_code_new = '1' then
        case direction is
          -- Current direction is Up (0)
				when 0 =>
					 if ps2_code = x"6B" or ps2_code = x"41" then
						local_next_direction <= 2;
					 elsif ps2_code = x"74" or ps2_code = x"44" then
						local_next_direction <= 3;
					 end if;

				when 1 =>
					 if ps2_code = x"6B" or ps2_code = x"41" then
						local_next_direction <= 2;
					 elsif ps2_code = x"74" or ps2_code = x"44" then
						local_next_direction <= 3;
					 end if;

				when 2 =>
					 if ps2_code = x"75" or ps2_code = x"57" then
						local_next_direction <= 0;
					 elsif ps2_code = x"72" or ps2_code = x"53" then
						local_next_direction <= 1;
					 end if;

				when 3 =>
					 if ps2_code = x"75" or ps2_code = x"57" then
						local_next_direction <= 0;
					 elsif ps2_code = x"72" or ps2_code = x"53" then
						local_next_direction <= 1;
					 end if;

          -- Default case (should not occur)
          when others =>
            local_next_direction <= direction;
        end case;
      end if;
      -- Update the next_direction output
      next_direction <= local_next_direction;

    end if;
  end process;				 
    -- Movement and game logic
    PROCESS(clock)
    BEGIN
        IF rising_edge(clock) THEN
            direction <= next_direction;

            FOR i IN 9 DOWNTO 1 LOOP
			IF i < snake_length THEN
				snake_x(i) <= snake_x(i - 1);
				snake_y(i) <= snake_y(i - 1);
				END IF;
			END LOOP;

            -- Move snake head
            CASE direction IS
                WHEN 0 => snake_y(0) <= snake_y(0) - step_size; -- Up
                WHEN 1 => snake_y(0) <= snake_y(0) + step_size; -- Down
                WHEN 2 => snake_x(0) <= snake_x(0) - step_size; -- Left
                WHEN 3 => snake_x(0) <= snake_x(0) + step_size; -- Right
                WHEN OTHERS => NULL;
            END CASE;

            -- Collision with fruit
            IF (snake_x(0) = fruit_x_start AND snake_y(0) = fruit_y_start) THEN
                score <= score + 1;
                snake_length <= snake_length + 1;

                
                random_seed <= random_seed + 1;
		fruit_x_start <= ((random_seed * 31) MOD fruit_x_bound) / 10 * 10 + game_space_x_start;
		fruit_y_start <= ((random_seed * 47) MOD fruit_y_bound) / 10 * 10 + game_space_y_start;
         END IF;

            -- Collision with walls
            IF snake_x(0) < game_space_x_start OR snake_x(0) > game_space_x_end OR
               snake_y(0) < game_space_y_start OR snake_y(0) > game_space_y_end or snake_length = MAX_LENGTH THEN
                score <= 0;
                snake_length <= 1;
					 snake_x <= (100, OTHERS => 0);
					 snake_y <= (250, OTHERS => 0);
            END IF;
				FOR i IN 1 TO 9 LOOP
                if i < snake_length then
                IF (snake_x(0) = snake_x(i) AND snake_y(0) = snake_y(i)) THEN
                    score <= 0;
                    snake_length <= 1;
						  snake_x <= (100, OTHERS => 0);
						  snake_y <= (250, OTHERS => 0);
                    END IF;
                END IF;
					 end loop;
        END IF;
    END PROCESS;

    PROCESS(disp_ena, row, column)
    BEGIN
        IF disp_ena = '1' THEN
            IF column >= game_space_x_start AND column <= game_space_x_end AND
               row >= game_space_y_start AND row <= game_space_y_end THEN
                -- Draw snake
                IF row >= snake_y(0) AND row < snake_y(0) + step_size AND
                   column >= snake_x(0) AND column < snake_x(0) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');						 
						   ELSIF row >= snake_y(1) AND row < snake_y(1) + step_size AND
                   column >= snake_x(1) AND column < snake_x(1) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(2) AND row < snake_y(2) + step_size AND
                   column >= snake_x(2) AND column < snake_x(2) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(3) AND row < snake_y(3) + step_size AND
                   column >= snake_x(3) AND column < snake_x(3) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(4) AND row < snake_y(4) + step_size AND
                   column >= snake_x(4) AND column < snake_x(4) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(5) AND row < snake_y(5) + step_size AND
                   column >= snake_x(5) AND column < snake_x(5) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(6) AND row < snake_y(6) + step_size AND
                   column >= snake_x(6) AND column < snake_x(6) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(7) AND row < snake_y(7) + step_size AND
                   column >= snake_x(7) AND column < snake_x(7) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(8) AND row < snake_y(8) + step_size AND
                   column >= snake_x(8) AND column < snake_x(8) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(9) AND row < snake_y(9) + step_size AND
                   column >= snake_x(9) AND column < snake_x(9) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
                -- Draw fruit
                ELSIF row >= fruit_y_start AND row < fruit_y_start + fruit_height AND
                      column >= fruit_x_start AND column < fruit_x_start + fruit_width THEN
                    red <= "11111111"; 
                    green <= "10101010";
                    blue <= "00000000";
                -- Draw walls
                ELSIF (column < game_space_x_start + wall_thickness OR
                       column > game_space_x_end - wall_thickness OR
                       row < game_space_y_start + wall_thickness OR
                       row > game_space_y_end - wall_thickness) THEN
                    red <= (OTHERS => '1');
                    green <= (OTHERS => '1');
                    blue <= (OTHERS => '1');
                ELSE
                    red <= (OTHERS => '0');
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '0');
                END IF;
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        ELSE
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
        END IF;
    END PROCESS;

END behavior;