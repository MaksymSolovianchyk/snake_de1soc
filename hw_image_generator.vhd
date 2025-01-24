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
    blue : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- blue magnitude output
	 
	 -- sound pins
	 ----------WM8731 pins-----
		AUD_BCLK: out std_logic;
		AUD_XCK: out std_logic;
		AUD_ADCLRCK:  out std_logic;
		AUD_ADCDAT: in std_logic;
		AUD_DACLRCK: out std_logic;
		AUD_DACDAT: out std_logic;

		---------FPGA pins-----

		clock_50: in std_logic;
		key: in std_logic_vector(3 downto 0);
		ledr: out std_logic_vector(9 downto 0);
		sw: in std_logic_vector(9 downto 0);
		FPGA_I2C_SCLK: out std_logic;
		FPGA_I2C_SDAT: inout std_logic
);
END hw_image_generator;

ARCHITECTURE behavior OF hw_image_generator IS
    -- Game area definitions
    CONSTANT game_space_x_start : INTEGER := 0;
    CONSTANT game_space_x_end : INTEGER := 480;
    CONSTANT game_space_y_start : INTEGER := 0;
    CONSTANT game_space_y_end : INTEGER := 480;
    CONSTANT wall_thickness : INTEGER := 10;
	 
	--score text area definitions
	 CONSTANT score_x_start : INTEGER := 500;
	 CONSTANT score_x_end : INTEGER := 619;
	 CONSTANT score_y_start : INTEGER := 100;
	 CONSTANT score_y_end : INTEGER := 150;
	 


	SIGNAL digit1 : INTEGER RANGE 0 TO 9;
    SIGNAL digit2 : INTEGER RANGE 0 TO 9;
    SIGNAL local_score : INTEGER;
	 
    CONSTANT fruit_x_bound : INTEGER := game_space_x_end - game_space_x_start - 20;
    CONSTANT fruit_y_bound : INTEGER := game_space_y_end - game_space_y_start - 20;

    -- Movement parameters
    CONSTANT step_size : INTEGER := 10;

    -- Snake and fruit parameters
    TYPE position_array IS ARRAY (0 TO 255) OF INTEGER RANGE 0 TO 470;
    SIGNAL snake_x : position_array := (100, OTHERS => 1000);
    SIGNAL snake_y : position_array := (250, OTHERS => 1000);
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
	 CONSTANT MAX_LENGTH : INTEGER := 20;
    -- Random seed
    SIGNAL random_seed : INTEGER := 1;

	 signal bitprsc: integer range 0 to 4:=0;
signal aud_mono: std_logic_vector(31 downto 0):=(others=>'0');
signal read_addr: integer range 0 to 240254:=0;
signal ROM_ADDR: std_logic_vector(17 downto 0);
signal ROM_OUT: std_logic_vector(15 downto 0);
signal clock_12pll: std_logic;
signal WM_i2c_busy: std_logic;
signal WM_i2c_done: std_logic;
signal WM_i2c_send_flag: std_logic;
signal WM_i2c_data: std_logic_vector(15 downto 0);
signal DA_CLR: std_logic:='0';

	
 component aud_gen is
 port (
    aud_clock_12: in std_logic;
    aud_bk: out std_logic;
    aud_dalr: out std_logic;
    aud_dadat: out std_logic;
    aud_data_in: in std_logic_vector(31 downto 0)
 ); 
 end component aud_gen;


component pll is
        port (
            clk_clk                         : in  std_logic                     := 'X';             -- clk
            clock_12_clk                    : out std_logic;                                        -- clk
            reset_reset_n                   : in  std_logic                     := 'X';             -- reset_n
            onchip_memory2_0_s1_address     : in  std_logic_vector(17 downto 0) := (others => 'X'); -- address
            onchip_memory2_0_s1_debugaccess : in  std_logic                     := 'X';             -- debugaccess
            onchip_memory2_0_s1_clken       : in  std_logic                     := 'X';             -- clken
            onchip_memory2_0_s1_chipselect  : in  std_logic                     := 'X';             -- chipselect
            onchip_memory2_0_s1_write       : in  std_logic                     := 'X';             -- write
            onchip_memory2_0_s1_readdata    : out std_logic_vector(15 downto 0);                    -- readdata
            onchip_memory2_0_s1_writedata   : in  std_logic_vector(15 downto 0) := (others => 'X'); -- writedata
            onchip_memory2_0_s1_byteenable  : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- byteenable
              onchip_memory2_0_reset1_reset   : in  std_logic                     := 'X'              -- reset
        );
        end component pll;



 component i2c is
 port(
    i2c_busy: out std_logic;
    i2c_scl: out std_logic;
    i2c_send_flag: in std_logic;
    i2c_sda: inout std_logic;
    i2c_addr: in std_logic_vector(7 downto 0);
    i2c_done: out std_logic;
    i2c_data: in std_logic_vector(15 downto 0);
    i2c_clock_50: in std_logic
 );
 
 end component i2c;




 
