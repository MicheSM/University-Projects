library ieee;
  use ieee.std_logic_1164.all;

entity MSM_wrapper is
  port (
    clk   : in  std_logic;                      -- System clock
    reset : in  std_logic;                      -- Asynchronous reset, active high
    FCW   : in  std_logic_vector(15 downto 0);  -- Frequency Control Word
    PCW   : in  std_logic_vector(15 downto 0);  -- Phase Control Word
    ACW   : in  std_logic_vector(3 downto 0);   -- Amplitude Control Word
    y     : out std_logic_vector(15 downto 0)   -- Output waveform (16-bit signed)
  );
end entity;

architecture struct of MSM_wrapper is

  -- inputs
  signal FCW_reg : std_logic_vector(15 downto 0);
  signal PCW_reg : std_logic_vector(15 downto 0);
  signal ACW_reg : std_logic_vector(3 downto 0);
  -- output
  signal y_core  : std_logic_vector(15 downto 0);

  ---------------------------------------------------------------------------
  -- Components
  ---------------------------------------------------------------------------

  -- Registers
  component DFF_N is
    generic (
      N : natural := 8
    );
    port (
      clk     : in  std_logic;
      a_rst_h : in  std_logic;
      en      : in  std_logic;
      d       : in  std_logic_vector(N - 1 downto 0);
      q       : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  -- DUT
  component MSM is
    port (
      clk   : in  std_logic;
      reset : in  std_logic;
      FCW   : in  std_logic_vector(15 downto 0);
      PCW   : in  std_logic_vector(15 downto 0);
      ACW   : in  std_logic_vector(3 downto 0);
      y     : out std_logic_vector(15 downto 0)
    );
  end component;

begin

  ---------------------------------------------------------------------------
  -- Input Register Barrier
  ---------------------------------------------------------------------------
  FCW_INPUT_REG: DFF_N
    generic map (N => 16)
    port map (
      clk     => clk,
      a_rst_h => reset,
      en      => '1',
      d       => FCW,
      q       => FCW_reg
    );

  PCW_INPUT_REG: DFF_N
    generic map (N => 16)
    port map (
      clk     => clk,
      a_rst_h => reset,
      en      => '1',
      d       => PCW,
      q       => PCW_reg
    );

  ACW_INPUT_REG: DFF_N
    generic map (N => 4)
    port map (
      clk     => clk,
      a_rst_h => reset,
      en      => '1',
      d       => ACW,
      q       => ACW_reg
    );

  ---------------------------------------------------------------------------
  -- DUT instance
  ---------------------------------------------------------------------------
  MSM_CORE: MSM
    port map (
      clk   => clk,
      reset => reset,
      FCW   => FCW_reg,
      PCW   => PCW_reg,
      ACW   => ACW_reg,
      y     => y_core
    );

  ---------------------------------------------------------------------------
  -- Output Register Barrier
  ---------------------------------------------------------------------------
  Y_OUTPUT_REG: DFF_N
    generic map (N => 16)
    port map (
      clk     => clk,
      a_rst_h => reset,
      en      => '1',
      d       => y_core,
      q       => y
    );

end architecture;