`default_nettype none

module adc_output_registers (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       sample_enable,
    input  wire       raw_ready,
    input  wire [7:0] raw_code,
    input  wire [7:0] calibrated_code,
    input  wire       activity_now,
    input  wire       saturated_now,
    output reg  [7:0] adc_code,
    output reg  [3:0] status_bits,
    output reg  [3:0] raw_nibble
);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            adc_code <= 8'h00;
            status_bits <= 4'b0000;
            raw_nibble <= 4'h0;
        end else begin
            status_bits[0] <= raw_ready;
            status_bits[1] <= sample_enable;

            if (!sample_enable) begin
                status_bits[2] <= 1'b0;
                status_bits[3] <= 1'b0;
                raw_nibble <= 4'h0;
            end

            if (raw_ready) begin
                adc_code <= calibrated_code;
                raw_nibble <= raw_code[7:4];
                status_bits[2] <= activity_now;
                status_bits[3] <= saturated_now;
            end
        end
    end

endmodule