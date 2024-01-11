library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity project_reti_logiche is port (

	i_clk   : in std_logic; 
	i_rst   : in std_logic; 
	i_start : in std_logic; 
	i_w     : in std_logic;

	o_z0    : out std_logic_vector(7 downto 0); 
	o_z1    : out std_logic_vector(7 downto 0); 
	o_z2    : out std_logic_vector(7 downto 0); 
	o_z3    : out std_logic_vector(7 downto 0);
	o_done  : out std_logic;

	o_mem_addr : out std_logic_vector(15 downto 0); 
	i_mem_data : in std_logic_vector(7 downto 0); 
	o_mem_we   : out std_logic;
	o_mem_en   : out std_logic
);

end project_reti_logiche;




ARCHITECTURE Behavioral OF project_reti_logiche IS
	
	--segnali per la macchina a stati finiti
	TYPE states IS (READ_FIRST_BIT, READ_SECOND_BIT, READ_RAM_ADDRESS, ASK_RAM, READ_RAM_DATA, SETUP_O);
	signal curr_state, next_state : states;

	--registri per il salvataggio della uscita sulla quale mandare il segnale
	--codificata con 2 bit: 00 -> Z0; 01 -> Z1; 10 -> Z2; 11 -> Z3	
	signal bit_first 	: std_logic := '0';
	signal bit_second	: std_logic := '0';
	
	--registro per salvare l'indirizzo di memoria da cui prendere il dato da mandare in output 
	signal address : std_logic_vector(15 downto 0) := "0000000000000000";
	
	--registri per il salvataggio e la gestione dell'output
	signal reg_z0 	: std_logic_vector(7 downto 0) := "00000000";
	signal reg_z1	: std_logic_vector(7 downto 0) := "00000000";
	signal reg_z2 	: std_logic_vector(7 downto 0) := "00000000";
	signal reg_z3 	: std_logic_vector(7 downto 0) := "00000000";
	signal data_read: std_logic_vector(7 downto 0) := "00000000";
	
	--registri utili per far partire i processi esterni alla fsm
	signal reg_ready			: std_logic := '0';
	signal leggi_primo_bit 		: std_logic := '0';
	signal leggi_secondo_bit 	: std_logic := '0';
	signal leggi_indirizzo		: std_logic := '0';
	signal leggi_memoria 		: std_logic := '0';
	signal chiedi_memoria 		: std_logic := '0';
	signal esci 				: std_logic := '0';
	signal reset_addr 			: std_logic := '0';
	

