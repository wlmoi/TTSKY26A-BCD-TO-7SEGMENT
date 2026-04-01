`default_nettype none

module adc_activity_monitor #(
    parameter THRESHOLD = 8
)(
    input  wire clk,
    input  wire reset_n,
    input  wire sample_enable,
    input  wire bitstream,
    input  wire raw_ready,
    output wire activity_now
);

    reg prev_bit;
    reg [7:0] trans_count;

    assign activity_now = (trans_count >= THRESHOLD[7:0]);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            prev_bit <= 1'b0;
            trans_count <= 8'b0;
        end else if (!sample_enable) begin
            prev_bit <= bitstream;
            trans_count <= 8'b0;
        end else begin
            if ((bitstream != prev_bit) && (trans_count != 8'hFF)) begin
                trans_count <= trans_count + 1'b1;
            end
            prev_bit <= bitstream;

            if (raw_ready) begin
                trans_count <= 8'b0;
            end
        end
    end

endmodule