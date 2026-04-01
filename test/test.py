# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import RisingEdge


WINDOW = 256


def pack_ui(enable, bitstream, offset_trim):
    return ((offset_trim & 0xF) << 4) | ((bitstream & 0x1) << 1) | (enable & 0x1)


def status_nibble(dut):
    return (int(dut.uio_out.value) >> 4) & 0xF


def status_valid(dut):
    return status_nibble(dut) & 0x1


def status_busy(dut):
    return (status_nibble(dut) >> 1) & 0x1


def status_activity(dut):
    return (status_nibble(dut) >> 2) & 0x1


def status_saturated(dut):
    return (status_nibble(dut) >> 3) & 0x1


def offset_to_signed(offset_trim):
    return offset_trim - 16 if (offset_trim & 0x8) else offset_trim


def expected_code(raw_code, gain_trim, offset_trim):
    gain_factor = 16 + (gain_trim & 0xF)
    scaled = (raw_code * gain_factor + 8) >> 4
    corrected = scaled + offset_to_signed(offset_trim)
    if corrected < 0:
        return 0
    if corrected > 255:
        return 255
    return corrected


def make_density_pattern(ones_count, length=WINDOW):
    ones_count = max(0, min(length, int(ones_count)))
    accumulator = 0
    bits = []
    for _ in range(length):
        accumulator += ones_count
        if accumulator >= length:
            bits.append(1)
            accumulator -= length
        else:
            bits.append(0)
    return bits


async def stream_windows_and_capture(dut, raw_windows, gain_trim, offset_trim):
    captures = []
    dut.uio_in.value = gain_trim & 0xF

    for raw in raw_windows:
        for bit in make_density_pattern(raw):
            dut.ui_in.value = pack_ui(1, bit, offset_trim)
            await RisingEdge(dut.clk)
            if status_valid(dut):
                captures.append(
                    {
                        "code": int(dut.uo_out.value),
                        "activity": status_activity(dut),
                        "saturated": status_saturated(dut),
                    }
                )

    dut.ui_in.value = pack_ui(1, 0, offset_trim)
    for _ in range(32):
        await RisingEdge(dut.clk)
        if status_valid(dut):
            captures.append(
                {
                    "code": int(dut.uo_out.value),
                    "activity": status_activity(dut),
                    "saturated": status_saturated(dut),
                }
            )

    return captures


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start ADC decimator behavior test")

    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    for _ in range(10):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1
    dut.ena.value = 1

    for _ in range(10):
        await RisingEdge(dut.clk)

    # Disabled behavior check: no valid pulse while ADC enable bit is low.
    dut.ui_in.value = pack_ui(0, 1, 0)
    for _ in range(320):
        await RisingEdge(dut.clk)
        assert status_valid(dut) == 0, "Valid pulse asserted while ADC disabled"
        assert status_busy(dut) == 0, "Busy status asserted while ADC disabled"

    raw_sequence = [0, 0, 24, 96, 180, 240]
    captured = await stream_windows_and_capture(dut, raw_sequence, gain_trim=0, offset_trim=0)
    assert len(captured) >= 4, "Did not capture enough ADC output samples"

    expected_nominal = [expected_code(v, 0, 0) for v in [24, 96, 180, 240]]
    observed_nominal = [c["code"] for c in captured[-4:]]
    assert observed_nominal == expected_nominal, (
        f"Nominal conversion mismatch. Expected {expected_nominal}, got {observed_nominal}"
    )

    # Gain and positive offset check.
    raw_sequence = [0, 0, 40, 120, 220]
    gain_trim = 8
    offset_trim = 0x3
    captured = await stream_windows_and_capture(dut, raw_sequence, gain_trim=gain_trim, offset_trim=offset_trim)
    assert len(captured) >= 3, "Did not capture enough calibrated ADC samples"

    expected_cal = [expected_code(v, gain_trim, offset_trim) for v in [40, 120, 220]]
    observed_cal = [c["code"] for c in captured[-3:]]
    assert observed_cal == expected_cal, (
        f"Calibrated conversion mismatch. Expected {expected_cal}, got {observed_cal}"
    )

    # Saturation and activity checks.
    raw_sequence = [0, 0, 250]
    captured = await stream_windows_and_capture(dut, raw_sequence, gain_trim=15, offset_trim=0x7)
    assert captured[-1]["code"] == 255, "High-end clipping failed to saturate at 255"
    assert captured[-1]["saturated"] == 1, "Saturation status did not assert for clipped sample"

    raw_sequence = [0, 0, 128]
    captured = await stream_windows_and_capture(dut, raw_sequence, gain_trim=0, offset_trim=0)
    assert captured[-1]["activity"] == 1, "Activity status did not assert on toggling bitstream"

    raw_sequence = [0, 0, 0]
    captured = await stream_windows_and_capture(dut, raw_sequence, gain_trim=0, offset_trim=0)
    assert captured[-1]["activity"] == 0, "Activity status remained asserted on static input"

    dut._log.info("ADC decimator checks passed")
