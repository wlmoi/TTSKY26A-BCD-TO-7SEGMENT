// TTSKY26A Neural Network - Dense Output Layer
// Takes LSTM hidden state and produces probability (8-bit: 0-255)
// Single neuron with sigmoid activation for binary classification

module nn_dense_layer (
    input clk,
    input reset_n,
    input [7:0] h_in,           // LSTM hidden state
    input valid_in,
    output reg [7:0] prob_out,  // Probability: 0-255 (0% to 100%)
    output reg valid_out
);

    // Simplified dense layer: weighted sum + bias + sigmoid
    // Output = sigmoid(w * h_in + bias)
    // For wake word detection, use tuned weights
    
    wire [7:0] sigmoid_in;
    wire [7:0] sigmoid_out;
    
    // Apply weight and bias (hardcoded for "NYALA" detector)
    // Weight: 2, Bias: -10 (to set threshold around 80%)
    assign sigmoid_in = (h_in << 1) - 8'd10;
    
    // Use sigmoid LUT from lstm_cell
    nn_sigmoid_lut sig_lut (
        .index(sigmoid_in),
        .out(sigmoid_out)
    );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            prob_out <= 8'b0;
            valid_out <= 1'b0;
        end else begin
            prob_out <= sigmoid_out;  // Output range: 0-255 (0% to 100%)
            valid_out <= valid_in;
        end
    end

endmodule