begin

	registro_primo_bit_o: process (i_clk, i_rst, leggi_primo_bit)
		--processo per la lettura del primo bit in ingresso, utile per la decisione
		--dell'uscita da utiizzare per trasmettere il valore dato
	begin
		if i_rst='1' then
				--nel caso in cui il segnale di reset sia alto, occorre resettare il valore del primo bit
			bit_first<='0';		
		elsif (i_clk'event) and (i_clk='1') and (leggi_primo_bit ='1') and i_start='1' then
				--nel caso in cui non ci sia reset alto, ma c'è sato un evento i clock e i segnali di start e di lettura del secondo bit sono alti, allora
				--occorre salvare il valore di i_w in bit_first
			if i_w ='1' then
				bit_first <='1';
			else
				bit_first<='0';
			end if ;
		end if;
	end process;


	registro_secondo_bit_o: process (i_clk, i_rst, leggi_secondo_bit)
		--processo per la lettura del secondo bit in ingresso, utile per la decisione
		--dell'uscita da utiizzare per trasmettere il valore dato
	begin
		if i_rst='1' then
				--nel caso in cui il segnale di reset sia alto, occorre resettare il valore del secondo bit
			bit_second<='0';		
		elsif i_clk'event and i_clk='1' and leggi_secondo_bit ='1' and i_start='1' then
				--nel caso in cui non ci sia reset alto, ma c'è sato un evento i clock e i segnali di start e di lettura del secondo bit sono alti, allora
				--occorre salvare il valore di i_w in bit_second
			if i_w ='1' then
				bit_second <='1';
			else
				bit_second<='0';
			end if ;			
		end if;
	end process;


	registro_indirizzo_ram: process (i_clk, i_rst, leggi_indirizzo)
		--processo per la lettura del vettore di indirizzo, utile per la decisione
		--riguardante quale cella di memoria deve fornire il dato in output
	begin
		if i_rst='1' or reset_addr='1' then
				--nel caso in cui il segnale di reset sia alto, allora occorre resettare l'intero valore di address a 0
				--in modo tale che quando, al prossimo ciclo, si debba leggere address nuovamente, i valori salvati precedentemente 
				--non influiscano sul nuovo valore di address
				--Inoltre è necessario resettare il valore di address anche ogni volta che la lettura è stata terminata
			address(15 downto 0) <= (others=>'0');
		elsif i_clk'event and i_clk='1'  then
			if leggi_indirizzo ='1' and i_start ='1' then
					--quando occorre leggere il valore, si effettuano le seguenti operazioni:
					--è necessario uno shift del precedente valore di address, 
					--in cui si mantengono i 15 bit meno significativi (dei 16 iniziali)
					--e si effettui la concatenazione del valore in ingresso sul canale i_w
				if i_w ='1' then
					address(15 downto 0) <= address(14 downto 0) & '1';
				else
					address(15 downto 0) <= address(14 downto 0) & '0';
				end if ;
			end if;
		end if;
	end process;


	invio_indirizzo_memoria: process (i_clk, i_rst, chiedi_memoria)
	begin
		if i_rst='1' then
				--reset del valore
			o_mem_addr <= (others=>'0');
		elsif i_clk'event and i_clk='1' and chiedi_memoria ='1' then
				--trasferire il valore salvato nel registro address su o_mem_addr
				--in modo tale che la memoria sappia da dove prendere il valore da mandare al componente
			o_mem_addr(15 downto 0) <= address(15 downto 0);
		end if;
	end process;


	leggi_dato_dalla_memoria: process (i_clk, i_rst, leggi_memoria)
	begin
		if i_rst='1' then
			data_read <= (others=>'0');
		elsif i_clk'event and i_clk='1' and leggi_memoria ='1' then
			data_read<=i_mem_data;
		end if;
	end process;


	scelta_canale_output: process (i_clk, esci)
		--processo per il salvataggio dei dati negli appositi registri di output
	begin
		if i_rst='1' then
			--reset di tutti i registri di uscita
			reg_z0 <= "00000000";
			reg_z1 <= "00000000";
			reg_z2 <= "00000000";
			reg_z3 <= "00000000";
			reg_ready<='0';
		elsif i_clk'event and i_clk='1' then
			
			if esci ='1' then
				-- è necessario salvare il valore ricevuto dalla memoria nei registri appositi
				--inoltre si porta ad 1 il valore di o_done per notificare la fine delle operazioni e mandare in output il valore effettivo
				o_done<='1';
				reg_ready<='1';
				if(bit_first = '0' and bit_second = '0') then
					--uscita codificata con 00 -> Z0
					reg_z0(7 downto 0) <= i_mem_data(7 downto 0); 
				elsif(bit_first = '0' and bit_second = '1') then
					--uscita codificata con 01 -> Z1
					reg_z1(7 downto 0) <= i_mem_data(7 downto 0); 
				elsif(bit_first = '1' and bit_second = '0') then
					--uscita codificata con 10 -> Z2
					reg_z2(7 downto 0) <= i_mem_data(7 downto 0); 
				elsif(bit_first = '1' and bit_second = '1') then
					--uscita codificata con 11 -> Z3
					reg_z3(7 downto 0) <= i_mem_data(7 downto 0); 
				end if;
			
			elsif esci ='0' then 
				--si riporta a 0 il valore di done e si notifica al processo di uscita 
				--che è necessario riportare a 0 tutte le uscite in modo da farle corrispondere alle specifiche richieste
				o_done <= '0';
				reg_ready<='0';
			end if;
		
		end if;
	end process;


    z_out: process (reg_ready)
    --processo che si attiva nel momento in cui tutti i segnali sono pronti (nello stesso momento in cui done è 1)
    --Manda in input i segnali sulle giuste uscite, oppure soli '0' nel caso in cui non ci sia done = '1' 
    begin
	    if (reg_ready='1') then
	    	o_z0<=reg_z0;
		   	o_z1<=reg_z1;
		   	o_z2<=reg_z2;
		   	o_z3<=reg_z3;
		else 
	    	o_z0<=(others=>'0');
		   	o_z1<=(others=>'0');
		  	o_z2<=(others=>'0');
			o_z3<=(others=>'0');
		end if;
    end process;


	aggiorna_stato_fsm: process(i_clk, i_rst)
	--processo per aggiornare il valore di curr_state e portare lo stato della FSM
	--a quello salvato in next_state
    begin
        if(i_rst = '1') then
        --nel caso di un reset, si torna allo stato iniziale: READ_FIRST_BIT
            curr_state <= READ_FIRST_BIT;
        elsif rising_edge(i_clk) then
        --altrimenti si passa allo stato successivo, salvato in next_state
            curr_state <= next_state;
        end if;
    end process; 



	fsm_states: process (curr_state, i_start)
	begin
		case curr_state is

			when READ_FIRST_BIT =>
			    if(i_start = '1') then
					next_state <= READ_SECOND_BIT;
				elsif (i_start = '0') then
					next_state <= READ_FIRST_BIT;
				end if;

			when READ_SECOND_BIT =>
				if(i_start = '1') then
					next_state <= READ_RAM_ADDRESS;
				elsif (i_start = '0') then
					next_state <= ASK_RAM;
				end if;

			when READ_RAM_ADDRESS =>
				if(i_start = '1') then
					next_state <= READ_RAM_ADDRESS;
				elsif (i_start = '0') then
					next_state <= ASK_RAM;
				end if;

			when ASK_RAM =>
			     next_state <= READ_RAM_DATA;

			when READ_RAM_DATA =>
			     next_state <= SETUP_O;

			when SETUP_O =>
				next_state <= READ_FIRST_BIT;
		end case;
	end process;


	fsm_signals: process (curr_state)
	begin	
		o_mem_en <= '0'; 
		o_mem_we <= '0';
		leggi_primo_bit<='0';
		leggi_secondo_bit<='0';
		leggi_indirizzo<='0';
		leggi_memoria<='0';
		chiedi_memoria<='0';
		esci<='0';
		reset_addr<='0';

		case curr_state is
			when READ_FIRST_BIT =>
				esci<='0';
				o_mem_en<='0';
				o_mem_we<='0';
				leggi_primo_bit<='1';

			when READ_SECOND_BIT =>
				leggi_primo_bit<='0';
				leggi_secondo_bit<='1';

			when READ_RAM_ADDRESS =>
				leggi_secondo_bit<='0';
				leggi_indirizzo<='1';

			when ASK_RAM =>
				leggi_indirizzo<='0';
				chiedi_memoria<='1';

			when READ_RAM_DATA =>
				chiedi_memoria<='0';
				leggi_memoria<='1';
				o_mem_en <='1';
				reset_addr<='1';

			when SETUP_O => 
				leggi_memoria<='1';
				esci<='1';
				o_mem_en<='0';
				reset_addr<='0';
		end case;
	end process;

END Behavioral;