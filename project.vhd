library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_reti_logiche is
Port (  i_clk : in STD_LOGIC;
        i_rst : in STD_LOGIC;
        i_start : in STD_LOGIC;
        i_data : in STD_LOGIC_VECTOR (7 downto 0);
        o_address : out STD_LOGIC_VECTOR (15 downto 0);
        o_done : out STD_LOGIC;
        o_en : out STD_LOGIC;
        o_we : out STD_LOGIC;
        o_data : out STD_LOGIC_VECTOR (7 downto 0));
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type state_type is (START,GET_COLUMN_WAIT,GET_COLUMN,GET_ROW_WAIT,GET_ROW,IN_READ_WAIT,IN_READ,CHECK_DIM_IN,CALC_DV_SHIFT,
                          CHECK_DIM_OUT,NEW_VALUE, WRITE, FINE, START_WAIT);
    signal state_next : state;
    signal state_curr : state;
    signal read_all : boolean := false
    signal MAX_PIXEL_VALUE: std_logic_vector(7 downto 0);
    signal MIN_PIXEL_VALUE: std_logic_vector(7 downto 0);
    signal counter: integer;
    signal data : std_logic_vector(7 downto 0);
    signal delta_value : std_logic_vector(7 downto 0);
    signal shift_level : integer;
    signal temp_pixel : std_logic_vector(7 downto 0);
    signal new_pixel_value : std_logic_vector(7 downto 0);
    signal int_res: integer;
    signal row: std_logic_vector(7 downto 0);
    signal clmn: std_logic_vector(7 downto 0);
    signal next_addr: std_logic_vector(15 downto 0);
    signal temp_value: integer;
    signal temp_value_vect: std_logic_vector(7 downto 0);

begin

    process(i_clk)

    begin
     transitions: process (i_clk)
     begin
         if(i_clk'event and i_clk = '1')then
             if(i_rst = '1')then
                state_curr <= START;
             else
                state_curr <= state_next;
        end if;
          else case state is               
      
            when START => read_all <= false;
            repo
                          counter <= 0; 
                          MAX_PIXEL_VALUE <= (others => '0');
                          MIN_PIXEL_VALUE <= (others => '1'); 
                          o_done <= '0';                   
                          if (i_start = '1') then _next <= GET_COLUMN_WAIT;
                          else state_next <= START;
                          end if;
                          
            when GET_COLUMN_WAIT => o_en <= '1';
                                    o_we <= '0';
                                    o_address <= std_logic_vector(to_unsigned(counter,16));
                                    state_next <=  GET_COLUMN;
                                
            when GET_COLUMN => clmn <= i_data;
                               counter <= counter +1;
                               state_next <= GET_ROW_WAIT;
                               
            when GET_ROW_WAIT => o_en <= '1';
                                 o_we <= '0';
                                 o_address <= std_logic_vector(to_unsigned(counter,16));
                                 state_next <= GET_ROW;
                                
            when GET_ROW => row <= unsigned(i_data;
                            int_res <= (to_integer(unsigned(row))*(to_integer(unsigned(clmn));
                            counter <= counter + 1;
                            state_next <= CHECK_DIM_IN;
            
            
            when CHECK_DIM_IN => if(counter <= (int_res+2)) then state_next <= IN_READ_WAIT;
                                 else state_next <= CALC_DV_SHIFT;
                                 end if;
                                
            when IN_READ_WAIT => o_en <= '1';
                                 o_we <= '0';
                                 o_address <= std_logic_vector(TO_UNSIGNED(counter,16));
                                 state_next <= IN_READ;
                            
            when IN_READ => data <= i_data;    
                            if(to_integer(unsigned(MIN_PIXEL_VALUE)) > to_integer(unsigned(data))) then MIN_PIXEL_VALUE <= data;
                            elsif (to_integer(unsigned(MAX_PIXEL_VALUE)) < to_integer(unsigned(data))) then MAX_PIXEL_VALUE <= data;
                            end if;
                            if (read_all) then state_next <= NEW_VALUE;     
                            else state_next <= CHECK_DIM_IN;     
                                
            when CALC_DV_SHIFT =>  read_all <= true;
                                   delta_value <= std_logic_vector(MAX_PIXEL_VALUE - MIN_PIXEL_VALUE);
                                   temp_value <= to_integer(unsigned(delta_value));
                                   shift_level <= 8;
                                   while temp_value>1 loop
                                        temp_value <= temp_value/2;
                                        shift_level <= shift_level - 1;
                                   end loop; 
                                   counter <= 0;
                                   state_next <= CHECK_DIM_OUT;   
                                
            when CHECK_DIM_OUT => if(counter < int_res) then state_next <= IN_READ_WAIT;
                                  else state_next <= FINE;
                                  end if;
            
            when NEW_VALUE => temp_value_vect <= std_logic_vector(unsigned(data) - MIN_PIXEL_VALUE);
                              temp_pixel <= sll std_logic_vector(shift_level(unsigned(temp_value_vect));
                              if(temp_pixel < "11111111") then new_pixel_value <= temp_pixel;
                              else new_pixel_value <= "11111111";
                              end if;
                              state_next <= WRITE;
                                  
            when WRITE => o_en <= '1';
                          o_we <= '1';
                          o_address <= std_logic_vector(to_unsigned(counter + int_res + 2,16));
                          o_data <= new_pixel_value;
                          counter <= counter + 1;
                          state_next <= CHECK_DIM_OUT;
                                                 
            
            when FINE => o_en <= '0';
                         o_we <= '0';
                         o_done <= '1';
                         state_next <= START_WAIT;
            
            when START_WAIT => if i_start = '0' then state_next <= START;
                               else state_next <= START_WAIT;
                               end if;
                                    
        end case;
    end if

end process;
end Behavioral;
                