-- A395D_dispatcher.vhd
-- -----------------------------------------------------------------------
-- A395D dispatcher 
-- -----------------------------------------------------------------------
--  Date        : 08/06/2016
--  Contact     : support.nuclear@caen.it
-- (c) CAEN SpA - http://www.caen.it   
-- -----------------------------------------------------------------------
library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;
       
entity A395D_Dispatcher is
  port(  
    dau_bus  : inout std_logic_vector(31 downto 0);   
    dau_moth : out   std_logic_vector(7 downto 0); 
    moth_dau : in    std_logic_vector(7 downto 0)
  );
end A395D_Dispatcher;
   
architecture arch of A395D_dispatcher is
   
  type t_io_mapping is array (0 to 7) of integer range 0 to 31;
  
  signal in_map   : t_io_mapping := (2,18,3,19,14,30,15,31);
  signal out_map  : t_io_mapping := (0,16,1,17,12,28,13,29);
    
begin
  
  dau_bus <= (others => 'Z'); -- Three-state if not used
  
  -- ---------------------------------------
  -- A395D Input mode
  -- ------------------------------------------
  -- Map mezzanine physical signals to check
  -- eight possible external I/O LEMO status.
  G_INPUT_MAPPING: for i in 0 to 7 generate
    dau_moth(i) <= dau_bus(in_map(i)); 
  end generate G_INPUT_MAPPING;
    
  -- ------------------------------------------
  -- A395D Output mode
  -- ------------------------------------------
  -- Map mezzanine physical signals to control
  -- eight available I/O LEMO according to 
  -- user provided values.
  G_OUTPUT_MAPPING: for i in 0 to 7 generate
    dau_bus(out_map(i)) <= moth_dau(i);
  end generate G_OUTPUT_MAPPING;
       
end architecture;
     
     