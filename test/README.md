# TTSKY26A-BCD-TO-7SEGMENT Test Guide

## Cocotb Regression (RTL + GL)

Run from this folder:

```powershell
make
```

For gate-level simulation in Tiny Tapeout flow:

```powershell
$env:GATES="yes"
make
```

## Standalone Verilog Verification

```powershell
iverilog -o sim_bcd_verify.vvp -I ../src \
  ../src/project.v \
  ../src/bcd_to_7seg_decoder.v \
  ../src/seg_display_control.v \
  ../src/seg_output_mode.v \
  tb_verify.v

vvp sim_bcd_verify.vvp
```

Expected summary:
- pass=13
- fail=0
