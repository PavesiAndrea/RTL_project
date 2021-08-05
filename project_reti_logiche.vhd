-- Politecnico di Milano
-- Pavesi Andrea, Radaelli Marta 
-- Codice Persona 10659804, 10657046 
-- Prova finale di reti logiche 2020-2021
-- Docente Palermo Gianluca
---------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
port (
--input signals
    i_clk : in STD_LOGIC; --segnale di clock in ingresso generato dal test bench
    i_rst : in STD_LOGIC; --segnale di reset che inizializza
    i_start : in STD_LOGIC; --segnale di start generato dal test bench
    i_data : in STD_LOGIC_VECTOR (7 downto 0); --vettore che arriva dalla memoria in seguito ad una richiesta di lettura
--output signals 
    o_address : out STD_LOGIC_VECTOR (15 downto 0); --segnale di uscita che manda l'indirizzo alla memoria 
    o_done : out STD_LOGIC; --segnale di uscita che comunica la fine dell'elaborazione 
    o_en : out STD_LOGIC; --segnale di enable da dover mandare alla memoria per comunicare
    o_we : out STD_LOGIC; --segnale di write enable, =0 in lettura, =1 in scrittura
    o_data : out STD_LOGIC_VECTOR (7 downto 0)); --segnale di uscita del componente verso la memoria 
end entity;

architecture Behavior of project_reti_logiche is

--stati della macchina
type state_type is (START, --stato iniziale
                    IN_READ, --stato per operazioni in preparazione alla lettura e indirizzarla a seconda che il primo ciclo di analisi 
                             --sulla memoria sia stata eseguita o meno
                    GET_ROW_WAIT, --stato per la memorizzazione dell'elemento nell'indirizzo zero
                    CHECK_DIM_IN, --stato per check sul numero di elementi letti
                    CHECK_MIN_MAX,  --stato per l'aggiornamento progressivo di massimo e minimo
                    CHECK_DIM_OUT, --stato per check su secondo ciclo di lettura e conseguente scrittura in memoria 
                    NEW_VALUE, --stato per il calcolo del nuovo valore del pixel e per check su valore calcolato: se >255 deve essere settato a 255  
                    WRITE, --stato per la scrittura del valore in memoria
                    DONE  --stato di fine 
                    );

--segnali
signal state_curr : state_type; --stato corrente

signal MAX_PIXEL_VALUE: unsigned(7 downto 0) := (others => '0'); --setto a 0 il valore max in modo che nel primo ciclo venga subito sostituito
signal MIN_PIXEL_VALUE: unsigned(7 downto 0) := (others => '1'); --setto a 255 il valore min in modo che nel primo ciclo venga subito sostituito
--booleano usato per check su prima lettura, passa a true quando sono stati passati tutti i pixel 
--in modo tale da poter entrare nella seconda parte dello svolgimento, ossia la modifica e scrittura in memoria
signal reading_done : boolean := false;

--funzione usata per calcolare lo shift level analizzando il vettore in ingresso
--return della funzione tiene conto della seguente operazione:
--8-floor(log2(max_value-min_value+1))
function shift_level_funct ( number : unsigned(7 downto 0)) return integer is
    begin 
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


begin

    process(i_clk,i_rst) 
    
    --variabili
    variable int_res: integer; --contiene il numero di pixel da leggere (colonna * riga)
    variable counter : integer;  --contatore usato per sapere quabnti valori sono già stati letti da memoria 
    variable int1: integer; --variabile locale generica per salvare valori numerici
    variable var: unsigned(7 downto 0) := (others => '0'); --usato per la conversione al momento dello shift
    variable new_pixel_value : std_logic_vector(15 downto 0):= (others => '0'); --valore vettoriale del pixel che sarà scritto in memoria
   
    begin
        if(i_rst = '1')then --nel caso arrivi un segnale di reset, riporta allo stato iniziale con conseguente reset delle variabili
                state_curr <= START;
        
        else if (rising_edge(i_clk)) then --altrimenti passaggio normale allo stato successivo
                    case state_curr is
        --definizione degli stati
            when START => 
                            counter := 2; 
                            o_done <= '0'; --abbasso segnale di done
                            o_en <= '1'; --permette la lettura in memoria 
                            o_we <= '0';
                            reading_done <= false;
                            o_address <= "0000000000000000";
                            if i_start = '1' then state_curr <= GET_ROW_WAIT;
                            else state_curr <= START;
                            end if;
            
            when GET_ROW_WAIT => 
                                 int1 := to_integer(unsigned(i_data));
                                 o_address <= "0000000000000001";   
                                 state_curr <= CHECK_DIM_IN;
           
            when CHECK_DIM_IN => 
                                 if (not reading_done and counter = 2) then int_res := int1*(to_integer(unsigned(i_data))); --numero di pixel presenti da modificare 
                                                                              if(int_res = 0) then state_curr <= DONE;
                                                                              else state_curr <= CHECK_DIM_IN;
                                                                              end if;
                                 end if;                                             
                                 if(counter < int_res+2) then o_address <= std_logic_vector(to_unsigned(counter,16));  
                                                              state_curr <= IN_READ;
                                 else reading_done <= true;
                                      counter := 2;
                                      state_curr <= CHECK_DIM_OUT;
                                 end if;
                                
            when IN_READ => 
                            counter := counter +1;
                            if (reading_done) then state_curr <= NEW_VALUE;
                            else state_curr <= CHECK_MIN_MAX;
                            end if;
                            
            when CHECK_MIN_MAX =>               
                              if(MIN_PIXEL_VALUE > unsigned(i_data)) then MIN_PIXEL_VALUE <= unsigned(i_data);
                               end if;                              
                              if (MAX_PIXEL_VALUE < unsigned(i_data)) then MAX_PIXEL_VALUE <= unsigned(i_data);  
                              end if;
                              state_curr <= CHECK_DIM_IN;       
                             
            when CHECK_DIM_OUT => 
                                    if(counter < int_res+2) then o_address <= std_logic_vector(to_unsigned(counter,16)); 
                                                                 o_we <= '0'; 
                                                                 state_curr <= IN_READ;
                                    else o_done <= '1';
                                         state_curr <= DONE;
                                    end if;
            
            when NEW_VALUE =>   
                            int1 := shift_level_funct(MAX_PIXEL_VALUE - MIN_PIXEL_VALUE + 1);
                            var := unsigned(i_data) - MIN_PIXEL_VALUE;
                            new_pixel_value := std_logic_vector(shift_left(resize(var,16),int1));
                        
                            if(to_integer(unsigned(new_pixel_value)) > 255) then new_pixel_value := std_logic_vector(to_unsigned(255,16));
                            end if;
                            o_address <= std_logic_vector(to_unsigned(counter+int_res-1,16));
                            o_we <= '1'; --permette la scritturaa in memoria
                             state_curr <= WRITE;
                              
        when WRITE =>   
                        o_data <= std_logic_vector(resize(unsigned(new_pixel_value), 8));
                         state_curr <= CHECK_DIM_OUT;
                                             
        
        when DONE =>    
                        o_we <= '0'; --disabilito la scrittura
                        o_en <= '0'; --disabilito comunicazione con memoria 
                        o_done <= '1'; --alzo il segnale di done
                        if i_start = '0' then  state_curr <= START; --attendo che start si abbassi per tornare allo stato inizale 
                        else state_curr <= DONE; --altrimenti resto nello stato finale
                        end if;
                                
            end case;
        end if;
        end if;
    end process;
end architecture;