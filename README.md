![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# TTSKY26A-BCD-TO-7SEGMENT

Tiny Tapeout project that converts 4-bit BCD input to 7-segment display outputs with practical control features for real hardware integration.

- Top module: tt_um_wlmoi_bcd_to_7segment
- Language: Verilog
- Clock target: 50 MHz
- Target shuttle: SKY130A

## Features

- BCD decode for digits 0..9
- Invalid BCD (10..15) shown as dash
- Display enable and blank control
- Lamp test mode (all segments on)
- Decimal point path
- Output mode selection:
  - common-cathode (active-high)
  - common-anode (active-low)
- Status reporting on uio outputs

## Interface

### Dedicated Inputs (ui[7:0])
- ui[3:0]: BCD nibble
- ui[4]: Display enable
- ui[5]: Blank
- ui[6]: Lamp test
- ui[7]: Decimal point input

### Dedicated Outputs (uo[7:0])
- uo[6:0]: Segment outputs {a,b,c,d,e,f,g}
- uo[7]: Decimal point output

### Bidirectional Input (uio[0])
- uio[0]: Active-low mode selector
  - 0: active-high segment drive (common-cathode)
  - 1: active-low segment drive (common-anode)

### Bidirectional Output Status (uio[7:4])
- uio[4]: valid digit
- uio[5]: invalid digit active
- uio[6]: display_on
- uio[7]: active_low_mode echo

## Source Files

- src/project.v
- src/bcd_to_7seg_decoder.v
- src/seg_display_control.v
- src/seg_output_mode.v

## Verification

### 1) Cocotb Regression

```powershell
cd test
make
```

### 2) Standalone Verilog Verification

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

Expected summary:
- pass=8
- fail=0

## References

- Tiny Tapeout: https://tinytapeout.com/
- GeeksforGeeks, Deep Learning - Introduction to Long Short Term Memory: https://www.geeksforgeeks.org/deep-learning/deep-learning-introduction-to-long-short-term-memory/

## License

Apache License 2.0
