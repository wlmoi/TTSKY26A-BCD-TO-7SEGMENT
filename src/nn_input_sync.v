// TTSKY26A Neural Network - Input Synchronizer
// Synchronizes 7-bit signed audio feature and data-valid strobe
// Handles clock-domain crossing and pipelining

module nn_input_sync (
    input clk,
    input reset_n,
    input [6:0] audio_feature_in,  // Signed 7-bit audio (MFCC-like)
    input data_valid_in,           // Strobe signal
    output reg [7:0] audio_sync,   // Synchronized to internal 8-bit signed
    output reg valid_sync
);

    // Stage 1: Double-flop synchronizer for meta-stability
    reg [6:0] feature_sync_0, feature_sync_1;
    reg valid_sync_0, valid_sync_1;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            feature_sync_0 <= 7'b0;
            feature_sync_1 <= 7'b0;
            valid_sync_0 <= 1'b0;
            valid_sync_1 <= 1'b0;
        end else begin
            // Shift chain for incoming data
            feature_sync_0 <= audio_feature_in;
            feature_sync_1 <= feature_sync_0;
            valid_sync_0 <= data_valid_in;
            valid_sync_1 <= valid_sync_0;
        end
    end

    // Convert 7-bit signed to 8-bit signed (sign-extend)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            audio_sync <= 8'b0;
            valid_sync <= 1'b0;
        end else begin
            audio_sync <= {feature_sync_1[6], feature_sync_1};  // Sign-extend to 8-bit
            valid_sync <= valid_sync_1;
        end
    end

endmodule
