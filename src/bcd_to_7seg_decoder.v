`default_nettype none

module bcd_to_7seg_decoder (
    input  wire [3:0] bcd,
    output reg  [6:0] segments,
    output reg        valid_digit
);
    // Segment order: {a,b,c,d,e,f,g}; active-high convention.
    always @* begin
        valid_digit = 1'b1;
        case (bcd)
            4'h0: segments = 7'b1111110;
            4'h1: segments = 7'b0110000;
            4'h2: segments = 7'b1101101;
            4'h3: segments = 7'b1111001;
            4'h4: segments = 7'b0110011;
            4'h5: segments = 7'b1011011;
            4'h6: segments = 7'b1011111;
            4'h7: segments = 7'b1110000;
            4'h8: segments = 7'b1111111;
            4'h9: segments = 7'b1111011;
            default: begin
                segments   = 7'b0000001; // Dash on invalid BCD.
                valid_digit = 1'b0;
            end
        endcase
    end

endmodule
