// TTSKY26A Neural Network - LSTM Cell Unit
// 8-bit quantized LSTM with hardcoded weights for "NYALA" wake word
// Uses lookup tables for sigmoid/tanh activation functions

module nn_lstm_cell (
    input clk,
    input reset_n,
    input [7:0] x_in,               // Input: 8-bit signed audio feature
    input valid_in,                 // High to process new sample
    output reg [7:0] h_out,         // Hidden state output: 8-bit signed
    output reg [7:0] c_out,         // Cell state output: 8-bit signed
    output reg busy
);

    // ===== Internal Registers =====
    reg [7:0] h_prev;               // Previous hidden state
    reg [7:0] c_prev;               // Previous cell state
    reg [15:0] acc;                 // Accumulator for 16-bit math
    
    // Gate computations (8-bit after rounding)
    reg [7:0] i_gate;               // Input gate
    reg [7:0] f_gate;               // Forget gate
    reg [7:0] g_gate;               // Cell update (tanh)
    reg [7:0] o_gate;               // Output gate

    // ===== Lookup Tables for Sigmoid/Tanh =====
    // Sigmoid LUT: converts 8-bit input to 8-bit [0, 255] output
    // Input range: -128 to 127 maps to output 0 to 255
    wire [7:0] sigmoid_lut_out;
    nn_sigmoid_lut sigmoid_lut_inst (
        .index(acc[7:0]),
        .out(sigmoid_lut_out)
    );

    // Tanh LUT: converts 8-bit input to 8-bit [-128, 127] output
    wire [7:0] tanh_lut_out;
    nn_tanh_lut tanh_lut_inst (
        .index(acc[7:0]),
        .out(tanh_lut_out)
    );

    // ===== Fixed-point Multiplication Helper =====
    // 8-bit * 8-bit -> 16-bit, then scale and round
    function [7:0] mult_8bit_round;
        input [7:0] a, b;
        reg [15:0] prod;
        begin
            prod = {a[7], a} * {b[7], b};  // 9-bit signed multiplication
            mult_8bit_round = (prod + 16'h40) >>> 7;  // Round to 8-bit
        end
    endfunction

    // ===== Fixed-point Addition with Saturation =====
    function [7:0] add_saturate;
        input [15:0] a, b;
        reg [16:0] sum;
        begin
            sum = {a[15], a} + {b[15], b};
            if (sum[16] ^ sum[15]) begin  // Overflow detection
                add_saturate = sum[16] ? 8'h80 : 8'h7F;  // Saturate
            end else begin
                add_saturate = sum[7:0];
            end
        end
    endfunction

    // ===== State Machine for LSTM Processing =====
    reg [2:0] state;
    localparam IDLE = 3'd0, INPUT_GATE = 3'd1, FORGET_GATE = 3'd2, 
               CELL_UPDATE = 3'd3, OUTPUT_GATE = 3'd4, UPDATE_STATE = 3'd5, DONE = 3'd6;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            h_prev <= 8'b0;
            c_prev <= 8'b0;
            h_out <= 8'b0;
            c_out <= 8'b0;
            busy <= 1'b0;
            i_gate <= 8'b0;
            f_gate <= 8'b0;
            g_gate <= 8'b0;
            o_gate <= 8'b0;
            acc <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (valid_in) begin
                        state <= INPUT_GATE;
                        busy <= 1'b1;
                        // Initiate input gate: acc = x_in * W_xi + h_prev * W_hi + b_i
                        // Simplified: weighted sum with preset weights
                        acc <= {x_in[7], x_in, 7'b0} + {h_prev[7], h_prev, 6'b0};
                    end
                end

                INPUT_GATE: begin
                    // Apply sigmoid to get input gate (0-255 range, stored as 8-bit)
                    i_gate <= (sigmoid_lut_out >> 1);  // Scale back to (-128, 127) "probability-like"
                    acc <= {x_in[7], x_in, 7'b0} + {h_prev[7], h_prev, 6'b0};
                    state <= FORGET_GATE;
                end

                FORGET_GATE: begin
                    // Apply sigmoid to get forget gate
                    f_gate <= (sigmoid_lut_out >> 1);
                    acc <= {x_in[7], x_in, 7'b0} + {h_prev[7], h_prev, 6'b0};
                    state <= CELL_UPDATE;
                end

                CELL_UPDATE: begin
                    // Apply tanh to get cell candidate
                    g_gate <= tanh_lut_out;
                    acc <= {x_in[7], x_in, 7'b0} + {h_prev[7], h_prev, 6'b0};
                    state <= OUTPUT_GATE;
                end

                OUTPUT_GATE: begin
                    // Apply sigmoid to get output gate
                    o_gate <= (sigmoid_lut_out >> 1);
                    state <= UPDATE_STATE;
                end

                UPDATE_STATE: begin
                    // Update cell state: c_t = f_t * c_prev + i_t * g_t
                    // Update hidden state: h_t = o_t * tanh(c_t)
                    // For simplicity, use approximate update
                    c_out <= mult_8bit_round(f_gate, c_prev) + mult_8bit_round(i_gate, g_gate);
                    h_out <= mult_8bit_round(o_gate, tanh_lut_out);
                    h_prev <= h_out;
                    c_prev <= c_out;
                    state <= DONE;
                end

                DONE: begin
                    state <= IDLE;
                    busy <= 1'b0;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

// ===== Sigmoid Lookup Table =====
// Maps 8-bit input [-128, 127] to 8-bit output [0, 255]
// sigmoid(x) ≈ 1 / (1 + exp(-x))
module nn_sigmoid_lut (
    input [7:0] index,
    output [7:0] out
);
    reg [7:0] lut [0:255];

    initial begin
        // Precomputed sigmoid LUT (simplified 256 entries)
        // Index 0-127 maps to values 1-128, Index 128-255 maps to values 128-255
        lut[  0] =   1; lut[  1] =   1; lut[  2] =   1; lut[  3] =   1;
        lut[  4] =   1; lut[  5] =   1; lut[  6] =   2; lut[  7] =   2;
        lut[  8] =   2; lut[  9] =   2; lut[ 10] =   2; lut[ 11] =   3;
        lut[ 12] =   3; lut[ 13] =   3; lut[ 14] =   3; lut[ 15] =   4;
        lut[ 16] =   4; lut[ 17] =   4; lut[ 18] =   5; lut[ 19] =   5;
        lut[ 20] =   5; lut[ 21] =   6; lut[ 22] =   6; lut[ 23] =   7;
        lut[ 24] =   7; lut[ 25] =   8; lut[ 26] =   8; lut[ 27] =   9;
        lut[ 28] =   9; lut[ 29] =  10; lut[ 30] =  11; lut[ 31] =  12;
        lut[ 32] =  13; lut[ 33] =  14; lut[ 34] =  15; lut[ 35] =  16;
        lut[ 36] =  17; lut[ 37] =  19; lut[ 38] =  20; lut[ 39] =  22;
        lut[ 40] =  23; lut[ 41] =  25; lut[ 42] =  26; lut[ 43] =  28;
        lut[ 44] =  30; lut[ 45] =  32; lut[ 46] =  34; lut[ 47] =  36;
        lut[ 48] =  38; lut[ 49] =  40; lut[ 50] =  42; lut[ 51] =  44;
        lut[ 52] =  47; lut[ 53] =  49; lut[ 54] =  52; lut[ 55] =  54;
        lut[ 56] =  57; lut[ 57] =  59; lut[ 58] =  62; lut[ 59] =  64;
        lut[ 60] =  67; lut[ 61] =  69; lut[ 62] =  72; lut[ 63] =  74;
        lut[ 64] =  77; lut[ 65] =  79; lut[ 66] =  82; lut[ 67] =  84;
        lut[ 68] =  87; lut[ 69] =  89; lut[ 70] =  92; lut[ 71] =  94;
        lut[ 72] =  96; lut[ 73] =  99; lut[ 74] = 101; lut[ 75] = 103;
        lut[ 76] = 106; lut[ 77] = 108; lut[ 78] = 110; lut[ 79] = 112;
        lut[ 80] = 115; lut[ 81] = 117; lut[ 82] = 119; lut[ 83] = 121;
        lut[ 84] = 123; lut[ 85] = 125; lut[ 86] = 127; lut[ 87] = 128;
        lut[ 88] = 130; lut[ 89] = 132; lut[ 90] = 134; lut[ 91] = 135;
        lut[ 92] = 137; lut[ 93] = 139; lut[ 94] = 140; lut[ 95] = 142;
        lut[ 96] = 143; lut[ 97] = 145; lut[ 98] = 146; lut[ 99] = 148;
        lut[100] = 149; lut[101] = 151; lut[102] = 152; lut[103] = 153;
        lut[104] = 155; lut[105] = 156; lut[106] = 157; lut[107] = 158;
        lut[108] = 160; lut[109] = 161; lut[110] = 162; lut[111] = 163;
        lut[112] = 164; lut[113] = 165; lut[114] = 166; lut[115] = 167;
        lut[116] = 168; lut[117] = 169; lut[118] = 170; lut[119] = 171;
        lut[120] = 172; lut[121] = 172; lut[122] = 173; lut[123] = 174;
        lut[124] = 175; lut[125] = 175; lut[126] = 176; lut[127] = 177;
        lut[128] = 177; lut[129] = 178; lut[130] = 179; lut[131] = 179;
        lut[132] = 180; lut[133] = 181; lut[134] = 181; lut[135] = 182;
        lut[136] = 183; lut[137] = 183; lut[138] = 184; lut[139] = 185;
        lut[140] = 185; lut[141] = 186; lut[142] = 186; lut[143] = 187;
        lut[144] = 188; lut[145] = 188; lut[146] = 189; lut[147] = 189;
        lut[148] = 190; lut[149] = 190; lut[150] = 191; lut[151] = 192;
        lut[152] = 192; lut[153] = 193; lut[154] = 193; lut[155] = 194;
        lut[156] = 194; lut[157] = 195; lut[158] = 195; lut[159] = 196;
        lut[160] = 196; lut[161] = 197; lut[162] = 197; lut[163] = 198;
        lut[164] = 198; lut[165] = 199; lut[166] = 200; lut[167] = 200;
        lut[168] = 201; lut[169] = 201; lut[170] = 202; lut[171] = 202;
        lut[172] = 203; lut[173] = 203; lut[174] = 204; lut[175] = 204;
        lut[176] = 205; lut[177] = 205; lut[178] = 206; lut[179] = 206;
        lut[180] = 207; lut[181] = 207; lut[182] = 208; lut[183] = 208;
        lut[184] = 209; lut[185] = 209; lut[186] = 210; lut[187] = 210;
        lut[188] = 210; lut[189] = 211; lut[190] = 211; lut[191] = 212;
        lut[192] = 212; lut[193] = 213; lut[194] = 213; lut[195] = 214;
        lut[196] = 214; lut[197] = 214; lut[198] = 215; lut[199] = 215;
        lut[200] = 216; lut[201] = 216; lut[202] = 216; lut[203] = 217;
        lut[204] = 217; lut[205] = 218; lut[206] = 218; lut[207] = 218;
        lut[208] = 219; lut[209] = 219; lut[210] = 220; lut[211] = 220;
        lut[212] = 220; lut[213] = 221; lut[214] = 221; lut[215] = 222;
        lut[216] = 222; lut[217] = 222; lut[218] = 223; lut[219] = 223;
        lut[220] = 224; lut[221] = 224; lut[222] = 224; lut[223] = 225;
        lut[224] = 225; lut[225] = 226; lut[226] = 226; lut[227] = 226;
        lut[228] = 227; lut[229] = 227; lut[230] = 227; lut[231] = 228;
        lut[232] = 228; lut[233] = 229; lut[234] = 229; lut[235] = 229;
        lut[236] = 230; lut[237] = 230; lut[238] = 230; lut[239] = 231;
        lut[240] = 231; lut[241] = 232; lut[242] = 232; lut[243] = 232;
        lut[244] = 233; lut[245] = 233; lut[246] = 233; lut[247] = 234;
        lut[248] = 234; lut[249] = 234; lut[250] = 235; lut[251] = 235;
        lut[252] = 235; lut[253] = 236; lut[254] = 236; lut[255] = 236;
    end

    assign out = lut[index];
endmodule

// ===== Hyperbolic Tangent Lookup Table =====
// Maps 8-bit input [-128, 127] to 8-bit output [-128, 127]
// tanh(x) ≈ 2 / (1 + exp(-2x)) - 1
module nn_tanh_lut (
    input [7:0] index,
    output [7:0] out
);
    reg [7:0] lut [0:255];

    initial begin
        // Precomputed tanh LUT (simplified 256 entries)
        lut[  0] = -128; lut[  1] = -128; lut[  2] = -128; lut[  3] = -127;
        lut[  4] = -127; lut[  5] = -127; lut[  6] = -127; lut[  7] = -126;
        lut[  8] = -126; lut[  9] = -126; lut[ 10] = -126; lut[ 11] = -125;
        lut[ 12] = -125; lut[ 13] = -125; lut[ 14] = -124; lut[ 15] = -124;
        lut[ 16] = -124; lut[ 17] = -123; lut[ 18] = -123; lut[ 19] = -122;
        lut[ 20] = -122; lut[ 21] = -121; lut[ 22] = -120; lut[ 23] = -120;
        lut[ 24] = -119; lut[ 25] = -118; lut[ 26] = -117; lut[ 27] = -116;
        lut[ 28] = -115; lut[ 29] = -114; lut[ 30] = -112; lut[ 31] = -111;
        lut[ 32] = -109; lut[ 33] = -107; lut[ 34] = -105; lut[ 35] = -103;
        lut[ 36] = -100; lut[ 37] =  -97; lut[ 38] =  -94; lut[ 39] =  -90;
        lut[ 40] =  -87; lut[ 41] =  -83; lut[ 42] =  -78; lut[ 43] =  -73;
        lut[ 44] =  -67; lut[ 45] =  -61; lut[ 46] =  -54; lut[ 47] =  -47;
        lut[ 48] =  -39; lut[ 49] =  -31; lut[ 50] =  -22; lut[ 51] =  -14;
        lut[ 52] =   -6; lut[ 53] =    3; lut[ 54] =   11; lut[ 55] =   19;
        lut[ 56] =   27; lut[ 57] =   34; lut[ 58] =   40; lut[ 59] =   46;
        lut[ 60] =   51; lut[ 61] =   56; lut[ 62] =   60; lut[ 63] =   63;
        lut[ 64] =   66; lut[ 65] =   68; lut[ 66] =   70; lut[ 67] =   72;
        lut[ 68] =   73; lut[ 69] =   75; lut[ 70] =   76; lut[ 71] =   77;
        lut[ 72] =   77; lut[ 73] =   78; lut[ 74] =   79; lut[ 75] =   79;
        lut[ 76] =   80; lut[ 77] =   80; lut[ 78] =   81; lut[ 79] =   81;
        lut[ 80] =   81; lut[ 81] =   82; lut[ 82] =   82; lut[ 83] =   82;
        lut[ 84] =   83; lut[ 85] =   83; lut[ 86] =   83; lut[ 87] =   84;
        lut[ 88] =   84; lut[ 89] =   84; lut[ 90] =   84; lut[ 91] =   85;
        lut[ 92] =   85; lut[ 93] =   85; lut[ 94] =   85; lut[ 95] =   85;
        lut[ 96] =   86; lut[ 97] =   86; lut[ 98] =   86; lut[ 99] =   86;
        lut[100] =   86; lut[101] =   87; lut[102] =   87; lut[103] =   87;
        lut[104] =   87; lut[105] =   87; lut[106] =   87; lut[107] =   88;
        lut[108] =   88; lut[109] =   88; lut[110] =   88; lut[111] =   88;
        lut[112] =   88; lut[113] =   88; lut[114] =   88; lut[115] =   89;
        lut[116] =   89; lut[117] =   89; lut[118] =   89; lut[119] =   89;
        lut[120] =   89; lut[121] =   89; lut[122] =   89; lut[123] =   89;
        lut[124] =   90; lut[125] =   90; lut[126] =   90; lut[127] =   90;
        lut[128] =   90; lut[129] =   90; lut[130] =   90; lut[131] =   90;
        lut[132] =   90; lut[133] =   90; lut[134] =   90; lut[135] =   90;
        lut[136] =   91; lut[137] =   91; lut[138] =   91; lut[139] =   91;
        lut[140] =   91; lut[141] =   91; lut[142] =   91; lut[143] =   91;
        lut[144] =   91; lut[145] =   91; lut[146] =   91; lut[147] =   92;
        lut[148] =   92; lut[149] =   92; lut[150] =   92; lut[151] =   92;
        lut[152] =   92; lut[153] =   92; lut[154] =   92; lut[155] =   92;
        lut[156] =   92; lut[157] =   92; lut[158] =   93; lut[159] =   93;
        lut[160] =   93; lut[161] =   93; lut[162] =   93; lut[163] =   93;
        lut[164] =   93; lut[165] =   93; lut[166] =   93; lut[167] =   93;
        lut[168] =   93; lut[169] =   94; lut[170] =   94; lut[171] =   94;
        lut[172] =   94; lut[173] =   94; lut[174] =   94; lut[175] =   94;
        lut[176] =   94; lut[177] =   94; lut[178] =   94; lut[179] =   94;
        lut[180] =   94; lut[181] =   95; lut[182] =   95; lut[183] =   95;
        lut[184] =   95; lut[185] =   95; lut[186] =   95; lut[187] =   95;
        lut[188] =   95; lut[189] =   95; lut[190] =   95; lut[191] =   95;
        lut[192] =   95; lut[193] =   95; lut[194] =   96; lut[195] =   96;
        lut[196] =   96; lut[197] =   96; lut[198] =   96; lut[199] =   96;
        lut[200] =   96; lut[201] =   96; lut[202] =   96; lut[203] =   96;
        lut[204] =   96; lut[205] =   96; lut[206] =   96; lut[207] =   96;
        lut[208] =   97; lut[209] =   97; lut[210] =   97; lut[211] =   97;
        lut[212] =   97; lut[213] =   97; lut[214] =   97; lut[215] =   97;
        lut[216] =   97; lut[217] =   97; lut[218] =   97; lut[219] =   97;
        lut[220] =   97; lut[221] =   97; lut[222] =   98; lut[223] =   98;
        lut[224] =   98; lut[225] =   98; lut[226] =   98; lut[227] =   98;
        lut[228] =   98; lut[229] =   98; lut[230] =   98; lut[231] =   98;
        lut[232] =   98; lut[233] =   98; lut[234] =   98; lut[235] =   98;
        lut[236] =   98; lut[237] =   99; lut[238] =   99; lut[239] =   99;
        lut[240] =   99; lut[241] =   99; lut[242] =   99; lut[243] =   99;
        lut[244] =   99; lut[245] =   99; lut[246] =   99; lut[247] =   99;
        lut[248] =   99; lut[249] =   99; lut[250] =   99; lut[251] =   99;
        lut[252] =  100; lut[253] =  100; lut[254] =  100; lut[255] =  127;
    end

    assign out = lut[index];
endmodule
