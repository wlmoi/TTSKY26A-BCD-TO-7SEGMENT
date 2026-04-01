`default_nettype none

module adc_gain_offset_cal (
    input  wire [7:0] raw_code,
    input  wire [3:0] gain_trim,
    input  wire [3:0] offset_trim,
    output reg  [7:0] calibrated_code,
    output reg        clip_hi,
    output reg        clip_lo
);

    wire [4:0] gain_factor;
    wire signed [4:0] offset_signed;
    reg [12:0] mult_value;
    reg [8:0] scaled_code;
    reg signed [9:0] adjusted_code;

    assign gain_factor = 5'd16 + {1'b0, gain_trim};
    assign offset_signed = {offset_trim[3], offset_trim};

    always @(*) begin
        mult_value = raw_code * gain_factor;
        scaled_code = (mult_value + 13'd8) >> 4;
        adjusted_code = $signed({1'b0, scaled_code}) + $signed(offset_signed);

        clip_hi = 1'b0;
        clip_lo = 1'b0;

        if (adjusted_code < 0) begin
            calibrated_code = 8'h00;
            clip_lo = 1'b1;
        end else if (adjusted_code > 10'sd255) begin
            calibrated_code = 8'hFF;
            clip_hi = 1'b1;
        end else begin
            calibrated_code = adjusted_code[7:0];
        end
    end

endmodule