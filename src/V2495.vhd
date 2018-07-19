-- V2495.vhd
-- -----------------------------------------------------------------------
-- V2495 Demo for A395D mezzanines (top level)
-- -----------------------------------------------------------------------
--  Date        : 21/06/2017
--  Contact     : support.nuclear@caen.it
-- (c) CAEN SpA - http://www.caen.it   
-- -----------------------------------------------------------------------
-- 
--  This demo code demonstrates the use of CAEN A395D mezaanine cards.
--  This demo code assumes that three CAEN A395D mezzanine cards are plugged
--  in each of the three expansion slot available on the CAEN V2495 module.
--                   
--  The demo as the following configuration:
--    * A395D plugged into D expansion slot is used as eight OUPUTS ports ONLY.
--    * A395D plugged into E expansion slot is used as eight INPUTS ports ONLY.
--    * A395D plugged into F expansion slot is used as eight BIDIRECTIONAL ports.
--
--  Other V2495 ports and feature are not used in this demo.
--
--  This code demonstrates the usage of a VHDL component (A395D_Dispatcher):
--  It maps user eight possible control signal (Outputs) or eight status signals
--  (inputs) to the mezzanine expansion slot data bus, according to 
--  Tab. 10.5: A395D mapping in UM5175 – V2495/VX2495 User Manual rev. 0.
-- 
--  User can get the status of A395D inputs on ports E and F by reading at VME
--  register offset 0x1000 and 0x1004 respectively.
--
--  User can set A395D outputs on ports D and F by writing at VME
--  register offset 0x1800 and 0x1804 respectively.
--
--  IMPORTANT NOTE
--  ---------------
--  A395D on port F is configure to take advantage of the possibility to use
--  each I/O as both input and output.
--  This possibility has one prerequisite: it MUST be possible to enable the 50 ohm
--  termination on each A395D I/O which is meant to be used as input:
--  In order to use one A395D I/O as input, it must be driver to logical value '0'
--  and its on-board termination must be enabled (see A395D documentation).
--  The A395D I/O which will be used as output, they can have no termination and
--  their state can be sensed via register access.
--
--  EXAMPLE
--  ----------------
--  Goal:
--  A395D plugged in F expansion port.
--  We want to set A395D I/O 0 (A395D_F[0]) as input. A395D_F[7:1] will be used as output.
--  Instructions:
--    - Enable 50-ohm termination on I/O 0
--    - Write 0 to register 0x1804 : bit 0 MUST always be kept to 0 to use I/O 0 
--                                   as input! 
--    - Read register 0x1004: bit0 is the status of A395D[0]   
--    - Write value to register 0x1804 : remember to keep bit 0 always to 0.
--          set other bits to set A395D outputs (only bit 7:1 are significant).                             
--------------------------------------------------------------------------------
-- $Id$ 
--------------------------------------------------------------------------------

library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;

    use work.V2495_pkg.all;

-- ----------------------------------------------
entity V2495 is
-- ----------------------------------------------
    port (

        CLK    : in     std_logic;                         -- System clock 
                                                           -- (50 MHz)

    -- ------------------------------------------------------
    -- Mainboard I/O ports
    -- ------------------------------------------------------   
      -- Port A : 32-bit LVDS/ECL input
         A        : in    std_logic_vector (31 DOWNTO 0);  -- Data bus 
      -- Port B : 32-bit LVDS/ECL input                    
         B        : in    std_logic_vector (31 DOWNTO 0);  -- Data bus
      -- Port C : 32-bit LVDS output                       
         C        : out   std_logic_vector (31 DOWNTO 0);  -- Data bus
      -- Port G : 2 NIM/TTL input/output                   
         GIN      : in    std_logic_vector ( 1 DOWNTO 0);  -- In data
         GOUT     : out   std_logic_vector ( 1 DOWNTO 0);  -- Out data
         SELG     : out   std_logic;                       -- Level select
         nOEG     : out   std_logic;                       -- Output Enable

    -- ------------------------------------------------------
    -- Expansion slots
    -- ------------------------------------------------------                                                                  
      -- PORT D Expansion control signals                  
         IDD      : in    std_logic_vector ( 2 DOWNTO 0);  -- Card ID
         SELD     : out   std_logic;                       -- Level select
         nOED     : out   std_logic;                       -- Output Enable
         D        : inout std_logic_vector (31 DOWNTO 0);  -- Data bus
                                                           
      -- PORT E Expansion control signals                  
         IDE      : in    std_logic_vector ( 2 DOWNTO 0);  -- Card ID
         SELE     : out   std_logic;                       -- Level select
         nOEE     : out   std_logic;                       -- Output Enable
         E        : inout std_logic_vector (31 DOWNTO 0);  -- Data bus
                                                           
      -- PORT F Expansion control signals                  
         IDF      : in    std_logic_vector ( 2 DOWNTO 0);  -- Card ID
         SELF     : out   std_logic;                       -- Level select
         nOEF     : out   std_logic;                       -- Output Enable
         F        : inout std_logic_vector (31 DOWNTO 0);  -- Data bus

    -- ------------------------------------------------------
    -- Gate & Delay
    -- ------------------------------------------------------
      --G&D I/O
        GD_START   : out  std_logic_vector(31 downto 0);   -- Start of G&D
        GD_DELAYED : in   std_logic_vector(31 downto 0);   -- G&D Output
      --G&D SPI bus                                        
        SPI_MISO   : in   std_logic;                       -- SPI data in
        SPI_SCLK   : out  std_logic;                       -- SPI clock
        SPI_CS     : out  std_logic;                       -- SPI chip sel.
        SPI_MOSI   : out  std_logic;                       -- SPI data out
      
    -- ------------------------------------------------------
    -- LED
    -- ------------------------------------------------------
        LED        : out std_logic_vector(7 downto 0);     -- User led    
    
    -- ------------------------------------------------------
    -- Local Bus in/out signals
    -- ------------------------------------------------------
      -- Communication interface
        nLBRES     : in     std_logic;                     -- Bus reset
        nBLAST     : in     std_logic;                     -- Last cycle
        WnR        : in     std_logic;                     -- Read (0)/Write(1)
        nADS       : in     std_logic;                     -- Address strobe
        nREADY     : out    std_logic;                     -- Ready (active low) 
        LAD        : inout  std_logic_vector (15 DOWNTO 0);-- Address/Data bus
      -- Interrupt requests  
        nINT       : out    std_logic                      -- Interrupt request
  );
