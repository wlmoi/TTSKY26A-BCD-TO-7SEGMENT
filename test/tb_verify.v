`timescale 1ns/1ps

module tb_bcd_to_7segment_verify;

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

    // 50MHz clock
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    task automatic apply_and_check(
        input [7:0] ui_val,
        input [7:0] uio_val,
        input [7:0] exp_uo,
        input [3:0] exp_status,
        input [159:0] test_name
    );
    begin
        ui_in = ui_val;
        uio_in = uio_val;
        @(posedge clk);
        #1;

        if ((uo_out === exp_uo) && (uio_out[7:4] === exp_status)) begin
            pass_count = pass_count + 1;
            $display("[PASS] %0s uo=0x%02h status=0x%1h", test_name, uo_out, uio_out[7:4]);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] %0s", test_name);
            $display("       expected: uo=0x%02h status=0x%1h", exp_uo, exp_status);
            $display("       got     : uo=0x%02h status=0x%1h", uo_out, uio_out[7:4]);
        end
    end
    endtask

    initial begin
        $display("============================================");
        $display("TTSKY26A HEX-to-7Segment Standalone Verify");
        $display("============================================");

        ena = 1'b0;
        rst_n = 1'b0;
        ui_in = 8'h00;
        uio_in = 8'h00;

        repeat (3) @(posedge clk);

        rst_n = 1'b1;
        ena = 1'b1;
        repeat (2) @(posedge clk);

        // ui format: [7]=dp, [6]=lamp_test, [5]=blank, [4]=display_enable, [3:0]=hex
        // status nibble: {active_low, display_on, invalid, valid}
        apply_and_check(8'h10, 8'h00, 8'h7E, 4'h5, "Digit 0 common-cathode");
        apply_and_check(8'h19, 8'h00, 8'h7B, 4'h5, "Digit 9 common-cathode");
        apply_and_check(8'h1A, 8'h00, 8'h77, 4'h5, "Digit A common-cathode");
        apply_and_check(8'h1B, 8'h00, 8'h1F, 4'h5, "Digit b common-cathode");
        apply_and_check(8'h1C, 8'h00, 8'h4E, 4'h5, "Digit C common-cathode");
        apply_and_check(8'h1D, 8'h00, 8'h3D, 4'h5, "Digit d common-cathode");
        apply_and_check(8'h1E, 8'h00, 8'h4F, 4'h5, "Digit e common-cathode");
        apply_and_check(8'h1F, 8'h00, 8'h47, 4'h5, "Digit F common-cathode");
        apply_and_check(8'h38, 8'h00, 8'h00, 4'h0, "Blank mode forces off");
        apply_and_check(8'h50, 8'h00, 8'hFF, 4'h5, "Lamp test forces all on");
        apply_and_check(8'h12, 8'h01, 8'h92, 4'hD, "Digit 2 active-low mode");
        apply_and_check(8'h91, 8'h00, 8'hB0, 4'h5, "Decimal point active-high");

        // Disable via ena should blank output regardless of ui settings.
        ena = 1'b0;
        apply_and_check(8'h98, 8'h00, 8'h00, 4'h0, "Top-level enable gate");

        $display("--------------------------------------------");
        $display("SUMMARY: pass=%0d fail=%0d", pass_count, fail_count);
        $display("--------------------------------------------");

        if (fail_count != 0) begin
            $fatal(1, "Standalone verification failed");
        end

        $display("All standalone checks passed.");
        $finish;
    end

endmodule
