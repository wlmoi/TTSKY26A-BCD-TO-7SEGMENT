## TTSKY26A-BCD-TO-7SEGMENT

### How it works

This design translates one 4-bit BCD input into a 7-segment display pattern.

Functional pipeline:

1. BCD decode:
- Inputs 0..9 map to standard 7-segment glyphs.
- Inputs 10..15 are marked invalid and mapped to dash.

2. Display control:
- display_enable gates the output path.
- blank forces all segments off.
- lamp_test forces all segments on.

3. Output-mode adaptation:
- active-high output mode (common-cathode)
- active-low output mode (common-anode)

4. Status reporting:
- valid digit flag
- invalid digit flag
- display_on flag
- active_low_mode echo

### Pin usage summary

- ui[3:0]: BCD
- ui[4]: display_enable
- ui[5]: blank
- ui[6]: lamp_test
- ui[7]: decimal point input

- uo[6:0]: segments {a,b,c,d,e,f,g}
- uo[7]: decimal point output

- uio[0]: active_low_mode
- uio_out[7:4]: status flags

### How to test

#### Cocotb regression

```powershell
cd test
make
```

#### Standalone Verilog check

```powershell
cd test
iverilog -o sim_bcd_verify.vvp -I ../src \
  ../src/project.v \
  ../src/bcd_to_7seg_decoder.v \
  ../src/seg_display_control.v \
  ../src/seg_output_mode.v \
  tb_verify.v

vvp sim_bcd_verify.vvp
```

### References

1. Tiny Tapeout: https://tinytapeout.com/
2. GeeksforGeeks, Deep Learning - Introduction to Long Short Term Memory: https://www.geeksforgeeks.org/deep-learning/deep-learning-introduction-to-long-short-term-memory/
