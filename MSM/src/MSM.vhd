library ieee;
  use ieee.std_logic_1164.all;

entity MSM is
  port (
    clk   : in  std_logic;
    reset : in  std_logic;                      -- async active-high
    FCW   : in  std_logic_vector(15 downto 0);  -- Frequency Control Word
    PCW   : in  std_logic_vector(15 downto 0);  -- Phase Control Word
    ACW   : in  std_logic_vector(3 downto 0);   -- Amplitude Control Word
    y     : out std_logic_vector(15 downto 0)   -- signed output
  );
end entity;

architecture struct of MSM is

  -- Phase accumulator output
  signal phase_acc_out : std_logic_vector(15 downto 0);

  -- Phase adder output
  signal phase_total : std_logic_vector(15 downto 0);

  -- LUT address (7 bits from phase_total)
  signal lut_address : std_logic_vector(6 downto 0);

  -- LUT output (11-bit unsigned sine amplitude)
  signal lut_output : std_logic_vector(10 downto 0);

  -- Pipeline register input/output: sign_bit & lut_output (12 bits)
  signal pipe_in  : std_logic_vector(11 downto 0);
  signal pipe_out : std_logic_vector(11 downto 0);

  -- Pipeline register output split
  signal sign_bit_reg   : std_logic;
  signal lut_output_reg : std_logic_vector(10 downto 0);

  -- Multiplier product (unsigned 15-bit)
  signal mult_product : std_logic_vector(14 downto 0);

  -- Signed output before zero-force
  signal y_signed : std_logic_vector(15 downto 0);

  ---------------------------------------------------------------------------
  -- Components
  ---------------------------------------------------------------------------

  component Counter is
    generic (N : natural := 8);
    port (
      clk       : in  std_logic;
      a_rst_h   : in  std_logic;
      en        : in  std_logic;
      increment : in  std_logic_vector(N - 1 downto 0);
      cntr_out  : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  component ripple_carry_adder is
    generic (Nbit : positive := 8);
    port (
      a    : in  std_logic_vector(Nbit - 1 downto 0);
      b    : in  std_logic_vector(Nbit - 1 downto 0);
      cin  : in  std_logic;
      s    : out std_logic_vector(Nbit - 1 downto 0);
      cout : out std_logic
    );
  end component;

  component DFF_N is
    generic (N : natural := 8);
    port (
      clk     : in  std_logic;
      a_rst_h : in  std_logic;
      en      : in  std_logic;
      d       : in  std_logic_vector(N - 1 downto 0);
      q       : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  component lut_7bit_11bit_quad is
    port (
      address       : in  std_logic_vector(6 downto 0);
      amplitude_out : out std_logic_vector(10 downto 0)
    );
  end component;

  component array_multiplier_11x4 is
    port (
      a    : in  std_logic_vector(10 downto 0);
      b    : in  std_logic_vector(3 downto 0);
      prod : out std_logic_vector(14 downto 0)
    );
  end component;

begin

  -- 1. Phase Accumulator: phase_acc_out += FCW each cycle
  PHASE_ACCUMULATOR: Counter
    generic map (N => 16)
    port map (
      clk       => clk,
      a_rst_h   => reset,
      en        => '1',
      increment => FCW,
      cntr_out  => phase_acc_out
    );

  -- 2. Phase Adder: phase_total = phase_acc_out + PCW (carry discarded)
  PHASE_ADDER: ripple_carry_adder
    generic map (Nbit => 16)
    port map (
      a    => phase_acc_out,
      b    => PCW,
      cin  => '0',
      s    => phase_total,
      cout => open
    );

  -- 3. Address MUX: quarter-wave addressing
  --    quadrant bit [14] = 0 -> forward, 1 -> reverse (one's complement)
  lut_address <= phase_total(13 downto 7)
                 when phase_total(14) = '0'
                 else not(phase_total(13 downto 7));

  -- 4. Quarter-Wave LUT: 128 entries, 11-bit unsigned output
  LUT_INSTANCE: lut_7bit_11bit_quad
    port map (
      address       => lut_address,
      amplitude_out => lut_output
    );

  -- 5. Pipeline Register: breaks critical path after LUT
  --    Packs sign bit [15] together with LUT output to maintain alignment
  pipe_in <= phase_total(15) & lut_output;

  PIPELINE_REG: DFF_N
    generic map (N => 12)
    port map (
      clk     => clk,
      a_rst_h => reset,
      en      => '1',
      d       => pipe_in,
      q       => pipe_out
    );

  sign_bit_reg   <= pipe_out(11);
  lut_output_reg <= pipe_out(10 downto 0);

  -- 6. Array Multiplier: unsigned 11x4, product = lut_output * ACW
  AMPLITUDE_MULT: array_multiplier_11x4
    port map (
      a    => lut_output_reg,
      b    => ACW,
      prod => mult_product
    );

  -- 7. Sign MUX: apply polarity using one's complement
  --    sign=0 -> zero-extend, sign=1 -> NOT(zero-extend)
  y_signed <= ("0" & mult_product)
              when sign_bit_reg = '0'
              else not("0" & mult_product);

  -- 8. Zero-Force: output = 0 when ACW = 0 (prevents -1 artifact)
  y <= (others => '0') when ACW = "0000"
       else y_signed;

end architecture;