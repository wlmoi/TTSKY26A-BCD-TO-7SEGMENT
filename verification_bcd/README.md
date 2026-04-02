# verification_bcd

Standalone deterministic verification for TTSKY26A-BCD-TO-7SEGMENT.

## Run

```powershell
./run_verification.ps1
```

## What it checks

- BCD digits 0,1,2,9
- Invalid BCD handling (dash)
- Blank mode
- Lamp-test mode
- Active-low output mode
- Top-level enable gating

Expected final summary:
- fail=0
