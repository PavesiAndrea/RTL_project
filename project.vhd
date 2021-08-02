  
----------------------------------------------------------------------------------
-- Company
-- Engineer: 
-- 
-- Create Date: 24.04.2021 11:40:10
-- Design Name: 
-- Module Name: project_reti_logiche - entity
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


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


    type state is (START_WAIT, IN_READ, RESET, GET_DIM, 
            CHECK_DIM_IN, CHECK_MIN, CHECK_MAX, CALC_DV, CALC_SHIFT,CHECK_DIM_OUT, NEW_VALUE, FINE, LOW_START_WAIT);

    signal state_next: state;
    signal state_curr: state;
    signal delta_value : integer;
    signal shift_value : integer;
    signal temp_pixel : std_logic_vector(7 downto 0);
    signal new_pixel_value : std_logic_vector(7 downto 0);
    signal matrix: STD_LOGIC_VECTOR(natural downto 0);
    signal counter: integer;
    signal int_res: integer;
    signal row: std_logic_vector(7 downto 0);
    signal column: std_logic_vector(7 downto 0);
    signal next_addr: std_logic_vector(15 downto 0);
    signal min: integer;
    signal max: integer;
    signal data: integer;
    signal temp_value: std_logic_vector(7 downto 0);

begin

    state_reg_update: process(i_clk)
    begin
    if(i_clk'event and i_clk = '1') then 
        if(i_rst = '1') then state_curr<=START_WAIT;
        else state_curr<=state_next;
        end if;
    
    case state_curr is
        when START_WAIT => temp_pixel <= "00000000";
                           delta_value <= 0;
                           shift_value <= 0;
                           new_pixel_value <= "00000000";
                           counter <= 0;
                           row <= "00000000";
                           column <= "00000000";
                           o_done <= '0';
                           if(i_start = '1') then state_next <= GET_DIM;
                           else state_next <= START_WAIT;
                           end if;
                           
        when GET_DIM => o_en <= '1';
                        o_we <= '0';
                        o_address <= "0000000000000000";  
                        column <= i_data;
                        o_address <= "0000000000010001";  
                        row <= i_data;
                        int_res <= (to_integer(unsigned(row)))*(to_integer(unsigned(column)));              
                        state_next <= CHECK_DIM_IN;       
                     
        when CHECK_DIM_IN => if(counter<int_res) then state_next<= IN_READ;
                          else state_next<= CALC_DV;  
                          end if;
                          
        when IN_READ => o_en <= '1';
                        o_we <= '0';
                        counter <= counter + 1;
                        next_addr <= std_logic_vector(TO_UNSIGNED(17*(counter +1),16));
                        o_address <= next_addr;
                        if(counter = 1) then min <= (to_integer(unsigned(i_data)));
                                             max <= min;
                                             state_next <= CHECK_DIM_IN;
                        else data <= (TO_INTEGER(unsigned(i_data)));
                             
                             state_next <= CHECK_MIN;                                    
                        end if;
                                  
        when CHECK_MIN => if(data < min) then min <= data;
                                              state_next <= CHECK_DIM_IN;
                          else state_next <= CHECK_MAX;
                          end if;   
                          
        when CHECK_MAX => if(data > max) then max <= data;
                          end if;                                       
                          state_next <= CHECK_DIM_IN;
                          
        when CALC_DV => counter <= 0;
                        delta_value <= (max - min);
                        state_next <= CALC_SHIFT;
                              
        when CALC_SHIFT => delta_value <= delta_value + 1;
                            shift_value <= 8;
                            while delta_value > 1 loop
                                delta_value <= delta_value/2;
                                shift_value <= shift_value - 1;
                                end loop;
                             state_next <= CHECK_DIM_OUT;                                                    
          
         when CHECK_DIM_OUT => if(counter < int_res) then state_next <= NEW_VALUE;
                                else state_next <= FINE;  
                                end if;                                    

         when NEW_VALUE => o_en <= '1';
                           o_we <= '1';
                           counter <= counter + 1;
                           next_addr <= std_logic_vector(TO_UNSIGNED(17*(counter +1),16));
                           o_address <= next_addr;
                           temp_value <= i_data;
                           temp_value <= std_logic_vector(to_unsigned((to_integer(unsigned(temp_value))) - min,7));
                           temp_pixel <= std_logic_vector(shift_left(unsigned(temp_value), shift_value));
                           next_addr <= std_logic_vector(TO_UNSIGNED(17*(counter +1 +int_res),16));
                           o_address <= next_addr;
                           if((to_integer(unsigned(temp_pixel))) < 255) then new_pixel_value <= temp_pixel;
                           else new_pixel_value <= "11111111";
                           end if;
                           o_data <= new_pixel_value;
                           state_next <= CHECK_DIM_OUT;
                           
                       
        when FINE => o_done <= '1';
                     state_next <= LOW_START_WAIT;
                     
                 
        when LOW_START_WAIT => if(i_start = '0') then state_next<= START_WAIT;
                               else state_next <= LOW_START_WAIT;
                               end if;
                               
                           
    end case;                                                
    
  end if;
                                                    
                                                       
 end process;
    

end Behavioral;           
            
                