-- Larger character definitions for "S", "C", "O", "R", "E"
TYPE character_font_large IS ARRAY (0 TO 13) OF STD_LOGIC_VECTOR(9 DOWNTO 0);  -- 10x14 grid for each character


CONSTANT S_FONT_LARGE : character_font_large := (
    "0011111100",  -- Row 0
    "1111111111",  -- Row 1
    "1100000011",  -- Row 2
    "1100000011",  -- Row 3
    "1100000000",  -- Row 4
    "1111110000",  -- Row 5
    "0011111100",  -- Row 6
    "0000001100",  -- Row 7
    "0000000011",  -- Row 8
    "0000000011",  -- Row 9
    "1100000011",  -- Row 10
    "1111111111",  -- Row 11
    "0011111100",  -- Row 12
    "0000000000"   -- Row 13
);

CONSTANT C_FONT_LARGE : character_font_large := (
    "1111111111",  -- Row 0
    "1111111111",  -- Row 1
    "1100000011",  -- Row 2
    "1100000000",  -- Row 3
    "1100000000",  -- Row 4
    "1100000000",  -- Row 5
    "1100000000",  -- Row 6
    "1100000000",  -- Row 7
    "1100000000",  -- Row 8
    "1100000000",  -- Row 9
    "1100000011",  -- Row 10
    "1111111111",  -- Row 11
    "1111111111",  -- Row 12
    "0000000000"   -- Row 13
);

