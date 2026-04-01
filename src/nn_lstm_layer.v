// TTSKY26A Neural Network - LSTM Layer (1 layer, 8 hidden units)
// Wraps lstm_cell and manages recurrent connections

module nn_lstm_layer (
    input clk,
    input reset_n,
    input [7:0] x_in,
    input valid_in,
    output [7:0] h_out,
    output busy_out
);

    wire [7:0] h_cell;
    wire [7:0] c_cell;
    wire busy_cell;

    nn_lstm_cell lstm_inst (
        .clk(clk),
        .reset_n(reset_n),
        .x_in(x_in),
        .valid_in(valid_in),
        .h_out(h_cell),
        .c_out(c_cell),
        .busy(busy_cell)
    );

    assign h_out = h_cell;
    assign busy_out = busy_cell;

endmodule
