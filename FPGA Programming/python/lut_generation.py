#!/usr/bin/env python3

# ##############################################################################
# Description  : Utility script for VHDL design LUT (Sine Wave)
# File         : LUT_generation.py
#
# Original Author(s): Luca Fanucci <luca.fanucci@unipi.it>
#              : Massimiliano Donati <massimiliano.donati@unipi.it>
#              : Luca Zulberti <luca.zulberti@phd.unipi.it>
# Department   : Dept. Information Engineering, University of Pisa
# Created      : Wed May 9 14:58:06 2018
#
# Modified by  : Mykhaylo Semenyshen <m.semenyshen@studenti.unipi.it>
# Last update  : April 2, 2026
# Modification : Refactored for modern Python 3.x, added first-quadrant
#                generation, and improved input validation. Modifications
#                were developed with the assistance of AI (Google Gemini).
#
# Language     : python3.x
# ##############################################################################

import math
import sys

def get_positive_int(prompt: str) -> int:
    """Prompts the user repeatedly until a valid positive integer is provided."""
    while True:
        try:
            val = int(input(prompt))
            if val > 0:
                return val
            print("WARNING: Please insert a positive integer.")
        except ValueError:
            print("WARNING: Invalid input. Please enter an integer.")

print("\n" + "*" * 80)
print("** DDFS Phase-to-Amplitude LUT Generation Script")
print("*" * 80 + "\n")

input_bits = get_positive_int('Input bits (Phase Address): ')
output_bits = get_positive_int('Output bits (Amplitude): ')

while True:
    quad_ans = input('Only first quadrant? (y/n): ').strip().lower()
    if quad_ans in ['y', 'n']:
        first_quadrant = (quad_ans == 'y')
        break
    print("WARNING: Please enter 'y' or 'n'.")

n_lut_lines = 2 ** input_bits

# --- DYNAMIC RANGE OPTIMIZATION ---
if first_quadrant:
    # First quadrant sine is strictly positive (0 to 1).
    # We use Unsigned format to utilize all bits for magnitude, doubling dynamic range.
    SG_UN = "UN"
    max_amplitude = (2 ** output_bits) - 1
else:
    # Full wave sine is negative and positive (-1 to 1).
    # We use Signed format with a balanced range to prevent DC offset.
    SG_UN = "SG"
    max_amplitude = 2 ** (output_bits - 1) - 1

print("-" * 40)
print(f"Input Bits      : {input_bits}")
print(f"LUT Lines       : {n_lut_lines}")
print(f"Output Bits     : {output_bits}")
print(f"LUT Type        : {SG_UN}")
print(f"Peak Amplitude  : {max_amplitude}")
print(f"First Quadrant  : {first_quadrant}")
print("-" * 40)

# VHDL best practice: Entity name and filename should match.
mname = f"lut_{input_bits}bit_{output_bits}bit"

if first_quadrant:
    mname += "_quad"

fname = f"{mname}.vhd"

try:
    with open(fname, "w") as out_file:
        out_file.write("library IEEE;\n")
        out_file.write("  use IEEE.std_logic_1164.all;\n")
        out_file.write("  use IEEE.numeric_std.all;\n\n")

        out_file.write(f"entity {mname} is\n")
        out_file.write("  port (\n")
        out_file.write(f"    address       : in  std_logic_vector({input_bits - 1} downto 0);\n")
        out_file.write(f"    amplitude_out : out std_logic_vector({output_bits - 1} downto 0)\n")
        out_file.write("  );\n")
        out_file.write("end entity;\n\n")

        out_file.write(f"architecture rtl of {mname} is\n\n")
        out_file.write(f"  type LUT_t is array (natural range 0 to {n_lut_lines - 1}) of integer;\n")
        out_file.write("  constant LUT: LUT_t := (\n")

        for a in range(n_lut_lines):
            # Map the address space to a phase angle.
            if first_quadrant:
                phase = (math.pi / 2) * (a / n_lut_lines)
            else:
                phase = 2 * math.pi * (a / n_lut_lines)

            # Scale normalized sine wave into the integer output range
            x = round(math.sin(phase) * max_amplitude)

            if a < (n_lut_lines - 1):
                out_file.write(f"    {a} => {int(x)},\n")
            else:
                out_file.write(f"    {a} => {int(x)}\n")

        out_file.write("  );\n\n")
        out_file.write("begin\n")

        # Correctly cast the array integer to the proper VHDL logic vector
        if SG_UN == "UN":
            out_file.write(
                f"  amplitude_out <= std_logic_vector(to_unsigned(LUT(to_integer(unsigned(address))), {output_bits}));\n")
        else:
            out_file.write(
                f"  amplitude_out <= std_logic_vector(to_signed(LUT(to_integer(unsigned(address))), {output_bits}));\n")

        out_file.write("end architecture;\n")

    print(f"SUCCESS: Generated {fname}")

except IOError as e:
    print(f"ERROR: Could not write to file {fname}. Details: {e}")
    sys.exit(1)