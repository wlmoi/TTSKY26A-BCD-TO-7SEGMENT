$ErrorActionPreference = 'Stop'

Write-Host "Running standalone BCD-to-7segment verification..." -ForegroundColor Cyan

Set-Location $PSScriptRoot

iverilog -o sim_bcd_selfcheck.vvp -I ../src `
  ../src/project.v `
  ../src/bcd_to_7seg_decoder.v `
  ../src/seg_display_control.v `
  ../src/seg_output_mode.v `
  tb_bcd_selfcheck.v

if ($LASTEXITCODE -ne 0) {
  throw "iverilog compilation failed"
}

vvp sim_bcd_selfcheck.vvp

if ($LASTEXITCODE -ne 0) {
  throw "Simulation failed"
}

Write-Host "Verification completed successfully." -ForegroundColor Green
