`default_nettype none

module seg_output_mode (
    input  wire [6:0] seg_active_high,
    input  wire       dp_active_high,
    input  wire       active_low_mode,
    output wire [6:0] seg_pins,
    output wire       dp_pin
);
    assign seg_pins = active_low_mode ? ~seg_active_high : seg_active_high;
    assign dp_pin   = active_low_mode ? ~dp_active_high : dp_active_high;

endmodule
