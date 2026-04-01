# ADC Verification Notes

This testbench verifies the 8-bit sigma-delta decimator ADC implementation.

## What is verified

- Disabled behavior: no valid pulse and no busy status.
- Nominal code generation for known bit densities.
- Gain and offset calibration logic.
- Saturation detection for clipped output.
- Activity flag behavior for dynamic and static bitstreams.

## Run RTL test

```sh
make -B
```

## Run gate-level test

Copy the generated netlist into `gate_level_netlist.v` and run:

```sh
make -B GATES=yes
```

## Waveform viewing

```sh
gtkwave tb.fst tb.gtkw
```
