`default_nettype none

module bcd_to_7seg_decoder (
    input  wire [3:0] bcd,
    output reg  [6:0] segments,
    output reg        valid_digit
);
    // Segment order: {a,b,c,d,e,f,g}; active-high convention.
    // Hex glyph set: 0,1,2,3,4,5,6,7,8,9,A,b,C,d,e,F.
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
            4'hA: segments = 7'b1110111; // A
            4'hB: segments = 7'b0011111; // b
            4'hC: segments = 7'b1001110; // C
            4'hD: segments = 7'b0111101; // d
            4'hE: segments = 7'b1001111; // e
            4'hF: segments = 7'b1000111; // F
            default: begin
                segments   = 7'b0000000;
                valid_digit = 1'b0;
            end
        endcase
    end

endmodule
