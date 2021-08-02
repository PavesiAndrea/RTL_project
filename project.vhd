 library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_reti_logiche is
Port ( i_clk : in STD_LOGIC;
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

type state is (START, IN_READ, GET_DIM,
CHECK_DIM_IN, CHECK_MIN, CHECK_MAX, CALC_DV, CALC_SHIFT,CHECK_DIM_OUT, NEW_VALUE, FINE, LOW_START_WAIT);
signal state_next: state;
signal state_curr: state;

begin

 process(i_clk, i_rst)
variable counter: integer;
variable wr_counter : integer;
variable data : integer;
variable delta_value : integer;
variable shift_value : integer;
variable temp_pixel : std_logic_vector(7 downto 0);
variable new_pixel_value : std_logic_vector(7 downto 0);
variable int_res: integer;
variable row: std_logic_vector(7 downto 0);
variable column: std_logic_vector(7 downto 0);
variable next_addr: std_logic_vector(15 downto 0);
variable min: integer;
variable max: integer;
variable temp_value: std_logic_vector(7 downto 0);

begin
--if(i_clk'event and i_clk = '1') then
-- if(i_rst = '1') then state_curr<=START_WAIT;
--else state_curr<=state_next;
--end if;
    if(i_rst = '1') then
        o_en <= '0';
        o_we <= '0';
        o_done <= '0';
        counter := 0;
        wr_counter := 1;
        data := 0;
        state_curr <= START;
    elsif(rising_edge(i_clk)) then
    case state_curr is
        when START => if(i_start = '1' AND i_rst = '0') then
                            o_en <= '1';
                            o_we <= '0';
                            temp_pixel := "00000000";
                            delta_value := 0;
                            shift_value := 0;
                            new_pixel_value := "00000000";
                            row := "00000000";
                            column := "00000000";
                            state_next <= GET_DIM;
                        else state_next <= START;
                        end if;
        
        when GET_DIM => o_address <= "0000000000000000";
                        column := i_data;
                        o_address <= "0000000000000001";
                        row := i_data;
                        int_res := (to_integer(unsigned(row)))*(to_integer(unsigned(column)));
                        state_next <= CHECK_DIM_IN;
        
        when CHECK_DIM_IN => if(counter < int_res) then state_next<= IN_READ;
                            else state_next <= CALC_DV;
                            end if;
                            
        when IN_READ => o_en <= '1';
                        o_we <= '0';
                        counter := counter + 1;
                        next_addr := std_logic_vector(TO_UNSIGNED((counter +1),16));
                        o_address <= next_addr;
                        data := TO_INTEGER(unsigned(i_data));
                        if(counter = 1) then min := data;
                                             max := min;
                                             state_next <= CHECK_DIM_IN;
                        else state_next <= CHECK_MIN;
                        end if;
                            
        when CHECK_MIN => if(data < min) then min := data;
                                         state_next <= CHECK_DIM_IN;
                            else state_next <= CHECK_MAX;
                            end if;
                            
        when CHECK_MAX => if(data > max) then max := data;
                            end if;
                            state_next <= CHECK_DIM_IN;
                            
        when CALC_DV => delta_value := (max - min);
                        state_next <= CALC_SHIFT;
                        
        when CALC_SHIFT => delta_value := delta_value + 1;
                           shift_value := 8;
                           while delta_value > 1 loop
                                delta_value := delta_value/2;
                                shift_value := shift_value - 1;
                           end loop;
                           state_next <= CHECK_DIM_OUT;
                            
        when CHECK_DIM_OUT => if(wr_counter < int_res) then state_next <= NEW_VALUE;
                              else state_next <= FINE;
                              end if;
        
        when NEW_VALUE =>  o_en <= '1';
                           o_we <= '1';
                           wr_counter := wr_counter + 1;
                           next_addr := std_logic_vector(TO_UNSIGNED((wr_counter),16));
                           o_address <= next_addr;
                           temp_value := i_data;
                           temp_value := std_logic_vector(to_unsigned((to_integer(unsigned(temp_value))) - min,8));
                           temp_pixel := std_logic_vector(shift_left(unsigned(temp_value), shift_value));
                           next_addr := std_logic_vector(TO_UNSIGNED((wr_counter + int_res),16));
                           if((to_integer(unsigned(temp_pixel))) < 255) then new_pixel_value := temp_pixel;
                           else new_pixel_value := "11111111";
                           end if;
                           o_address <= next_addr;
                           o_data <= new_pixel_value;
                           state_next <= CHECK_DIM_OUT;
        
        when FINE =>  o_en <= '0';
                      o_we <= '0';
                      o_done <= '1';
                      state_next <= LOW_START_WAIT;
        
        when LOW_START_WAIT => if(i_start = '0')then o_done <= '0';
                                                     state_next<= START;
                                else state_next <= LOW_START_WAIT;
                                end if;

        end case;
    end if;

end process;

end architecture;
            
                