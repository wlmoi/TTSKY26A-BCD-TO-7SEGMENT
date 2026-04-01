`default_nettype none

module adc_decimator #(
    parameter WINDOW_BITS = 8
)(
    input  wire       clk,
    input  wire       reset_n,
    input  wire       sample_enable,
    input  wire       bitstream,
    output reg  [7:0] raw_code,
    output reg        raw_ready,
    output reg        busy,
    output reg        raw_saturated
);

    reg [WINDOW_BITS-1:0] sample_counter;
    reg [8:0] ones_accum;
    wire [8:0] ones_next;

    assign ones_next = ones_accum + {8'b0, bitstream};

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sample_counter <= {WINDOW_BITS{1'b0}};
            ones_accum <= 9'b0;
            raw_code <= 8'b0;
            raw_ready <= 1'b0;
            busy <= 1'b0;
            raw_saturated <= 1'b0;
        end else if (!sample_enable) begin
            sample_counter <= {WINDOW_BITS{1'b0}};
            ones_accum <= 9'b0;
            raw_ready <= 1'b0;
            busy <= 1'b0;
            raw_saturated <= 1'b0;
        end else begin
            busy <= 1'b1;
            raw_ready <= 1'b0;

            if (sample_counter == {WINDOW_BITS{1'b1}}) begin
                sample_counter <= {WINDOW_BITS{1'b0}};
                ones_accum <= 9'b0;
                raw_ready <= 1'b1;

                if (ones_next[8]) begin
                    raw_code <= 8'hFF;
                    raw_saturated <= 1'b1;
                end else begin
                    raw_code <= ones_next[7:0];
                    raw_saturated <= 1'b0;
                end
            end else begin
                sample_counter <= sample_counter + 1'b1;
                ones_accum <= ones_next;
            end
        end
    end

endmodule