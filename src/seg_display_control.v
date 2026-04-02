`default_nettype none

module seg_display_control (
    input  wire [6:0] seg_digit,
    input  wire       valid_digit,
    input  wire       display_enable,
    input  wire       blank,
    input  wire       lamp_test,
    output reg  [6:0] seg_out,
    output wire       display_on,
    output wire       invalid_active
);
    assign display_on = display_enable & ~blank;
    assign invalid_active = display_on & ~lamp_test & ~valid_digit;

    always @* begin
        if (!display_enable || blank) begin
            seg_out = 7'b0000000;
        end else if (lamp_test) begin
            seg_out = 7'b1111111;
        end else begin
            seg_out = seg_digit;
        end
    end

endmodule
