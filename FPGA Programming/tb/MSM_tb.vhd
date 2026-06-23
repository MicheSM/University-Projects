-- ##############################################################################
-- MSM Testbench
--  1  - Reset assertion
--  2  - Reset recovery + basic sine
--  3  - Zero frequency (DC)
--  4  - FSK low frequency
--  5  - FSK high frequency
--  6  - BPSK (180 deg)
--  7  - QPSK (90 deg)
--  8  - QPSK (270 deg)
--  9  - ASK zero amplitude (zero-force)
--  10 - ASK minimum amplitude
--  11 - ASK mid amplitude
--  12 - ASK max amplitude
--  13 - Simultaneous input change
--  14 - Reset mid-operation
--  15 - Recovery after reset
--  16 - Near-Nyquist frequency
--  17 - Phase accumulator wrap-around
-- ##############################################################################

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity MSM_tb is
end entity;

architecture tb of MSM_tb is

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

  constant T_CLK : time := 8 ns;  -- 125 MHz
  constant T_RESET_CYCLES : integer := 4;

  -- Sine period in clocks = 65536 / FCW
  constant PERIOD_0100 : integer := 256;   -- FCW = 0x0100
  constant PERIOD_0200 : integer := 128;   -- FCW = 0x0200
  constant PERIOD_0040 : integer := 1024;  -- FCW = 0x0040

  -- Pipeline latency (accumulator reg + pipeline reg)
  constant PIPELINE_STAGES : integer := 2;

  -- Test start times (cumulative)
  constant C1  : integer := T_RESET_CYCLES;
  constant C2  : integer := C1  + PERIOD_0100 * 2;
  constant C3  : integer := C2  + 300;
  constant C4  : integer := C3  + PERIOD_0100 * 2;
  constant C5  : integer := C4  + PERIOD_0200 * 2;
  constant C6  : integer := C5  + PERIOD_0100 * 2;
  constant C7  : integer := C6  + PERIOD_0100 * 2;
  constant C8  : integer := C7  + PERIOD_0100 * 2;
  constant C9  : integer := C8  + PERIOD_0100 * 2;
  constant C10 : integer := C9  + PERIOD_0100;
  constant C11 : integer := C10 + PERIOD_0100;
  constant C12 : integer := C11 + PERIOD_0100;
  constant C13 : integer := C12 + PERIOD_0100;
  constant C14 : integer := C13 + 100;
  constant C15 : integer := C14 + PERIOD_0100 * 2;
  constant C16 : integer := C15 + 200;
  constant C17 : integer := C16 + PERIOD_0040;

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------

  signal clk_tb   : std_logic := '0';
  signal reset_tb  : std_logic := '1';
  signal run_simulation : std_logic := '1';
  signal FCW_tb : std_logic_vector(15 downto 0) := (others => '0');
  signal PCW_tb : std_logic_vector(15 downto 0) := (others => '0');
  signal ACW_tb : std_logic_vector(3 downto 0)  := (others => '0');
  signal y_tb   : std_logic_vector(15 downto 0);