end V2495;

-- ---------------------------------------------------------------
architecture rtl of V2495 is
-- ---------------------------------------------------------------

    signal mon_regs    : MONITOR_REGS_T;
    signal ctrl_regs   : CONTROL_REGS_T;

    -- Gate & Delay control bus signals
    signal gd_write     :  std_logic;
    signal gd_read      :  std_logic;
    signal gd_ready     :  std_logic;
    signal reset        :  std_logic;
    signal gd_data_wr   :  std_logic_vector(31 downto 0);
    signal gd_data_rd   :  std_logic_vector(31 downto 0);
    signal gd_command   :  std_logic_vector(15 downto 0);

    -- A395D drivers and sensing signals
    signal A395D_D_control : std_logic_vector(7 downto 0);
    signal A395D_E_status  : std_logic_vector(7 downto 0);
    signal A395D_F_control : std_logic_vector(7 downto 0);
    signal A395D_F_status  : std_logic_vector(7 downto 0);
    
-----\
begin --
-----/

    -- Register mapping
    -- ----------------------------------------------------
    mon_regs(0) <= X"000000" & A395D_E_status;   -- 0x1000 (read only)
    mon_regs(1) <= X"000000" & A395D_F_status;   -- 0x1004 (read only)

    A395D_D_Control <= ctrl_regs(0)(7 downto 0); -- 0x1800 (read/write)
    A395D_F_control <= ctrl_regs(1)(7 downto 0); -- 0x1804 (read/write)
    
    
    -- Unused output ports are explicitally set to HiZ
    -- ----------------------------------------------------
    GD_START <= (others => 'Z');
    GOUT <= (others => 'Z');

    -- D EXPANSION PORT
    -- All eight A395D port used as OUTPUTS
    SELD <= 'Z';
    nOED <= '0';

    I_A395D_ON_PORT_D : entity work.A395D_Dispatcher 
    port map (  
      dau_bus  => D,   
      dau_moth => open, -- unused  
      moth_dau => A395D_D_control
    );
    
    -- E EXPANSION PORT
    -- All eight A395D port used as INPUTS
    SELE <= 'Z';
    nOEE <= '1';
    
    I_A395D_ON_PORT_E : entity work.A395D_Dispatcher 
    port map (  
      dau_bus  => E,   
      dau_moth => A395D_E_status,
      moth_dau => X"00" -- not significant
    );
    
    -- F EXPANSION PORT
    -- A395D ports used as BOTH INPUTS AND OUTPUTS.
    -- Based on the "recessive" state of A395D output stage: 
    --  - Activate 50ohm termination on all bidirectional I/O 
    --  - Drive all outputs to '0' logical value
    SELF <= 'Z';
    nOEF <= '0';
    
    I_A395D_ON_PORT_F : entity work.A395D_Dispatcher 
    port map (  
      dau_bus  => F,   
      dau_moth => A395D_F_status, 
      moth_dau => A395D_F_control
    );
    
    -- Local bus Interrupt request
    nINT <= '1';
    
    -- User Led driver
    LED <= (others => 'Z');
    
    -- Internal reset (active high)
    reset <= not(nLBRES);
           
    -- --------------------------
    --  Local Bus slave interface
    -- --------------------------  
    I_LBUS_INTERFACE: entity work.lb_int  
        port map (
            clk         => CLK,   
            reset       => reset,
            -- Local Bus            
            nBLAST      => nBLAST,   
            WnR         => WnR,      
            nADS        => nADS,     
            nREADY      => nREADY,   
            LAD         => LAD,
            -- Register interface  
            ctrl_regs   => ctrl_regs,
            mon_regs    => mon_regs,      
            -- Gate and Delay controls
            gd_data_wr  => gd_data_wr,       
            gd_data_rd  => gd_data_rd,         
            gd_command  => gd_command,
            gd_write    => gd_write,
            gd_read     => gd_read,
            gd_ready    => gd_ready
        );
        
    -- --------------------------
    --  Gate and Delay controller
    -- --------------------------  
    I_GD: entity  work.gd_control
        port map  (
            reset       => reset,
            clk         => clk,                
            -- Programming interface
            write       => gd_write,
            read        => gd_read,
            writedata   => gd_data_wr,
            command     => gd_command,
            ready       => gd_ready,
            readdata    => gd_data_rd,  
            -- Gate&Delay control interface (SPI)        
            spi_sclk    => spi_sclk,
            spi_cs      => spi_cs,  
            spi_mosi    => spi_mosi,
            spi_miso    => spi_miso    
        );

end rtl;
   