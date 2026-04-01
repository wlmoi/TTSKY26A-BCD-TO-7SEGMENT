`default_nettype none
`timescale 1ns / 1ps

module tb_adc_selfcheck;

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  integer fail_count;
  integer pass_count;

  wire status_valid;
  wire status_busy;
  wire status_activity;
  wire status_saturated;

  assign status_valid = uio_out[4];
  assign status_busy = uio_out[5];
  assign status_activity = uio_out[6];
  assign status_saturated = uio_out[7];

  tt_um_william_adc8 dut (
      .ui_in   (ui_in),
      .uo_out  (uo_out),
      .uio_in  (uio_in),
      .uio_out (uio_out),
      .uio_oe  (uio_oe),
      .ena     (ena),
      .clk     (clk),
      .rst_n   (rst_n)
  );

  initial clk = 1'b0;
  always #36.873 clk = ~clk;

  function integer offset_signed;
    input [3:0] offset_trim;
    begin
      if (offset_trim[3]) begin
        offset_signed = offset_trim - 16;
      end else begin
        offset_signed = offset_trim;
      end
    end
  endfunction

  function integer expected_code;
    input integer raw_code;
    input [3:0] gain_trim;
    input [3:0] offset_trim;
    integer gain_factor;
    integer scaled;
    integer corrected;
    begin
      gain_factor = 16 + gain_trim;
      scaled = (raw_code * gain_factor + 8) >>> 4;
      corrected = scaled + offset_signed(offset_trim);

      if (corrected < 0) begin
        expected_code = 0;
      end else if (corrected > 255) begin
        expected_code = 255;
      end else begin
        expected_code = corrected;
      end
    end
  endfunction

  task automatic drive_cycle;
    input bit adc_enable;
    input bit bitstream;
    input [3:0] offset_trim;
    input [3:0] gain_trim;
    begin
      ui_in = {offset_trim, 2'b00, bitstream, adc_enable};
      uio_in = {4'b0000, gain_trim};
      @(posedge clk);
    end
  endtask

  task automatic check;
    input cond;
    input [1023:0] msg;
    begin
      if (cond) begin
        pass_count = pass_count + 1;
      end else begin
        fail_count = fail_count + 1;
        $display("[FAIL] %0s", msg);
      end
    end
  endtask

  task automatic run_window_check;
    input integer raw_ones;
    input [3:0] gain_trim;
    input [3:0] offset_trim;
    input expected_activity;
    input expected_sat;
    input [1023:0] label;

    integer i;
    integer accum;
    integer exp_code;
    integer diff_code;
    integer valid_seen;
    reg bitstream_now;
    reg found_sample;
    reg [7:0] observed_code;
    begin
      accum = 0;
      exp_code = expected_code(raw_ones, gain_trim, offset_trim);
      diff_code = 0;
      valid_seen = 0;
      bitstream_now = 1'b0;
      found_sample = 1'b0;
      observed_code = 8'h00;

      // Force decimator restart for each scenario.
      repeat (4) begin
        drive_cycle(1'b0, 1'b0, offset_trim, gain_trim);
      end

      // Stream several windows, skip initial valid pulses, then check a stable one.
      begin : STREAM_AND_CAPTURE
        for (i = 0; i < (256 * 8); i = i + 1) begin
          accum = accum + raw_ones;
          if (accum >= 256) begin
            bitstream_now = 1'b1;
            accum = accum - 256;
          end else begin
            bitstream_now = 1'b0;
          end

          drive_cycle(1'b1, bitstream_now, offset_trim, gain_trim);

          if (status_valid) begin
            valid_seen = valid_seen + 1;
            if (valid_seen >= 3) begin
              observed_code = uo_out;
              diff_code = (observed_code > exp_code) ? (observed_code - exp_code) : (exp_code - observed_code);

              check(diff_code <= 1, {label, ": conversion code mismatch"});
              check(status_busy == 1'b1, {label, ": busy should be high while enabled"});
              check(status_activity == expected_activity, {label, ": activity mismatch"});
              check(status_saturated == expected_sat, {label, ": saturation mismatch"});

              found_sample = 1'b1;
              disable STREAM_AND_CAPTURE;
            end
          end
        end
      end

      check(found_sample == 1'b1, {label, ": valid sample was not captured"});
      if (found_sample) begin
        $display("[PASS] %0s code=%0d expected=%0d activity=%0d sat=%0d", label, observed_code, exp_code, status_activity, status_saturated);
      end

      drive_cycle(1'b0, 1'b0, offset_trim, gain_trim);
    end
  endtask

  initial begin
    fail_count = 0;
    pass_count = 0;

    rst_n = 1'b0;
    ena = 1'b0;
    ui_in = 8'h00;
    uio_in = 8'h00;

    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    ena = 1'b1;
    repeat (8) @(posedge clk);

    // Disabled checks
    repeat (320) begin
      drive_cycle(1'b0, 1'b1, 4'h0, 4'h0);
      check(status_valid == 1'b0, "disabled: valid must stay low");
      check(status_busy == 1'b0, "disabled: busy must stay low");
    end

    // Nominal conversion windows
    run_window_check(24, 4'h0, 4'h0, 1'b1, 1'b0, "nominal_raw24");
    run_window_check(96, 4'h0, 4'h0, 1'b1, 1'b0, "nominal_raw96");
    run_window_check(180, 4'h0, 4'h0, 1'b1, 1'b0, "nominal_raw180");
    run_window_check(240, 4'h0, 4'h0, 1'b1, 1'b0, "nominal_raw240");

    // Calibration checks
    run_window_check(40, 4'h8, 4'h3, 1'b1, 1'b0, "calibrated_raw40");
    run_window_check(120, 4'h8, 4'h3, 1'b1, 1'b0, "calibrated_raw120");
    run_window_check(220, 4'h8, 4'h3, 1'b1, 1'b1, "calibrated_raw220");

    // Saturation and activity edge checks
    run_window_check(250, 4'hF, 4'h7, 1'b1, 1'b1, "clip_high");
    run_window_check(0, 4'h0, 4'h0, 1'b0, 1'b0, "static_zero");

    $display("============================================================");
    $display("ADC SELF-CHECK SUMMARY: pass=%0d fail=%0d", pass_count, fail_count);
    $display("============================================================");

    if (fail_count != 0) begin
      $fatal(1, "ADC self-check failed");
    end

    $finish;
  end

endmodule
