`default_nettype none

module tt_um_wlmoi_bcd_to_7segment (
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

  // Inputs
  wire [3:0] bcd_in = ui_in[3:0];
  wire display_enable_in = ui_in[4];
  wire blank_in = ui_in[5];
  wire lamp_test_in = ui_in[6];
  wire dp_in = ui_in[7];

  // Mode
  wire active_low_mode = uio_in[0];

  // Effective enable respects top-level enable and reset.
  wire display_enable = ena & rst_n & display_enable_in;

  wire [6:0] seg_digit;
  wire       valid_digit;
  wire [6:0] seg_active_high;
  wire       display_on;
  wire       invalid_active;
  wire [6:0] seg_pins;
  wire       dp_active_high;
  wire       dp_pin;

  bcd_to_7seg_decoder u_decoder (
    .bcd       (bcd_in),
    .segments  (seg_digit),
    .valid_digit(valid_digit)
  );

  seg_display_control u_control (
    .seg_digit     (seg_digit),
    .valid_digit   (valid_digit),
    .display_enable(display_enable),
    .blank         (blank_in),
    .lamp_test     (lamp_test_in),
    .seg_out       (seg_active_high),
    .display_on    (display_on),
    .invalid_active(invalid_active)
  );

  assign dp_active_high = display_enable & ~blank_in & (lamp_test_in | dp_in);

  seg_output_mode u_mode (
    .seg_active_high(seg_active_high),
    .dp_active_high (dp_active_high),
    .active_low_mode(active_low_mode),
    .seg_pins       (seg_pins),
    .dp_pin         (dp_pin)
  );

  // uo_out[6:0] => segments a..g, uo_out[7] => decimal point.
  assign uo_out = {dp_pin, seg_pins};

  // uio_out[7:4] => {active_low_mode, display_on, invalid_active, valid_digit}
  assign uio_out[7:4] = {
    active_low_mode,
    display_on,
    invalid_active,
    valid_digit & display_on
  };
  assign uio_out[3:0] = 4'b0000;

  assign uio_oe = 8'b11110000;

  wire _unused = &{clk, uio_in[7:1], 1'b0};
`ifdef USE_POWER_PINS
  wire _unused_power = &{VPWR, VGND, 1'b0};
`endif

endmodule
