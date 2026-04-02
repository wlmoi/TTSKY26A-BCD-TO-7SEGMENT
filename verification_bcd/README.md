# verification_bcd

Standalone deterministic verification for TTSKY26A-BCD-TO-7SEGMENT HEX behavior.

## Run

```powershell
./run_verification.ps1
```

## What it checks

- HEX digits 0,1,2,9,A,b,C,d,e,F
- Blank mode
- Lamp-test mode
- Active-low output mode
- Top-level enable gating

Expected final summary:
- fail=0
