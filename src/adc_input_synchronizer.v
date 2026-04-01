`default_nettype none

module adc_input_synchronizer (
    input  wire clk,
    input  wire reset_n,
    input  wire enable_in,
    input  wire bitstream_in,
    output reg  enable_sync,
    output reg  bitstream_sync
);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            enable_sync <= 1'b0;
            bitstream_sync <= 1'b0;
        end else begin
            enable_sync <= enable_in;
            bitstream_sync <= bitstream_in;
        end
    end

endmodule