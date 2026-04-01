// TTSKY26A Neural Network - Busy Controller
// Manages busy flag through pipeline stages
// Asserts busy for N cycles during LSTM computation

module nn_busy_controller (
    input clk,
    input reset_n,
    input valid_in,            // New sample incoming
    input lstm_busy,           // LSTM processing busy
    output reg busy_out        // Chip busy (don't send new data)
);

    reg [2:0] busy_counter;
    localparam BUSY_CYCLES = 3'd6;  // 6 cycles for full LSTM computation

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            busy_counter <= 3'b0;
            busy_out <= 1'b0;
        end else begin
            if (valid_in && !busy_out) begin
                // Start busy period
                busy_counter <= BUSY_CYCLES;
                busy_out <= 1'b1;
            end else if (busy_counter > 3'b0) begin
                // Count down busy cycles
                busy_counter <= busy_counter - 1'b1;
                busy_out <= 1'b1;
            end else begin
                // Done processing
                busy_out <= 1'b0;
            end
        end
    end

endmodule
