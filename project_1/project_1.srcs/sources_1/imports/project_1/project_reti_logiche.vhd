library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
port (
--input signals
    i_clk : in STD_LOGIC;
    i_rst : in STD_LOGIC;
    i_start : in STD_LOGIC;
    i_data : in STD_LOGIC_VECTOR (7 downto 0);
--output signals 
    o_address : out STD_LOGIC_VECTOR (15 downto 0);
    o_done : out STD_LOGIC;
    o_en : out STD_LOGIC;
    o_we : out STD_LOGIC;
    o_data : out STD_LOGIC_VECTOR (7 downto 0));
end entity;

architecture Behavior of project_reti_logiche is

type state_type is (START, IN_READ, IN_READ_WAIT, GET_COL,  GET_COL_WAIT, GET_ROW, GET_ROW_WAIT,
CHECK_DIM_IN,CHECK_MIN_MAX,CALC_SHIFT,CHECK_DIM_OUT, NEW_VALUE, WRITE, DONE, START_WAIT);

signal state_next : state_type;
signal state_curr : state_type;

signal MAX_PIXEL_VALUE: unsigned(7 downto 0) := (others => '0'); --setto a 0 il valore max in modo che nel primo ciclo venga subito sostituito
signal MIN_PIXEL_VALUE: unsigned(7 downto 0) := (others => '1'); --setto a 255 il valore min in modo che nel primo ciclo venga subito sostituito

function shift_level_funct ( number : unsigned(7 downto 0)) return integer is
    begin 
    --funzione usata per calcolare il log2(x+1)
    if number(7) = '1' then return 1;
    elsif number(6) = '1'then return 2;
    elsif number(5) = '1'then return 3;
    elsif number(4) = '1'then return 4;
    elsif number(3) = '1'then return 5;
    elsif number(2) = '1'then return 6;
    elsif number(1) = '1'then return 7;
    else return 0;
    end if;
end function;

signal reading_done : boolean := false;
signal temp_pixel : std_logic_vector(7 downto 0);
signal new_pixel_value : std_logic_vector(7 downto 0);
signal addr: std_logic_vector(15 downto 0);
signal temp_value_vect: std_logic_vector(7 downto 0);


begin

    process(i_clk) 
    
    variable counter : integer;
    variable wr_counter: integer;
    variable int_res: integer;
    variable row: integer;
    variable column: integer;
    variable shift_level: integer;
    variable data_read : unsigned(7 downto 0);
    
    variable addr: std_logic_vector(15 downto 0);
    
    begin
    
    if(i_clk'event and i_clk = '1')then
        if(i_rst = '1')then
            state_curr <= START;
        else
            state_curr <= state_next;
        end if;
    
    
    else case state_curr is
    
        when START => 
                        counter := 2; 
                        column := 0;
                        row := 0;
                        reading_done <= false;
                        if i_start = '1' then state_next <= GET_COL_WAIT;
                        else state_next <= START;
                        end if;
        
        when GET_COL_WAIT => o_en <= '1';
                             o_we <= '0';
                             o_address <= "0000000000000000";
                             --state_next <= GET_COL;
                             --report "colonna:" & integer'image(column);
                             state_next <= GET_COL;
       
        when GET_COL =>  column := to_integer(unsigned(i_data));
                         state_next <= GET_ROW_WAIT;
           
        when GET_ROW_WAIT => o_en <= '1';
                             o_we <= '0';
                             o_address <= "0000000000000001";   
                             state_next <= GET_ROW;
                    
        when GET_ROW =>  
                        row := to_integer(unsigned(i_data));
                        --report "riga:" & integer'image(row);
                        int_res := row*column; --numero di pixel presenti da modificare 
                        --report "int res" & integer'image(int_res);
                        if(int_res = 0) then state_next <= DONE;
                        else state_next <= IN_READ_WAIT;
                        end if;
                            
        when CHECK_DIM_IN => 
                             if(counter < int_res+2) then state_next <= IN_READ_WAIT;
                             else reading_done <= true;
                                  state_next <= CALC_SHIFT;
                             end if;
                            
        when IN_READ_WAIT => o_en <= '1';
                             o_we <= '0'; 
                             o_address <= std_logic_vector(to_unsigned(counter,16)); 
                             state_next <= IN_READ;                        
                        
        when IN_READ => 
                        data_read := unsigned(i_data);
                        --report "counter:" &integer'image(counter); 
                        --report "indirizzo letto:" &integer'image(to_integer(unsigned(addr)));
                        --report "letto:" &integer'image(TO_INTEGER(unsigned(data_read)));   
                        counter := counter +1;
                        if (reading_done) then state_next <= NEW_VALUE;
                        else state_next <= CHECK_MIN_MAX;
                        end if;
                        
        when CHECK_MIN_MAX =>               
                          if(MIN_PIXEL_VALUE > data_read) then MIN_PIXEL_VALUE <= data_read;
                          --report "min:" &integer'image(TO_INTEGER(unsigned(MIN_PIXEL_VALUE)));
                           end if;                              
                          if (MAX_PIXEL_VALUE < data_read) then MAX_PIXEL_VALUE <= data_read;  
                          --report "max:" &integer'image(TO_INTEGER(unsigned(MAX_PIXEL_VALUE)));
                          end if;
                          state_next <= CHECK_DIM_IN;       
                         --else state_next <= CHECK_MAX;
                          
                            
        when CALC_SHIFT => 
                            shift_level := shift_level_funct(MAX_PIXEL_VALUE - MIN_PIXEL_VALUE + 1);
                            wr_counter := int_res; --primo indirizzo di scrittura puntato dal contatore
                            counter := 2; --riparte dall'inizio per ciclare nuovamente su tutti i valori
                            state_next <= CHECK_DIM_OUT;   
                            
        when CHECK_DIM_OUT => 
                                if(counter < int_res) then state_next <= IN_READ_WAIT;
                                else state_next <= DONE;
                                end if;
        
        when NEW_VALUE =>
                            temp_value_vect <= std_logic_vector(unsigned(data_read) - MIN_PIXEL_VALUE);
                            temp_pixel <= std_logic_vector(shift_left(unsigned(temp_value_vect), shift_level));
                            if(temp_pixel < "11111111") then new_pixel_value <= temp_pixel;
                            else new_pixel_value <= "11111111";
                            end if;
                            state_next <= WRITE;
                              
        when WRITE => 
                        o_en <= '1';
                        o_we <= '1';
                        o_address <= std_logic_vector(to_unsigned(wr_counter,16));
                        o_data <= new_pixel_value;
                        counter := counter +1;
                        wr_counter := wr_counter + 1;
                        state_next <= CHECK_DIM_OUT;
                                             
        
        when DONE => 
                        o_done <= '1';
                        state_next <= START_WAIT;
        
        when START_WAIT => 
                            if(i_start = '0')then state_next <= START;
                            else state_next <= START_WAIT;
                            end if;
                            
        end case;
    end if;
end process;
end architecture;