-- Similar definitions for O, R, E (I'll omit them for brevity)
CONSTANT O_FONT_LARGE : character_font_large := (
    "0111111110",  -- Row 0
    "1111111111",  -- Row 1
    "1100000011",  -- Row 2
    "1100000011",  -- Row 3
    "1100000011",  -- Row 4
    "1100000011",  -- Row 5
    "1100000011",  -- Row 6
    "1100000011",  -- Row 7
    "1100000011",  -- Row 8
    "1100000011",  -- Row 9
    "1100000011",  -- Row 10
    "1111111111",  -- Row 11
    "0111111110",  -- Row 12
    "0000000000"   -- Row 13
);

CONSTANT R_FONT_LARGE : character_font_large := (
    "1111111111",  -- Row 0
    "1111111111",  -- Row 1
    "1100000011",  -- Row 2
    "1100000011",  -- Row 3
    "1111111110",  -- Row 4
    "1111111100",  -- Row 5
    "1100001110",  -- Row 6
    "1100000011",  -- Row 7
    "1100000011",  -- Row 8
    "1100000011",  -- Row 9
    "1100000011",  -- Row 10
    "1100000011",  -- Row 11
    "1100000011",  -- Row 12
    "0000000000"   -- Row 13
);

CONSTANT E_FONT_LARGE : character_font_large := (
    "1111111111",  -- Row 0
    "1111111111",  -- Row 1
    "1100000000",  -- Row 2
    "1100000000",  -- Row 3
    "1100000000",  -- Row 4
    "1100000000",  -- Row 5
    "1111111110",  -- Row 6
    "1111111110",  -- Row 7
    "1100000000",  -- Row 8
    "1100000000",  -- Row 9
    "1100000000",  -- Row 10
    "1111111111",  -- Row 11
    "1111111111",  -- Row 12
    "0000000000"   -- Row 13
);

TYPE digit_font_array IS ARRAY (0 TO 9) OF character_font_large;
-- Large digit definitions (0-9) in 10x14 grid
CONSTANT DIGIT_FONT_LARGE : digit_font_array := (
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "1100000011",  -- Row 2
        "1100000011",  -- Row 3
        "1100000011",  -- Row 4
        "1100000011",  -- Row 5
        "1100000011",  -- Row 6
        "1100000011",  -- Row 7
        "1100000011",  -- Row 8
        "1100000011",  -- Row 9
        "1100000011",  -- Row 10
        "1111111111",  -- Row 11
        "1111111111",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 1
    (
        "0000000011",  -- Row 0
        "0000000011",  -- Row 1
        "0000000011",  -- Row 2
        "0000000011",  -- Row 3
        "0000000011",  -- Row 4
        "0000000011",  -- Row 5
        "0000000011",  -- Row 6
        "0000000011",  -- Row 7
        "0000000011",  -- Row 8
        "0000000011",  -- Row 9
        "0000000011",  -- Row 10
        "0000000011",  -- Row 11
        "0000000011",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 2
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "1100000011",  -- Row 2
        "0000000011",  -- Row 3
        "0000000011",  -- Row 4
        "1111111111",  -- Row 5
        "1111111111",  -- Row 6
        "1100000000",  -- Row 7
        "1100000000",  -- Row 8
        "1100000000",  -- Row 9
        "1100000001",  -- Row 10
        "1111111111",  -- Row 11
        "1111111111",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 3
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "0000000011",  -- Row 2
        "0000000011",  -- Row 3
        "0000000011",  -- Row 4
        "1111111111",  -- Row 5
        "1111111111",  -- Row 6
        "0000000011",  -- Row 7
        "0000000011",  -- Row 8
        "0000000011",  -- Row 9
        "0000000011",  -- Row 10
        "1111111111",  -- Row 11
        "1111111111",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 4
    (
        "1100000011",  -- Row 0
        "1100000011",  -- Row 1
        "1100000011",  -- Row 2
        "1100000011",  -- Row 3
        "1111111111",  -- Row 4
        "1111111111",  -- Row 5
        "0000000011",  -- Row 6
        "0000000011",  -- Row 7
        "0000000011",  -- Row 8
        "0000000011",  -- Row 9
        "0000000011",  -- Row 10
        "0000000011",  -- Row 11
        "0000000011",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 5
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "1100000000",  -- Row 2
        "1100000000",  -- Row 3
        "1100000000",  -- Row 4
        "1111111111",  -- Row 5
        "1111111111",  -- Row 6
        "0000000011",  -- Row 7
        "0000000011",  -- Row 8
        "0000000011",  -- Row 9
        "1000000011",  -- Row 10
        "1111111111",  -- Row 11
        "1111111111",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 6
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "1100000000",  -- Row 2
        "1100000000",  -- Row 3
        "1100000000",  -- Row 4
        "1111111111",  -- Row 5
        "1111111111",  -- Row 6
        "1100000011",  -- Row 7
        "1100000011",  -- Row 8
        "1100000011",  -- Row 9
        "1100000011",  -- Row 10
        "1111111111",  -- Row 11
        "1111111111",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 7
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "0000000011",  -- Row 2
        "0000000011",  -- Row 3
        "0000000011",  -- Row 4
        "0000000110",  -- Row 5
        "0000001100",  -- Row 6
        "0000011000",  -- Row 7
        "0000110000",  -- Row 8
        "0001100000",  -- Row 9
        "0011000000",  -- Row 10
        "0110000000",  -- Row 11
        "1100000000",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 8
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "1100000011",  -- Row 2
        "1100000011",  -- Row 3
        "1100000011",  -- Row 4
        "1111111111",  -- Row 5
        "1111111111",  -- Row 6
        "1100000011",  -- Row 7
        "1100000011",  -- Row 8
        "1100000011",  -- Row 9
        "1100000011",  -- Row 10
        "1111111111",  -- Row 11
        "1111111111",  -- Row 12
        "0000000000"   -- Row 13
    ),
    
    -- 9
    (
        "1111111111",  -- Row 0
        "1111111111",  -- Row 1
        "1100000011",  -- Row 2
        "1100000011",  -- Row 3
        "1100000011",  -- Row 4
        "1111111111",  -- Row 5
        "1111111111",  -- Row 6
        "0000000011",  -- Row 7
        "0000000011",  -- Row 8
        "0000000011",  -- Row 9
        "0000000011",  -- Row 10
        "1111111111",  -- Row 11
        "1111111111",  -- Row 12
        "0000000000"   -- Row 13
    )
);
	 
	 
BEGIN

u0 : component pll
        port map (
            clk_clk       => clock_50,                                           -- clk.clk
            reset_reset_n => '1',                                                -- reset.reset_n
            clock_12_clk  => clock_12pll, 												   -- clock_12.clk
				onchip_memory2_0_s1_address     => ROM_ADDR,
            onchip_memory2_0_s1_debugaccess =>'0',                               -- debugaccess
            onchip_memory2_0_s1_clken       =>'1',                               -- clken
            onchip_memory2_0_s1_chipselect  =>'1',                               -- chipselect
            onchip_memory2_0_s1_write      =>'0',                                -- write
            onchip_memory2_0_s1_readdata   =>ROM_OUT,                            -- readdata
            onchip_memory2_0_s1_writedata  =>(others=>'0'),
            onchip_memory2_0_s1_byteenable  =>"11",
				onchip_memory2_0_reset1_reset=>'0'
				);


sound: component aud_gen
		port map(
		aud_clock_12=>clock_12pll,
		aud_bk=>AUD_BCLK,
		aud_dalr=>DA_CLR,
		aud_dadat=>AUD_DACDAT,	
		aud_data_in=>aud_mono

		);

WM8731: component i2c 
		port map(
			i2c_busy=>WM_i2c_busy,
			i2c_scl=>FPGA_I2C_SCLK,
			i2c_send_flag=>WM_i2c_send_flag,
			i2c_sda=>FPGA_I2C_SDAT,
			i2c_addr=>"00110100",
			i2c_done=>WM_i2c_done,
			i2c_data=>WM_i2c_data,
			i2c_clock_50=>clock_50	
		);

		
AUD_XCK<=clock_12pll;
AUD_DACLRCK<=DA_CLR;
	
ROM_ADDR<=std_logic_vector(to_unsigned(read_addr,18));

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
	 --variable can_spawn:BOOLEAN;
	 VARIABLE fruit_new_x : INTEGER;
	 VARIABLE fruit_new_y : INTEGER;
    BEGIN
        IF rising_edge(clock) THEN
            direction <= next_direction;
				
            FOR i IN MAX_LENGTH DOWNTO 1 LOOP
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
					 
					 fruit_new_x := ((random_seed * 31) MOD fruit_x_bound) / 10 * 10 + game_space_x_start;
					 fruit_new_y := ((random_seed * 47) MOD fruit_y_bound) / 10 * 10 + game_space_y_start;
								
					 for i in 0 to MAX_LENGTH loop
							iF  i <= snake_length then
							 if fruit_new_x = snake_x(i) and fruit_new_y = snake_y(i) then
								fruit_new_x := ((random_seed * 31) MOD fruit_x_bound) / 10 * 10 + game_space_x_start+i*10;
								fruit_new_y := ((random_seed * 47) MOD fruit_y_bound) / 10 * 10 + game_space_y_start+i*10;
								end if;
							end if;
					end loop;
					fruit_x_start <= fruit_new_x;
					fruit_y_start <= fruit_new_y;
         END IF;

            -- Collision with walls
            IF snake_x(0) < game_space_x_start OR snake_x(0) > game_space_x_end OR
               snake_y(0) < game_space_y_start OR snake_y(0) > game_space_y_end or snake_length = MAX_LENGTH THEN
                score <= 0;
                snake_length <= 1;
					 snake_x <= (100, OTHERS => 1000);
					 snake_y <= (250, OTHERS => 1000);
            END IF;
				FOR i IN 1 TO MAX_LENGTH LOOP
                if i < snake_length then
                IF (snake_x(0) = snake_x(i) AND snake_y(0) = snake_y(i)) THEN
                    score <= 0;
                    snake_length <= 1;
						  snake_x <= (100, OTHERS => 1000);
						  snake_y <= (250, OTHERS => 1000);
                    END IF;
                END IF;
					 end loop;
        END IF;
    END PROCESS;

	 
	------------------------------------------------------------------------------------------------------------------- 

 
process (clock_12pll)
begin

if rising_edge(clock_12pll)then

 	if(SW(8)='1')then--------reset
	read_addr<=0;
	bitprsc<=0;
	aud_mono<=(others=>'0');
	else
	LEDR(1)<=SW(7);
	aud_mono(15 downto 0)<=ROM_OUT;----mono sound
	aud_mono(31 downto 16)<=ROM_OUT;
	  if(DA_CLR='1')then
			if(bitprsc<5)then----8ksps
			bitprsc<=bitprsc+1;
			else
			bitprsc<=0;
				if(read_addr<240254)then
				read_addr<=read_addr+1;
				else
				read_addr<=0;
				end if;
			end if;
		end if;
	end if;


	
end if;

end process;	

process (clock_50)
begin

	if rising_edge (clock_50)then
		if(KEY="1111")then
		WM_i2c_send_flag<='0';
		end if;
	end if;
 if rising_edge(clock_50) and WM_i2c_busy='0' then
 
	
		if (KEY(0)='0') then ----Digital Interface: DSP, 16 bit, slave mode
		WM_i2c_data(15 downto 9)<="0000111";
		WM_i2c_data(8 downto 0)<="000010011";	
		WM_i2c_send_flag<='1';
			
		elsif (KEY(0)='0'AND SW(0)='1' ) then---HEADPHONE VOLUME
		WM_i2c_data(15 downto 9)<="0000010";
		WM_i2c_data(8 downto 0)<="101111001";
		WM_i2c_send_flag<='1';
		
		elsif (KEY(1)='0'AND SW(0)='0' ) then---ADC of, DAC on, Linout ON, Power ON
		WM_i2c_data(15 downto 9)<="0000110";
		WM_i2c_data(8 downto 0)<="000000111";
	
		WM_i2c_send_flag<='1';
		elsif (KEY(1)='0'AND SW(0)='1' ) then---USB mode
		WM_i2c_data(15 downto 9)<="0001000";
		WM_i2c_data(8 downto 0)<="000000001";
		
		WM_i2c_send_flag<='1';
		elsif (KEY(2)='0'AND SW(0)='0') then---activ interface
		WM_i2c_data(15 downto 9)<="0001001";
		WM_i2c_data(8 downto 0)<="111111111";
		
		WM_i2c_send_flag<='1';
		elsif (KEY(2)='0'AND SW(0)='1') then---Enable DAC to LINOUT
		WM_i2c_data(15 downto 9)<="0000100";
		WM_i2c_data(8 downto 0)<="000010010";
		
		WM_i2c_send_flag<='1';
		elsif (KEY(3)='0' AND SW(0)='0') then---remove mute DAC
		WM_i2c_data(15 downto 9)<="0000101";
		WM_i2c_data(8 downto 0)<="000000000";
		
		WM_i2c_send_flag<='1';
		elsif (KEY(3)='0' AND SW(0)='1') then---reset
		WM_i2c_data(15 downto 9)<="0001111";
		WM_i2c_data(8 downto 0)<="000000000";
		
		WM_i2c_send_flag<='1';
		end if;
 

 
 
 end if;
end process;
	 
	------------------------------------------------------------------------------------------------------------------- 
 
	 
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
						     ELSIF row >= snake_y(10) AND row < snake_y(10) + step_size AND
                   column >= snake_x(10) AND column < snake_x(10) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(11) AND row < snake_y(11) + step_size AND
                   column >= snake_x(11) AND column < snake_x(11) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(12) AND row < snake_y(12) + step_size AND
                   column >= snake_x(12) AND column < snake_x(12) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(13) AND row < snake_y(13) + step_size AND
                   column >= snake_x(13) AND column < snake_x(13) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						   ELSIF row >= snake_y(14) AND row < snake_y(14) + step_size AND
                   column >= snake_x(14) AND column < snake_x(14) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(15) AND row < snake_y(15) + step_size AND
                   column >= snake_x(15) AND column < snake_x(15) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(16) AND row < snake_y(16) + step_size AND
                   column >= snake_x(16) AND column < snake_x(16) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(17) AND row < snake_y(17) + step_size AND
                   column >= snake_x(17) AND column < snake_x(17) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(18) AND row < snake_y(18) + step_size AND
                   column >= snake_x(18) AND column < snake_x(18) + step_size THEN
                    red <= (OTHERS => '1'); 
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '1');
						  ELSIF row >= snake_y(19) AND row < snake_y(19) + step_size AND
                   column >= snake_x(19) AND column < snake_x(19) + step_size THEN
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
                ELSe
                    red <= (OTHERS => '0');
                    green <= (OTHERS => '0');
                    blue <= (OTHERS => '0');
                END IF;
					 
					   -- "SCORE" section logic
             -- "SCORE" section logic
ELSIF column >= score_x_start AND column <= score_x_end AND
      row >= score_y_start AND row < score_y_start + 14 THEN
		
		 
			 local_score <= score;
			 
			 -- Extract tens and ones digits
			 digit1 <= local_score / 10;  -- Tens place
			 digit2 <= local_score MOD 10;  -- Ones place
    -- Determine the current character column with added spacing
    CASE column - score_x_start IS
        -- Draw "S" (0-9) with space after
        WHEN 0 TO 9 =>
            IF S_FONT_LARGE(row - score_y_start)(9 - (column - score_x_start)) = '1' THEN
                red <= (OTHERS => '1');
                green <= (OTHERS => '1');
                blue <= (OTHERS => '1');
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        
        -- Space after S (10)
        WHEN 10 =>
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
        
        -- Draw "C" (11-20) with space after
        WHEN 11 TO 20 =>
            IF C_FONT_LARGE(row - score_y_start)(9 - (column - (score_x_start + 11))) = '1' THEN
                red <= (OTHERS => '1');
                green <= (OTHERS => '1');
                blue <= (OTHERS => '1');
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        
        -- Space after C (21)
        WHEN 21 =>
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
        
        -- Draw "O" (22-31) with space after
        WHEN 22 TO 31 =>
            IF O_FONT_LARGE(row - score_y_start)(9 - (column - (score_x_start + 22))) = '1' THEN
                red <= (OTHERS => '1');
                green <= (OTHERS => '1');
                blue <= (OTHERS => '1');
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        
        -- Space after O (32)
        WHEN 32 =>
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
        
        -- Draw "R" (33-42) with space after
        WHEN 33 TO 42 =>
            IF R_FONT_LARGE(row - score_y_start)(9 - (column - (score_x_start + 33))) = '1' THEN
                red <= (OTHERS => '1');
                green <= (OTHERS => '1');
                blue <= (OTHERS => '1');
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        
        -- Space after R (43)
        WHEN 43 =>
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
        
        -- Draw "E" (44-53)
        WHEN 44 TO 53 =>
            IF E_FONT_LARGE(row - score_y_start)(9 - (column - (score_x_start + 44))) = '1' THEN
                red <= (OTHERS => '1');
                green <= (OTHERS => '1');
                blue <= (OTHERS => '1');
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        
        WHEN 54 TO 59 =>
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
        
        -- First digit (tens place) from column 60-69
        WHEN 60 TO 69 =>
            IF DIGIT_FONT_LARGE(digit1)(row - score_y_start)(9 - (column - (score_x_start + 60))) = '1' THEN
                red <= (OTHERS => '1');
                green <= (OTHERS => '1');
                blue <= (OTHERS => '1');
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        
        -- Space after first digit
        WHEN 70 TO 74 =>
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
        
        -- Second digit (ones place) from column 75-84
        WHEN 75 TO 84 =>
            IF DIGIT_FONT_LARGE(digit2)(row - score_y_start)(9 - (column - (score_x_start + 75))) = '1' THEN
                red <= (OTHERS => '1');
                green <= (OTHERS => '1');
                blue <= (OTHERS => '1');
            ELSE
                red <= (OTHERS => '0');
                green <= (OTHERS => '0');
                blue <= (OTHERS => '0');
            END IF;
        
        WHEN OTHERS =>
            red <= (OTHERS => '0');
            green <= (OTHERS => '0');
            blue <= (OTHERS => '0');
    END CASE;
ELSE
    -- Default black background outside defined regions
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