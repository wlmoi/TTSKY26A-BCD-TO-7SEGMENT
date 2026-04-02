`timescale 1ns/1ps

module tb_bcd_selfcheck;

    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    integer pass_count = 0;
    integer fail_count = 0;

    tt_um_wlmoi_bcd_to_7segment dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    task automatic check_case(
        input [7:0] ui_val,
        input [7:0] uio_val,
        input [7:0] exp_uo,
        input [3:0] exp_status,
        input [159:0] name
    );
    begin
        ui_in = ui_val;
        uio_in = uio_val;
        @(posedge clk);
        #1;
        if ((uo_out === exp_uo) && (uio_out[7:4] === exp_status)) begin
            pass_count = pass_count + 1;
            $display("[PASS] %0s", name);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] %0s", name);
            $display("       expected uo=0x%02h status=0x%1h", exp_uo, exp_status);
            $display("       got      uo=0x%02h status=0x%1h", uo_out, uio_out[7:4]);
        end
    end
    endtask

    initial begin
        $display("Start BCD standalone self-check");

        ena = 1'b0;
        rst_n = 1'b0;
        ui_in = 8'h00;
        uio_in = 8'h00;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        ena = 1'b1;

        check_case(8'h10, 8'h00, 8'h7E, 4'h5, "digit 0");
        check_case(8'h11, 8'h00, 8'h30, 4'h5, "digit 1");
        check_case(8'h12, 8'h00, 8'h6D, 4'h5, "digit 2");
        check_case(8'h19, 8'h00, 8'h7B, 4'h5, "digit 9");
        check_case(8'h1A, 8'h00, 8'h01, 4'h6, "invalid A");
        check_case(8'h38, 8'h00, 8'h00, 4'h0, "blank mode");
        check_case(8'h50, 8'h00, 8'hFF, 4'h5, "lamp test");
        check_case(8'h12, 8'h01, 8'h92, 4'hD, "active-low mode");

        ena = 1'b0;
        check_case(8'h98, 8'h00, 8'h00, 4'h0, "ena gate off");

        $display("SUMMARY: pass=%0d fail=%0d", pass_count, fail_count);
        if (fail_count != 0) begin
            $fatal(1, "BCD self-check failed");
        end
        $finish;
    end

endmodule
