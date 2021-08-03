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

type state_type is (START, IN_READ, IN_READ_WAIT, GET_COL,  GET_ROW,
CHECK_DIM_IN,CHECK_MIN_MAX, CALC_SHIFT,CHECK_DIM_OUT, NEW_VALUE, WRITE, DONE, START_WAIT);

signal state: state_type := START;

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

signal temp_pixel : std_logic_vector(7 downto 0);
signal new_pixel_value : std_logic_vector(7 downto 0);
signal addr: std_logic_vector(15 downto 0);
signal temp_value_vect: std_logic_vector(7 downto 0);


begin

    transistions : process(i_clk) 
    
    variable counter : integer;
    variable wr_counter: integer;
    variable int_res: integer;
    variable row: integer;
    variable column: integer;
    variable shift_level: integer;
    variable data_read : unsigned(7 downto 0);
    
    variable addr: std_logic_vector(15 downto 0);
    
    begin
    
    if rising_edge(i_clk) then  o_en <= '0';
                                o_done <= '0';
                                o_we <= '0';
                                o_data <= (others => '0');
                                o_address <= (others => '0');
    
    if i_rst = '1' then state <= START; 
    
    else case state is
    
        when START => 
                        o_en <= '1';
                        o_we <= '0';
                        counter := 2; 
                        column := 0;
                        row := 0;
                        if i_start = '1' then state <= GET_COL;
                        else state <= START;
                        end if;
        
        when GET_COL =>    
                        o_address <= "0000000000000000";
                        state <= GET_COL;
                        column := to_integer(unsigned(i_data));
                        o_address <= "0000000000000001";   
                        report "colonna:" & integer'image(column);
                        state <= GET_ROW;
       
        when GET_ROW =>  
                        row := to_integer(unsigned(i_data));
                        report "riga:" & integer'image(row);
                        int_res := row*column; --numero di pixel presenti da modificare 
                        report "int res" & integer'image(int_res);
                        if(int_res = 0) then state <= DONE;
                        else state <= IN_READ_WAIT;
                        end if;
                            
        when CHECK_DIM_IN => 
                             if(counter < int_res+2) then state <= IN_READ_WAIT;
                             else state <= CALC_SHIFT;
                             end if;
                            
        when IN_READ_WAIT =>    
                                addr := std_logic_vector(to_unsigned(counter,16));
                                o_address <= addr;
                                state <= IN_READ;                        
                        
        when IN_READ => 
                        data_read := unsigned(i_data);
                        report "counter:" &integer'image(counter); 
                        report "indirizzo letto:" &integer'image(to_integer(unsigned(addr)));
                        report "letto:" &integer'image(TO_INTEGER(unsigned(data_read)));   
                        counter := counter +1;
                        state <= CHECK_DIM_IN;
                        
        when CHECK_MIN_MAX =>                
                                if(MIN_PIXEL_VALUE > data_read) then MIN_PIXEL_VALUE <= data_read;
                                elsif (MAX_PIXEL_VALUE < data_read) then MAX_PIXEL_VALUE <= data_read;
                                end if;
                                counter := counter + 1;
                                report "letto:" &integer'image(TO_INTEGER(unsigned(data_read)));
                                report "min:" &integer'image(TO_INTEGER(unsigned(MIN_PIXEL_VALUE)));
                                report "max:" &integer'image(TO_INTEGER(unsigned(MAX_PIXEL_VALUE)));
                                state <= CHECK_DIM_IN;
                        
                          
                            
        when CALC_SHIFT => 
                            shift_level := shift_level_funct(MAX_PIXEL_VALUE - MIN_PIXEL_VALUE + 1);
                            wr_counter := counter; --primo indirizzo di scrittura puntato dal contatore
                            counter := 2; --riparte dall'inizio per ciclare nuovamente su tutti i valori
                            state <= CHECK_DIM_OUT;   
                            
        when CHECK_DIM_OUT => 
                                if(counter < int_res) then state <= NEW_VALUE;
                                else state <= DONE;
                                end if;
        
        when NEW_VALUE =>
                            o_en <= '1';
                            o_we <= '1';
                            o_address <= std_logic_vector(to_unsigned(counter,16));
                            temp_value_vect <= std_logic_vector(unsigned(i_data) - MIN_PIXEL_VALUE);
                            temp_pixel <= std_logic_vector(shift_left(unsigned(temp_value_vect), shift_level));
                            if(temp_pixel < "11111111") then new_pixel_value <= temp_pixel;
                            else new_pixel_value <= "11111111";
                            end if;
                            state <= WRITE;
                              
        when WRITE => 
                        o_en <= '1';
                        o_we <= '1';
                        o_address <= std_logic_vector(to_unsigned(wr_counter,16));
                        o_data <= new_pixel_value;
                        counter := counter +1;
                        wr_counter := wr_counter + 1;
                        state <= CHECK_DIM_OUT;
                                             
        
        when DONE => 
                        o_en <= '0';
                        o_we <= '0';
                        o_done <= '1';
                        state <= START_WAIT;
        
        when START_WAIT => 
                            if(i_start = '0')then state <= START;
                            else state <= START_WAIT;
                            end if;
                            
        end case;
    end if;
    end if;
end process;
end architecture;