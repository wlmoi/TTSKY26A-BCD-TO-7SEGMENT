# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import NextTimeStep, ReadOnly, RisingEdge

SEG_MAP = {
    0x0: 0b1111110,
    0x1: 0b0110000,
    0x2: 0b1101101,
    0x3: 0b1111001,
    0x4: 0b0110011,
    0x5: 0b1011011,
    0x6: 0b1011111,
    0x7: 0b1110000,
    0x8: 0b1111111,
    0x9: 0b1111011,
}

DASH_SEG = 0b0000001


def pack_ui(bcd, display_enable=1, blank=0, lamp_test=0, dp=0):
    return (
        ((dp & 0x1) << 7)
        | ((lamp_test & 0x1) << 6)
        | ((blank & 0x1) << 5)
        | ((display_enable & 0x1) << 4)
        | (bcd & 0xF)
    )


async def drive_signals(dut, ui_in=None, uio_in=None, ena=None, rst_n=None):
    await NextTimeStep()
    if ui_in is not None:
        dut.ui_in.value = ui_in
    if uio_in is not None:
        dut.uio_in.value = uio_in
    if ena is not None:
        dut.ena.value = ena
    if rst_n is not None:
        dut.rst_n.value = rst_n


async def sample_once(dut):
    await RisingEdge(dut.clk)
    await ReadOnly()
    return int(dut.uo_out.value), int(dut.uio_out.value)


def split_status(uio_out):
    return {
        "valid": (uio_out >> 4) & 0x1,
        "invalid": (uio_out >> 5) & 0x1,
        "display_on": (uio_out >> 6) & 0x1,
        "active_low": (uio_out >> 7) & 0x1,
    }


def expected_outputs(bcd, display_enable=1, blank=0, lamp_test=0, dp=0, active_low_mode=0):
    valid_digit = 1 if bcd <= 9 else 0
    seg_digit = SEG_MAP.get(bcd, DASH_SEG)

    if not display_enable or blank:
        seg_active_high = 0b0000000
    elif lamp_test:
        seg_active_high = 0b1111111
    else:
        seg_active_high = seg_digit

    display_on = 1 if display_enable and not blank else 0
    invalid_active = 1 if (display_on and not lamp_test and not valid_digit) else 0
    valid_status = 1 if (valid_digit and display_on) else 0

    dp_active_high = 1 if (display_enable and not blank and (lamp_test or dp)) else 0

    if active_low_mode:
        seg = (~seg_active_high) & 0x7F
        dp_out = 0 if dp_active_high else 1
    else:
        seg = seg_active_high
        dp_out = dp_active_high

    uo_out = ((dp_out & 0x1) << 7) | seg
    status = {
        "valid": valid_status,
        "invalid": invalid_active,
        "display_on": display_on,
        "active_low": active_low_mode,
    }
    return uo_out, status


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start BCD-to-7segment verification")

    await drive_signals(dut, ena=0, rst_n=0, ui_in=pack_ui(0, 0), uio_in=0)
    for _ in range(4):
        await RisingEdge(dut.clk)

    await drive_signals(dut, rst_n=1, ena=1)
    for _ in range(2):
        await RisingEdge(dut.clk)

    # Check valid BCD digits in common-cathode mode.
    for digit in range(10):
        ui_val = pack_ui(digit, display_enable=1, blank=0, lamp_test=0, dp=0)
        await drive_signals(dut, ui_in=ui_val, uio_in=0x00)
        got_uo, got_uio = await sample_once(dut)

        exp_uo, exp_status = expected_outputs(digit, 1, 0, 0, 0, 0)
        assert got_uo == exp_uo, (
            f"Digit {digit} mismatch. expected uo=0x{exp_uo:02x}, got uo=0x{got_uo:02x}"
        )

        got_status = split_status(got_uio)
        assert got_status == exp_status, (
            f"Digit {digit} status mismatch. expected={exp_status}, got={got_status}"
        )

    # Invalid BCD should show dash and invalid flag.
    for digit in [10, 11, 12, 13, 14, 15]:
        ui_val = pack_ui(digit, display_enable=1, blank=0, lamp_test=0, dp=0)
        await drive_signals(dut, ui_in=ui_val, uio_in=0x00)
        got_uo, got_uio = await sample_once(dut)

        exp_uo, exp_status = expected_outputs(digit, 1, 0, 0, 0, 0)
        assert got_uo == exp_uo, (
            f"Invalid digit {digit} mismatch. expected uo=0x{exp_uo:02x}, got=0x{got_uo:02x}"
        )
        assert split_status(got_uio) == exp_status, (
            f"Invalid digit {digit} status mismatch"
        )

    # Blank mode should force all segments off.
    await drive_signals(dut, ui_in=pack_ui(8, display_enable=1, blank=1, lamp_test=0, dp=1), uio_in=0x00)
    got_uo, got_uio = await sample_once(dut)
    exp_uo, exp_status = expected_outputs(8, 1, 1, 0, 1, 0)
    assert got_uo == exp_uo, "Blank mode output mismatch"
    assert split_status(got_uio) == exp_status, "Blank mode status mismatch"

    # Lamp-test should force all segments (and dp) on.
    await drive_signals(dut, ui_in=pack_ui(3, display_enable=1, blank=0, lamp_test=1, dp=0), uio_in=0x00)
    got_uo, got_uio = await sample_once(dut)
    exp_uo, exp_status = expected_outputs(3, 1, 0, 1, 0, 0)
    assert got_uo == exp_uo, "Lamp-test output mismatch"
    assert split_status(got_uio) == exp_status, "Lamp-test status mismatch"

    # Active-low mode inversion check.
    await drive_signals(dut, ui_in=pack_ui(2, display_enable=1, blank=0, lamp_test=0, dp=0), uio_in=0x01)
    got_uo, got_uio = await sample_once(dut)
    exp_uo, exp_status = expected_outputs(2, 1, 0, 0, 0, 1)
    assert got_uo == exp_uo, "Active-low mode output mismatch"
    assert split_status(got_uio) == exp_status, "Active-low mode status mismatch"

    # Disable via ena should blank outputs regardless of BCD value.
    await drive_signals(dut, ena=0, ui_in=pack_ui(8, display_enable=1, blank=0, lamp_test=0, dp=1), uio_in=0x00)
    got_uo, got_uio = await sample_once(dut)
    exp_uo, exp_status = expected_outputs(8, 0, 0, 0, 1, 0)
    assert got_uo == exp_uo, "Enable gating output mismatch"
    assert split_status(got_uio) == exp_status, "Enable gating status mismatch"

    await drive_signals(dut, ena=1)
    await RisingEdge(dut.clk)

    dut._log.info("BCD-to-7segment checks passed")
