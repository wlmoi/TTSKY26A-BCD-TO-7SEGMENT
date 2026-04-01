`default_nettype none

module adc_control (
    input  wire clk,
    input  wire reset_n,
    input  wire enable,
    output reg  sample_enable
);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sample_enable <= 1'b0;
        end else begin
            sample_enable <= enable;
        end
    end

    wire _unused = &{clk, 1'b0};

endmodule