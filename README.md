![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout - 8-bit Sigma-Delta Bitstream ADC

- Top module: `tt_um_william_adc8`
- Language: Verilog
- Target shuttle: SKY26a (`sky130A`, digital tile)
- Project docs: [docs/info.md](docs/info.md)

## Creator

- William Anthony
- Electrical Engineering, Bandung Institute of Technology (ITB)
- Built in 6th semester (admitted in 2023)
- LinkedIn: https://www.linkedin.com/in/wlmoi/
- GitHub: https://github.com/wlmoi
- Instagram: https://www.instagram.com/wlmoi/

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Overview

This project implements a fully digital, directly verifiable ADC path:

- Input is a 1-bit sigma-delta style bitstream.
- A 256-sample decimator converts the bit density into an 8-bit code.
- Gain and offset trim are applied in fixed-point.
- Status outputs indicate valid sample, busy state, activity, and clipping.

The design is deterministic and easy to validate with cocotb because each output code is tied to a well-defined 256-cycle observation window.

## Interface summary

- Global controls:
  - `ena=1` and `rst_n=1` must be asserted.
- Dedicated inputs (`ui_in`):
  - `ui[0]`: ADC enable
  - `ui[1]`: 1-bit bitstream input
  - `ui[7:4]`: signed offset trim (two's complement)
- Bidirectional (`uio`):
  - `uio[3:0]` input: gain trim
  - `uio[7:4]` output status: `{saturated, activity, busy, valid}`
- Dedicated outputs (`uo_out`):
  - `uo[7:0]`: calibrated 8-bit ADC code

## Verification

From `test/` run:

```sh
make -B
```

The cocotb test verifies:

- Disabled mode behavior (no valid pulse, no busy status).
- Nominal conversion accuracy for multiple bit densities.
- Gain and offset calibration correctness.
- Saturation flag behavior at clipping condition.
- Activity monitor response for toggling vs static input.

Waveforms can be opened with:

```sh
gtkwave tb.fst tb.gtkw
```

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## Credits

Project template and submission flow are based on the Tiny Tapeout project ecosystem and documentation.

## Submit your design

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).

## Share your project

- LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
- Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
- X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
- Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
