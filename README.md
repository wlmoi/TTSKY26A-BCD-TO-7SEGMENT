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

## Visual Overview

### Block Diagram

![BCD to 7-segment block diagram](docs/blockdiagram.png)

### Display Types

![Common anode vs common cathode](docs/commonanodecathode_format.webp)

### Segment Layout Reference

![7-segment layout](docs/bcd7segment.webp)

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

## BCD Results

Segment order uses {a,b,c,d,e,f,g} with active-high convention before optional active-low inversion.

| BCD | Digit | Segment bits (abcdefg) | Hex |
|-----|-------|-------------------------|-----|
| 0000 | 0 | 1111110 | 0x7E |
| 0001 | 1 | 0110000 | 0x30 |
| 0010 | 2 | 1101101 | 0x6D |
| 0011 | 3 | 1111001 | 0x79 |
| 0100 | 4 | 0110011 | 0x33 |
| 0101 | 5 | 1011011 | 0x5B |
| 0110 | 6 | 1011111 | 0x5F |
| 0111 | 7 | 1110000 | 0x70 |
| 1000 | 8 | 1111111 | 0x7F |
| 1001 | 9 | 1111011 | 0x7B |
| 1010-1111 | Invalid | 0000001 (dash) | 0x01 |

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

- GeeksforGeeks, BCD to 7 Segment Decoder: https://www.geeksforgeeks.org/digital-logic/bcd-to-7-segment-decoder/
- Electronics Tutorials, BCD to 7 Segment Decoder: https://www.electronics-tutorials.ws/combination/comb_6.html

## License

Apache License 2.0
