![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# TTSKY26A Neural Network - LSTM Wake Word Detector

**The Whisper-Switch** - Privacy-First Smart Home Voice Controller

An 8-bit quantized LSTM neural network for real-time wake word detection on edge devices. Detects the Bahasa Indonesia word "NYALA" (Light On) without internet connectivity.

- **Top module**: `tt_um_lstm_wakeword`
- **Language**: Verilog
- **Target shuttle**: SKY130A (Tiny Tapeout)
- **Clock**: 50 MHz target (timing-constrained)

## Creator

- William Anthony
- Electrical Engineering, Bandung Institute of Technology (ITB)
- LinkedIn: https://www.linkedin.com/in/wlmoi/
- GitHub: https://github.com/wlmoi

## Overview

This project implements an LSTM neural network inference accelerator optimized for:

- **Ultra-low latency**: Single LSTM cell processes 7-bit audio features in 6-8 clock cycles
- **8-bit quantization**: Fixed-point arithmetic with pre-computed sigmoid/tanh LUTs
- **Privacy-first**: On-device detection without cloud connectivity
- **Battery-operable**: Designed for coin-cell power budget (<5mW during inference)
- **Flexible I/O**:
  - Input: 7-bit signed audio MFCC feature + valid strobe
  - Output: 1-bit trigger + 6-bit confidence + busy flag
  - Debug bypass mode for device diagnostics

## Architecture

```
Audio Input (7-bit MFCC)
        ↓
  [Input Synchronizer] → Metastability hardening
        ↓
  [LSTM Cell] → Gates (input, forget, output) + Tanh activations
        ↓
  [Dense Layer] → Classification (sigmoid)
        ↓
  [Confidence Calculator] → Threshold detection
        ↓
  Output: Trigger (1-bit) + Confidence (6-bit) + Busy (1-bit)
```

### Core Modules

| Module | Purpose | LUTs |
|--------|---------|------|
| `nn_input_sync.v` | Clock sync + metastability hardening | ~50 |
| `nn_lstm_cell.v` | LSTM cell with sigmoid/tanh LUTs | ~600 |
| `nn_lstm_layer.v` | LSTM layer wrapper | ~100 |
| `nn_dense_layer.v` | Output classification layer | ~150 |
| `nn_confidence_calc.v` | Confidence & trigger logic | ~100 |
| `nn_busy_controller.v` | Pipeline busy management | ~30 |
| `project.v` | Top-level Tiny Tapeout wrapper | ~200 |

**Total**: ~1,230 LUTs (≈61% SKY130A utilization)

## I/O Specification

### Input Ports (ui_in[7:0])

| Pin | Signal | Format | Description |
|-----|--------|--------|-------------|
| ui_in[6:0] | `audio_feature` | Signed 7-bit | MFCC coefficient from RP2040 preprocessor (-64 to +63) |
| ui_in[7] | `data_valid` | 1-bit | Strobe when feature is valid |

### Output Ports (uo_out[7:0])

| Pin | Signal | Format | Description |
|-----|--------|--------|-------------|
| uo_out[0] | `trigger` | 1-bit | **HIGH** if confidence > 80% |
| uo_out[6:1] | `confidence` | 6-bit | Unsigned score (0-63 = 0%-100%) |
| uo_out[7] | `busy` | 1-bit | HIGH if processing; don't send new data |

### Control Ports (uio_in[7:0])

| Pin | Purpose |
|-----|---------|
| uio_in[0] | **reset** - Active-HIGH to zero LSTM states |
| uio_in[1] | **debug_mode** - Active-HIGH to enable bypass (input→output) |
| uio_in[7:2] | Reserved (tied to ground) |

### Status Output (uio_out[7:0])

| Pin | Purpose |
|-----|---------|
| uio_out[7] | **busy_out** - Echo of busy flag for external coordination |
| uio_out[6:0] | Tied to ground |

## Usage Example

### Python Interface (RP2040 + TTSKY26A-NN)

```python
# 1. Reset the chip
chip.uio_in = 0x01  # reset=1
time.sleep(10e-6)
chip.uio_in = 0x00  # release reset

# 2. Read audio and compute MFCC (13 features)
audio_features = compute_mfcc(mic_samples)  # shape: (13,)

# 3. Feed to LSTM accelerator
for feature_idx in range(13):
    # Wait until not busy
    while (chip.uo_out & 0x80) != 0:
        pass
    
    # Send feature + valid strobe
    feature_val = int(audio_features[feature_idx])  # 7-bit signed
    chip.ui_in = (1 << 7) | (feature_val & 0x7F)
    
    # Wait for LSTM latency (~6 cycles @ 50 MHz)
    time.sleep(120e-9)
    
    # Read output
    confidence = (chip.uo_out >> 1) & 0x3F
    triggered = chip.uo_out & 0x01
    
    if triggered:
        print(f"✓ NYALA detected! Confidence: {confidence}/63")
        GPIO.output(RELAY_PIN, GPIO.HIGH)
        break
    else:
        print(f"  Audio [%d]: confidence={confidence}/63" % feature_idx)
```

## Quantization & Math

### 8-Bit Fixed-Point LSTM

The LSTM implementation uses simplified 8-bit integer arithmetic:

**Sigmoid LUT**: Input [-128, 127] → Output [0, 255]
- Represents sigmoid(x) ≈ 1/(1+exp(-x)) mapped to 8-bit range

**Tanh LUT**: Input [-128, 127] → Output [-128, 127]
- Represents tanh(x) ≈ 2/(1+exp(-2x)) - 1

**Gate Computation**:
```
i_gate = sigmoid( W_ii*x_t + W_hi*h_{t-1} + b_i )
f_gate = sigmoid( W_if*x_t + W_hf*h_{t-1} + b_f )
g_gate = tanh(    W_ig*x_t + W_hg*h_{t-1} + b_g )
o_gate = sigmoid( W_io*x_t + W_ho*h_{t-1} + b_o )
```

**Cell/Hidden State Update**:
```
c_t = f_gate ⊙ c_{t-1} + i_gate ⊙ g_gate
h_t = o_gate ⊙ tanh(c_t)
```

**Classification (Dense Layer)**:
```
prob = sigmoid( 2*h_t - 10 )
confidence = prob >> 2        // Scale [0..255] to [0..63]
trigger = (prob >= 205)       // Threshold at ~80%
```

### Weights & Lookup Tables

- **LSTM weights**: Hardcoded in RTL (optimized for "NYALA")
- **Sigmoid LUT**: 256 entries × 8-bit = 2 KB
- **Tanh LUT**: 256 entries × 8-bit = 2 KB
- **Total LUT memory**: 4 KB

## Testing & Verification

### Standalone RTL Verification

```bash
cd test
iverilog -o sim_verify.vvp -I ../src \
    ../src/project.v \
    ../src/nn_input_sync.v \
    ../src/nn_lstm_cell.v \
    ../src/nn_lstm_layer.v \
    ../src/nn_dense_layer.v \
    ../src/nn_confidence_calc.v \
    ../src/nn_busy_controller.v \
    tb_verify.v

vvp sim_verify.vvp
```

**Expected Output**:
```
TTSKY26A Wake Word Detector - Standalone Verification
======================================================================

[TEST 1] Low confidence sequence
  Input sequence: [-8, -4, 4, 8, -8, ...]
  ✓ No trigger (as expected)

[TEST 2] Medium confidence sequence
  ✓ Outputs generated

[TEST 3] High confidence sequence (should approach trigger)
  ✓ High confidence reflected

[TEST Reset] Verify reset clears state
  ✓ Reset cycle completed

[TEST Debug] Verify debug bypass mode
  ✓ Debug mode cycle completed

SUMMARY: 5 PASS, 0 FAIL
======================================================================
✓ All tests passed!
```

### Cocotb Regression Testing

Detailed cocotb verification available in `test/test.py`:
- Random audio sequence generation
- Golden model comparison
- Edge case testing (saturation, reset)
- Gate-level (GL) simulation support

```bash
cd test && make
```

## Configuration

### System Clock

File: `src/config.json`

```json
{
  "CLOCK_PERIOD": 20,
  "CLOCK_PORT": "clk"
}
```

The project now targets a 50 MHz external clock for higher throughput, subject to timing closure in the Tiny Tapeout flow.

## Design Decisions

1. **8-bit Quantization**: Balance between accuracy and gate count
2. **1 LSTM Cell**: Simplicity; attention/multi-head variants possible in future
3. **Fixed Weights**: No on-device training; weights are application-specific (pre-trained)
4. **Lookup Tables**: Fast sigmoid/tanh without multipliers
5. **Reset Control**: Optional state clearing for re-triggering same word

## Future Enhancements

- Multi-word detection (multiple gates on-chip)
- Adaptive threshold (environmental noise tracking)
- Energy harvesting compatible (ultra-low sleep mode)
- Multi-channel support (left/right audio)

## References

- **Tiny Tapeout**: https://tinytapeout.com/
- **SKY130 PDK**: https://skywater-pdk.readthedocs.io/
- **LSTM Architecture**: Hochreiter & Schmidhuber (1997)
- **Quantization**: Jacob et al. (2018), "Quantization and Training of Neural Networks..."

## License

Apache License 2.0 - See [LICENSE](LICENSE)
