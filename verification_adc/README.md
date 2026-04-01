# ADC Standalone Verification

Folder ini berisi verifikasi Verilog murni (tanpa cocotb) untuk desain `tt_um_william_adc8`.

## Isi

- `tb_adc_selfcheck.v`: testbench self-check dengan assert internal.
- `run_verification.ps1`: script compile + run (`iverilog` + `vvp`).
- `results/`: output log dan artefak simulasi.

## Cara run

```powershell
Set-Location .\verification_adc
.\run_verification.ps1
```

## Kriteria lulus

- Summary menampilkan `fail=0`.
- Tidak ada `$fatal` dari testbench.
