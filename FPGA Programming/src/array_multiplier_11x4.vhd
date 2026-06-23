library ieee;
  use ieee.std_logic_1164.all;

entity array_multiplier_11x4 is
  port (
    a    : in  std_logic_vector(10 downto 0);  -- 11-bit multiplicand
    b    : in  std_logic_vector(3 downto 0);   -- 4-bit multiplier
    prod : out std_logic_vector(14 downto 0)   -- 15-bit unsigned product
  );
end entity;

architecture struct of array_multiplier_11x4 is

---------------------------------------------------------------------------
-- Internal signals
---------------------------------------------------------------------------
  
  -- Partial products: pp_i(j) = a(j) AND b(i)
  signal pp0 : std_logic_vector(10 downto 0);
  signal pp1 : std_logic_vector(10 downto 0);
  signal pp2 : std_logic_vector(10 downto 0);
  signal pp3 : std_logic_vector(10 downto 0);

  -- RCA intermediate sums and carries
  signal sum1  : std_logic_vector(10 downto 0);
  signal cout1 : std_logic;
  signal sum2  : std_logic_vector(10 downto 0);
  signal cout2 : std_logic;
  signal sum3  : std_logic_vector(10 downto 0);
  signal cout3 : std_logic;

  -- RCA inputs (shifted partial sums)
  signal a_in_row1 : std_logic_vector(10 downto 0);
  signal a_in_row2 : std_logic_vector(10 downto 0);
  signal a_in_row3 : std_logic_vector(10 downto 0);

---------------------------------------------------------------------------
-- Component declaration
---------------------------------------------------------------------------

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

begin

  -- Partial product generation
  GEN_PP0: for j in 0 to 10 generate
    pp0(j) <= a(j) and b(0);
  end generate;

  GEN_PP1: for j in 0 to 10 generate
    pp1(j) <= a(j) and b(1);
  end generate;

  GEN_PP2: for j in 0 to 10 generate
    pp2(j) <= a(j) and b(2);
  end generate;

  GEN_PP3: for j in 0 to 10 generate
    pp3(j) <= a(j) and b(3);
  end generate;

  -- RCA inputs: shift previous sum right by 1 (LSB goes to product)
  a_in_row1 <= '0' & pp0(10 downto 1);
  a_in_row2 <= cout1 & sum1(10 downto 1);
  a_in_row3 <= cout2 & sum2(10 downto 1);

  -- Row 1: "0" & pp0(10:1) + pp1
  RCA_ROW_1: ripple_carry_adder
    generic map (Nbit => 11)
    port map (
      a => a_in_row1,
      b => pp1,
      cin => '0',
      s => sum1,
      cout => cout1
    );

  -- Row 2: {cout1, sum1(10:1)} + pp2
  RCA_ROW_2: ripple_carry_adder
    generic map (Nbit => 11)
    port map (
      a => a_in_row2,
      b => pp2,
      cin => '0',
      s => sum2,
      cout => cout2
    );

  -- Row 3: {cout2, sum2(10:1)} + pp3
  RCA_ROW_3: ripple_carry_adder
    generic map (Nbit => 11)
    port map (
      a => a_in_row3,
      b => pp3,
      cin => '0',
      s => sum3,
      cout => cout3
    );

  -- Product assembly: collect LSBs from each row + final sum
  prod(0)           <= pp0(0);
  prod(1)           <= sum1(0);
  prod(2)           <= sum2(0);
  prod(13 downto 3) <= sum3(10 downto 0);
  prod(14)          <= cout3;

end architecture;