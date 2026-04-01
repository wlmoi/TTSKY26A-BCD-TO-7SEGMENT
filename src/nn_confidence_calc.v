// TTSKY26A Neural Network - Confidence Score Calculator
// Converts probability (0-255) to 6-bit confidence (0-63)
// Also detects trigger when probability > 80% (threshold = 205)

module nn_confidence_calc (
    input clk,
    input reset_n,
    input [7:0] prob_in,        // Probability 0-255
    input valid_in,
    output reg [5:0] confidence, // Confidence 0-63
    output reg trigger,         // High when prob > 205 (~80.5%)
    output reg valid_out
);

    // Convert 8-bit probability (0-255) to 6-bit confidence (0-63)
    // confidence = prob >> 2 (divide by 4)
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            confidence <= 6'b0;
            trigger <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            // Scale probability to 6-bit confidence
            confidence <= prob_in[7:2];
            
            // Trigger threshold at 80.5% (205/255)
            trigger <= (prob_in >= 8'd205) ? 1'b1 : 1'b0;
            
            valid_out <= valid_in;
        end
    end

endmodule
