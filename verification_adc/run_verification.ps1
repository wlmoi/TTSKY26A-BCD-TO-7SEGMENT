$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$srcRoot = Join-Path $projectRoot "src"
$outVvp = Join-Path $PSScriptRoot "results/adc_selfcheck.vvp"
$outLog = Join-Path $PSScriptRoot "results/adc_selfcheck.log"

$rtl = @(
  (Join-Path $srcRoot "project.v"),
  (Join-Path $srcRoot "adc_sigma_delta_top.v"),
  (Join-Path $srcRoot "adc_input_synchronizer.v"),
  (Join-Path $srcRoot "adc_control.v"),
  (Join-Path $srcRoot "adc_decimator.v"),
  (Join-Path $srcRoot "adc_gain_offset_cal.v"),
  (Join-Path $srcRoot "adc_activity_monitor.v"),
  (Join-Path $srcRoot "adc_output_registers.v"),
  (Join-Path $PSScriptRoot "tb_adc_selfcheck.v")
)

Write-Host "[INFO] Compiling ADC self-check testbench..."
& iverilog -g2012 -I $srcRoot -o $outVvp $rtl

Write-Host "[INFO] Running ADC self-check simulation..."
& vvp $outVvp *>&1 | Tee-Object -FilePath $outLog

Write-Host "[INFO] Done. Log: $outLog"