---------------------------------------------------------------------------
-- Component
---------------------------------------------------------------------------

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

  -- clock generation (125 MHz)
  clk_tb <= (not(clk_tb) and run_simulation) after T_CLK / 2;

  -- DUT instance
  DUT: MSM
    port map (
      clk => clk_tb,
      reset => reset_tb,
      FCW => FCW_tb,
      PCW => PCW_tb,
      ACW => ACW_tb,
      y => y_tb
    );

  ---------------------------------------------------------------------------
  -- Stimulus process
  ---------------------------------------------------------------------------
  stimuli: process(clk_tb, reset_tb)
    variable clock_cycle : integer := 0;
  begin
    if (rising_edge(clk_tb)) then
      case (clock_cycle) is

        -- TEST 1: Reset active, non-zero inputs -> y must stay 0
        when 0 =>
          report "TEST 1: Reset assertion";
          reset_tb <= '1';
          FCW_tb <= x"0100"; PCW_tb <= x"4000"; ACW_tb <= x"F";

        -- TEST 2: Release reset, basic sine (FCW=0x0100, ACW=15)
        when T_RESET_CYCLES =>
          report "TEST 2: Basic sine wave";
          reset_tb <= '0';
          FCW_tb <= x"0100"; PCW_tb <= x"0000"; ACW_tb <= x"F";

        -- TEST 3: FCW=0 -> DC output at current phase
        when C2 =>
          report "TEST 3: DC output (FCW=0)";
          FCW_tb <= x"0000"; PCW_tb <= x"4000";

        -- TEST 4: FSK low freq
        when C3 =>
          report "TEST 4: FSK low (FCW=0x0100)";
          FCW_tb <= x"0100";

        -- TEST 5: FSK high freq (2x)
        when C4 =>
          report "TEST 5: FSK high (FCW=0x0200)";
          FCW_tb <= x"0200";

        -- TEST 6: BPSK 180 deg
        when C5 =>
          report "TEST 6: BPSK (PCW=0x8000)";
          FCW_tb <= x"0100"; PCW_tb <= x"8000";

        -- TEST 7: QPSK 90 deg
        when C6 =>
          report "TEST 7: QPSK 90 (PCW=0x4000)";
          PCW_tb <= x"4000";

        -- TEST 8: QPSK 270 deg
        when C7 =>
          report "TEST 8: QPSK 270 (PCW=0xC000)";
          PCW_tb <= x"C000";

        -- TEST 9: ACW=0 -> zero-force check
        when C8 =>
          report "TEST 9: Zero amplitude (ACW=0)";
          PCW_tb <= x"0000"; ACW_tb <= x"0";

        -- TEST 10: ACW=1 minimum amplitude
        when C9 =>
          report "TEST 10: Min amplitude (ACW=1)";
          ACW_tb <= x"1";

        -- TEST 11: ACW=8 mid amplitude
        when C10 =>
          report "TEST 11: Mid amplitude (ACW=8)";
          ACW_tb <= x"8";

        -- TEST 12: ACW=15 max amplitude
        when C11 =>
          report "TEST 12: Max amplitude (ACW=15)";
          ACW_tb <= x"F";

        -- TEST 13: Change all inputs simultaneously
        when C12 =>
          report "TEST 13: Simultaneous change";
          FCW_tb <= x"0200"; PCW_tb <= x"4000"; ACW_tb <= x"A";

        -- TEST 14: Assert reset while running
        when C13 =>
          report "TEST 14: Reset mid-operation";
          reset_tb <= '1';

        -- TEST 15: Release reset, resume
        when C14 =>
          report "TEST 15: Recovery after reset";
          reset_tb <= '0';
          FCW_tb <= x"0100"; PCW_tb <= x"0000"; ACW_tb <= x"F";

        -- TEST 16: Near-Nyquist (FCW=0x7FFF, ~2 clocks/period)
        when C15 =>
          report "TEST 16: Near-Nyquist (FCW=0x7FFF)";
          FCW_tb <= x"7FFF"; PCW_tb <= x"4000";

        -- TEST 17: Slow sine for accumulator wrap-around
        when C16 =>
          report "TEST 17: Wrap-around (FCW=0x0040)";
          FCW_tb <= x"0040"; ACW_tb <= x"F";

        -- End simulation
        when C17 =>
          report "=== ALL TESTS COMPLETED ===";
          run_simulation <= '0';

        when others => null;
      end case;

      clock_cycle := clock_cycle + 1;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Zero-force assertion: y must be 0 when ACW=0 (after pipeline latency)
  ---------------------------------------------------------------------------
  zero_force_check: process(clk_tb)
    variable cycle_count : integer := 0;
  begin
    if (rising_edge(clk_tb)) then
      if (reset_tb = '0' and ACW_tb = "0000" and cycle_count > PIPELINE_STAGES) then
        assert (y_tb = x"0000")
          report "ZERO-FORCE FAIL: y /= 0 when ACW=0 (y = " &
                 integer'image(to_integer(signed(y_tb))) & ")"
          severity error;
      end if;

      if (ACW_tb = "0000") then
        cycle_count := cycle_count + 1;
      else
        cycle_count := 0;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Metavalue assertion: no X/U on output after reset release
  ---------------------------------------------------------------------------
  no_metavalue_check: process(clk_tb)
  begin
    if (rising_edge(clk_tb)) then
      assert (not is_x(y_tb))
        report "METAVALUE FAIL: y contains X or U"
        severity error;
    end if;
  end process;

end architecture;