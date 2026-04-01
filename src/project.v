`default_nettype none

module tt_um_william_adc8 (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
`ifdef USE_POWER_PINS
  ,
  input  wire       VPWR,
  input  wire       VGND
`endif
);

  wire core_enable;
  wire bitstream_in;
  wire [3:0] gain_trim;
  wire [3:0] offset_trim;
  wire [7:0] adc_code;
  wire adc_valid;
  wire adc_busy;
  wire adc_activity;
  wire adc_saturated;

  assign core_enable = ena & ui_in[0];
  assign bitstream_in = ui_in[1];
  assign offset_trim = ui_in[7:4];
  assign gain_trim = uio_in[3:0];

  adc_sigma_delta_top #(
    .WINDOW_BITS       (8),
    .ACTIVITY_THRESHOLD(8)
  ) u_adc (
    .clk               (clk),
    .reset_n           (rst_n),
    .enable            (core_enable),
    .bitstream_in      (bitstream_in),
    .gain_trim         (gain_trim),
    .offset_trim       (offset_trim),
    .adc_code          (adc_code),
    .adc_valid         (adc_valid),
    .adc_busy          (adc_busy),
    .adc_activity      (adc_activity),
    .adc_saturated     (adc_saturated)
  );

  assign uo_out = adc_code;

  assign uio_out[7:4] = {adc_saturated, adc_activity, adc_busy, adc_valid};
  assign uio_out[3:0] = 4'b0;

  assign uio_oe = 8'b11110000;

  wire _unused = &{ui_in[3:2], uio_in[7:4], 1'b0};
`ifdef USE_POWER_PINS
  wire _unused_power = &{VPWR, VGND, 1'b0};
`endif

endmodule
