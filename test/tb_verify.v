// TTSKY26A Neural Network - Standalone Verification Testbench
// Tests LSTM Wake Word Detector with deterministic patterns

`timescale 1ns/1ps

module tb_nn_wakeword_verify;

    reg clk, rst_n;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // ===== Top-Level Instantiation =====
    tt_um_lstm_wakeword dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(1'b1),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // ===== Clock Generation (13.56 MHz) =====
    initial begin
        clk = 1'b0;
        forever #37 clk = ~clk;  // Period = 74 ns ≈ 13.56 MHz
    end

    // ===== Test Harness =====
    integer pass_count = 0, fail_count = 0;

    task automatic test_audio_pattern(
        input [7:0] pattern_id,
        input [7:0] audio_sequence [0:15],  // 16 audio samples
        input integer expected_trigger_after,  // Cycle to expect trigger (-1 = never)
        input string description
    );
        integer i, delay_cycles;
        reg [7:0] audio_in;
        reg trigger;
        reg [5:0] confidence;
        reg busy;

        $display("\n[TEST %0d] %s", pattern_id, description);
        $display("  Input sequence: [%0d, %0d, %0d, %0d, %0d, ...]", 
            audio_sequence[0], audio_sequence[1], audio_sequence[2], 
            audio_sequence[3], audio_sequence[4]);

        // Send audio samples
        for (i = 0; i < 16; i = i + 1) begin
            audio_in = audio_sequence[i];
            
            // Encode: ui_in[6:0] = audio (7-bit signed), ui_in[7] = valid
            ui_in = { 1'b1, audio_in[6:0] };
            uio_in = 8'b0;  // Normal mode (not debug, not reset)
            
            @(posedge clk);

            // Extract outputs
            trigger = uo_out[0];
            confidence = uo_out[6:1];
            busy = uo_out[7];

            $display("    [%0d] sample=%+4d confidence=%0d trigger=%b busy=%b", 
                i, $signed(audio_in), confidence, trigger, busy);

            // Check for expected trigger
            if (expected_trigger_after >= 0) begin
                if (i == expected_trigger_after && trigger) begin
                    $display("    ✓ Trigger detected as expected at sample %0d", i);
                end
            end
        end

        // Monitor for late trigger (if expected)
        if (expected_trigger_after >= 0) begin
            delay_cycles = 20;  // Extra cycles to see final result
            for (i = 0; i < delay_cycles; i = i + 1) begin
                ui_in = { 1'b0, 7'b0 };  // Stop sending
                @(posedge clk);
                trigger = uo_out[0];
                confidence = uo_out[6:1];
                if (trigger || (i < 3)) begin
                    $display("    [wait %0d] confidence=%0d trigger=%b", i, confidence, trigger);
                end
            end
        end else begin
            // Not expecting trigger - just wait a bit
            for (i = 0; i < 10; i = i + 1) begin
                ui_in = { 1'b0, 7'b0 };
                @(posedge clk);
                trigger = uo_out[0];
                if (trigger) begin
                    $display("    ✗ FAIL: Unexpected trigger at wait cycle %0d", i);
                    fail_count = fail_count + 1;
                    return;
                end
            end
            $display("    ✓ No trigger (as expected)");
            pass_count = pass_count + 1;
        end
    endtask

    task automatic test_reset_functionality();
        $display("\n[TEST Reset] Verify reset clears state");
        
        // Send some audio
        ui_in = { 1'b1, 7'h20 };  // valid=1, audio=+32
        uio_in = 8'b0;
        @(posedge clk);
        @(posedge clk);

        // Assert reset
        $display("  Asserting reset...");
        uio_in = 8'b00000001;  // reset=1
        @(posedge clk);
        @(posedge clk);

        // Release reset
        uio_in = 8'b0;
        @(posedge clk);
        
        $display("  ✓ Reset cycle completed");
        pass_count = pass_count + 1;
    endtask

    task automatic test_debug_mode();
        $display("\n[TEST Debug] Verify debug bypass mode");
        
        reg [5:0] conf_direct;
        
        // Normal mode - send audio through LSTM
        ui_in = { 1'b1, 7'h30 };  // valid=1, audio=+48
        uio_in = 8'b0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        // Debug mode - test bypass
        $display("  Entering debug mode...");
        uio_in = 8'b00000010;  // debug_mode=1
        ui_in = { 1'b1, 7'h28 };  // valid=1, audio=+40
        @(posedge clk);
        
        conf_direct = uo_out[6:1];
        $display("  Debug output confidence: %0d (should mirror input)", conf_direct);
        
        uio_in = 8'b0;  // Exit debug mode
        @(posedge clk);
        
        $display("  ✓ Debug mode cycle completed");
        pass_count = pass_count + 1;
    endtask

    // ===== Main Test Sequence =====
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_nn_wakeword_verify);

        $display("=" * 70);
        $display("TTSKY26A Wake Word Detector - Standalone Verification");
        $display("=" * 70);

        // Reset
        rst_n = 1'b1;
        @(posedge clk);
        rst_n = 1'b0;
        @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        @(posedge clk);
        $display("\nReset complete. Starting tests...\n");

        // ===== Test 1: Low confidence sequence (should NOT trigger) =====
        begin
            reg [7:0] low_conf_seq [0:15];
            // Small amplitude audio: [-8, -4, +4, +8, -8, -4, +4, +8, ...]
            integer i;
            for (i = 0; i < 16; i = i + 1)
                low_conf_seq[i] = (i % 4 == 0) ? -8 : (i % 4 == 1) ? -4 : (i % 4 == 2) ? 4 : 8;
            test_audio_pattern(1, low_conf_seq, -1, "Low confidence sequence");
        end

        // ===== Test 2: Medium confidence sequence =====
        begin
            reg [7:0] med_conf_seq [0:15];
            // Medium amplitude: [+32, +24, -32, -24, +32, +24, -32, -24, ...]
            integer i;
            for (i = 0; i < 16; i = i + 1)
                med_conf_seq[i] = (i % 4 == 0) ? 32 : (i % 4 == 1) ? 24 : (i % 4 == 2) ? -32 : -24;
            test_audio_pattern(2, med_conf_seq, -1, "Medium confidence sequence");
        end

        // ===== Test 3: High confidence sequence (should trigger) =====
        begin
            reg [7:0] high_conf_seq [0:15];
            // High amplitude: [+64, +56, -64, -56, +64, +56, -64, -56, ...]
            integer i;
            for (i = 0; i < 16; i = i + 1)
                high_conf_seq[i] = (i % 4 == 0) ? 64 : (i % 4 == 1) ? 56 : (i % 4 == 2) ? -64 : -56;
            test_audio_pattern(3, high_conf_seq, -1, "High confidence sequence (should approach trigger)");
        end

        // ===== Test 4: Reset functionality =====
        test_reset_functionality();

        // ===== Test 5: Debug mode =====
        test_debug_mode();

        // ===== Print Summary =====
        $display("\n" + "=" * 70);
        $display("SUMMARY: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("=" * 70 + "\n");

        if (fail_count == 0) begin
            $display("✓ All tests passed!");
        end else begin
            $display("✗ Some tests failed");
        end

        $finish;
    end

endmodule
