# ADC Verification Report

Date: 2026-04-01  
Project: `tt_um_william_adc8`  
Method: Standalone Verilog self-check (`iverilog` + `vvp`)

## Command Executed

```powershell
Set-Location .\verification_adc
.\run_verification.ps1
```

## Final Result

- Status: **PASS**
- Summary: `ADC SELF-CHECK SUMMARY: pass=685 fail=0`
- Raw simulation log: `results/adc_selfcheck.log`

## Module-by-Module Check Coverage

1. `adc_input_synchronizer.v`
- Checked via enable/disable transitions and stable status propagation.
- Evidence: disabled checks keep `valid=0` and `busy=0`.

2. `adc_control.v`
- Checked via enable-gated sampling behavior.
- Evidence: when ADC disabled, decimation/valid pulse never runs.

3. `adc_decimator.v`
- Checked with known bit densities: 24, 96, 180, 240 ones per 256 samples.
- Evidence: output code matches expected (exact match in all tested points).

4. `adc_gain_offset_cal.v`
- Checked with gain/offset trims:
  - raw 40, gain 8, offset +3 => code 63
  - raw 120, gain 8, offset +3 => code 183
  - raw 220, gain 8, offset +3 => clipped 255

5. `adc_activity_monitor.v`
- Checked with dynamic and static streams.
- Evidence:
  - dynamic patterns => `activity=1`
  - static zero => `activity=0`

6. `adc_output_registers.v`
- Checked by monitoring `valid`, `busy`, `activity`, `saturated` outputs.
- Evidence: status flags align with scenario expectations.

7. `adc_sigma_delta_top.v`
- Integration of all submodules validated under all scenarios.

8. `project.v` (`tt_um_william_adc8`)
- Top-level pin mapping verified through the same end-to-end scenarios.

## Tested Scenarios

1. `nominal_raw24`
2. `nominal_raw96`
3. `nominal_raw180`
4. `nominal_raw240`
5. `calibrated_raw40`
6. `calibrated_raw120`
7. `calibrated_raw220`
8. `clip_high`
9. `static_zero`

All scenarios passed.
