module aes #(
    parameter AES_DATA_WIDTH = 128,
    parameter AES_KEY_WIDTH = 128,
    parameter ECB = 0,
    parameter CTR = 1,
    parameter STATIC = 0,
    parameter DYNAMIC = 1
) (
    input clk,
    input aresetn,

    // AES master interface
    input [AES_DATA_WIDTH-1:0] plaintext,
    input [AES_KEY_WIDTH-1:0] key,
    output reg [AES_DATA_WIDTH-1:0] cyphertext,
    input start,
    output aes_ready,
    output reg stall,
    input stall1,
    output just_done,
    output reg just_done_reg,

    // AES slave interface
    input key_valid,
    output reg busy,
    output reg empty,
    output reg done
);

    localparam KEY_UPDATE = STATIC;
    localparam MODE = ECB;

    // round constants
    localparam [87:0] RC = {8'h36, 8'h1B, 8'h80, 8'h40, 8'h20, 8'h10, 8'h08, 8'h04, 8'h02, 8'h01, 8'h00};

    // initialising the S-Box memory
    reg [7:0] sbox [0:255];
    initial begin
        $readmemh("rtl/sbox.mem", sbox);
    end

    // galois function for multiplying 2
    function [7:0] gmul2;
        input [7:0] x;
        begin
            gmul2 = (x << 1) ^ (8'h1B & {8{x[7]}});
        end
    endfunction

    // galois function for multiplying 3
    function [7:0] gmul3; 
        input [7:0] x;
        begin 
            gmul3 = gmul2(x) ^ x;
        end
    endfunction

    // reg [7:0] subkey0 [15:0];
    reg [127:0] subkey0;
    reg [127:0] text0;
    reg [10:0] validR;

    // control
    assign aes_ready = (~validR[0]); // pipeline ready to take plaintext waiting for aes_start
    assign just_done = validR[9];
    reg [127:0] plaintext_reg;
    reg [1:0] stall_count;
    reg text_done;

    always@(posedge clk or negedge aresetn) begin 
        if(!aresetn) begin 
            validR <= 11'b0;
            busy <= 1'b0;
            done <= 1'b0;
            plaintext_reg <= 128'b0;
            just_done_reg <= 1'b0;
        end
        else if (!stall && !stall1) begin
            if (|validR) begin 
                busy <= 1'b1;
                empty <= 1'b0;
            end
            else begin 
                busy <= 1'b0;
                empty <= 1'b1;
            end
            validR[0] <= start;
            validR[10:1] <= validR[9:0];
            done <= validR[10];
            just_done_reg <= validR[9];
            plaintext_reg <= plaintext;
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            stall <= 1'b0;
            stall_count <= 2'b0;
        end
        else begin 
            if (validR[10]) begin 
                if (validR[9]) begin 
                    stall <= 1'b1;
                end
                stall_count <= 2'b0;
                text_done <= 1'b1;

            end
            else if (text_done) begin 
                stall_count <= stall_count + 1'b1;
            end
            if (stall_count == 2'b10) begin 
                text_done <= 1'b0;
                stall <= 1'b0;
            end
        end
    end

    
    // round 0
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text0 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[0]) begin
                text0 <= plaintext_reg ^ subkey0;
            end
        end
    end

    reg [127:0] subkey1;
    wire [7:0] sb1 [0:15];
    wire [7:0] sr1 [0:15];
    wire [7:0] mc1 [0:15];
    wire [7:0] ark1 [0:15];
    reg [127:0] text1;

    // round 1
    genvar i;
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb1_gen 
            assign sb1[i] = sbox[text0[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr1_gen
            assign sr1[4*i] = sb1[4*i];
            assign sr1[4*i+1] = sb1[4*((i+1) & 2'b11) + 1];
            assign sr1[4*i+2] = sb1[4*((i+2) & 2'b11) + 2];
            assign sr1[4*i+3] = sb1[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc1_gen
            assign mc1[4*i] = gmul2(sr1[4*i]) ^ gmul3(sr1[4*i+1]) ^ sr1[4*i+2] ^ sr1[4*i+3];
            assign mc1[4*i+1] = sr1[4*i] ^ gmul2(sr1[4*i+1]) ^ gmul3(sr1[4*i+2]) ^ sr1[4*i+3];
            assign mc1[4*i+2] = sr1[4*i] ^ sr1[4*i+1] ^ gmul2(sr1[4*i+2]) ^ gmul3(sr1[4*i+3]);
            assign mc1[4*i+3] = gmul3(sr1[4*i]) ^ sr1[4*i+1] ^ sr1[4*i+2] ^ gmul2(sr1[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark1_gen
            assign ark1[i] = mc1[i] ^ subkey1[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text1 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[1]) begin 
                text1 <= {ark1[0], ark1[1], ark1[2], ark1[3], ark1[4], ark1[5], ark1[6], ark1[7], ark1[8], ark1[9], ark1[10], ark1[11], ark1[12], ark1[13], ark1[14], ark1[15]};
            end
        end
    end

    // reg [7:0] subkey2 [0:15];
    reg [127:0] subkey2;
    wire [7:0] sb2 [0:15];
    wire [7:0] sr2 [0:15];
    wire [7:0] mc2 [0:15];
    wire [7:0] ark2 [0:15];
    reg [127:0] text2;

    // round 2
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb2_gen 
            assign sb2[i] = sbox[text1[127 - 8*i -: 8]];
            // assign sb1[i] = sbox[text0[8*i +: 8]];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr2_gen
            assign sr2[4*i] = sb2[4*i];
            assign sr2[4*i+1] = sb2[4*((i+1) & 2'b11) + 1];
            assign sr2[4*i+2] = sb2[4*((i+2) & 2'b11) + 2];
            assign sr2[4*i+3] = sb2[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc2_gen
            assign mc2[4*i] = gmul2(sr2[4*i]) ^ gmul3(sr2[4*i+1]) ^ sr2[4*i+2] ^ sr2[4*i+3];
            assign mc2[4*i+1] = sr2[4*i] ^ gmul2(sr2[4*i+1]) ^ gmul3(sr2[4*i+2]) ^ sr2[4*i+3];
            assign mc2[4*i+2] = sr2[4*i] ^ sr2[4*i+1] ^ gmul2(sr2[4*i+2]) ^ gmul3(sr2[4*i+3]);
            assign mc2[4*i+3] = gmul3(sr2[4*i]) ^ sr2[4*i+1] ^ sr2[4*i+2] ^ gmul2(sr2[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark2_gen
            assign ark2[i] = mc2[i] ^ subkey2[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text2 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[2]) begin 
                text2 <= {ark2[0], ark2[1], ark2[2], ark2[3], ark2[4], ark2[5], ark2[6], ark2[7], ark2[8], ark2[9], ark2[10], ark2[11], ark2[12], ark2[13], ark2[14], ark2[15]};
            end
        end
    end

    reg [127:0] subkey3;
    wire [7:0] sb3 [0:15];
    wire [7:0] sr3 [0:15];
    wire [7:0] mc3 [0:15];
    wire [7:0] ark3 [0:15];
    reg [127:0] text3;

    // round 3
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb3_gen 
            assign sb3[i] = sbox[text2[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr3_gen
            assign sr3[4*i] = sb3[4*i];
            assign sr3[4*i+1] = sb3[4*((i+1) & 2'b11) + 1];
            assign sr3[4*i+2] = sb3[4*((i+2) & 2'b11) + 2];
            assign sr3[4*i+3] = sb3[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc3_gen
            assign mc3[4*i] = gmul2(sr3[4*i]) ^ gmul3(sr3[4*i+1]) ^ sr3[4*i+2] ^ sr3[4*i+3];
            assign mc3[4*i+1] = sr3[4*i] ^ gmul2(sr3[4*i+1]) ^ gmul3(sr3[4*i+2]) ^ sr3[4*i+3];
            assign mc3[4*i+2] = sr3[4*i] ^ sr3[4*i+1] ^ gmul2(sr3[4*i+2]) ^ gmul3(sr3[4*i+3]);
            assign mc3[4*i+3] = gmul3(sr3[4*i]) ^ sr3[4*i+1] ^ sr3[4*i+2] ^ gmul2(sr3[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark3_gen
            assign ark3[i] = mc3[i] ^ subkey3[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text3 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[3]) begin 
                text3 <= {ark3[0], ark3[1], ark3[2], ark3[3], ark3[4], ark3[5], ark3[6], ark3[7], ark3[8], ark3[9], ark3[10], ark3[11], ark3[12], ark3[13], ark3[14], ark3[15]};
            end
        end
    end

    reg [127:0] subkey4;
    wire [7:0] sb4 [0:15];
    wire [7:0] sr4 [0:15];
    wire [7:0] mc4 [0:15];
    wire [7:0] ark4 [0:15];
    reg [127:0] text4;

    // round 4
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb4_gen 
            assign sb4[i] = sbox[text3[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr4_gen
            assign sr4[4*i] = sb4[4*i];
            assign sr4[4*i+1] = sb4[4*((i+1) & 2'b11) + 1];
            assign sr4[4*i+2] = sb4[4*((i+2) & 2'b11) + 2];
            assign sr4[4*i+3] = sb4[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc4_gen
            assign mc4[4*i] = gmul2(sr4[4*i]) ^ gmul3(sr4[4*i+1]) ^ sr4[4*i+2] ^ sr4[4*i+3];
            assign mc4[4*i+1] = sr4[4*i] ^ gmul2(sr4[4*i+1]) ^ gmul3(sr4[4*i+2]) ^ sr4[4*i+3];
            assign mc4[4*i+2] = sr4[4*i] ^ sr4[4*i+1] ^ gmul2(sr4[4*i+2]) ^ gmul3(sr4[4*i+3]);
            assign mc4[4*i+3] = gmul3(sr4[4*i]) ^ sr4[4*i+1] ^ sr4[4*i+2] ^ gmul2(sr4[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark4_gen
            assign ark4[i] = mc4[i] ^ subkey4[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text4 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[4]) begin 
                text4 <= {ark4[0], ark4[1], ark4[2], ark4[3], ark4[4], ark4[5], ark4[6], ark4[7], ark4[8], ark4[9], ark4[10], ark4[11], ark4[12], ark4[13], ark4[14], ark4[15]};
            end
        end
    end

    reg [127:0] subkey5;
    wire [7:0] sb5 [0:15];
    wire [7:0] sr5 [0:15];
    wire [7:0] mc5 [0:15];
    wire [7:0] ark5 [0:15];
    reg [127:0] text5;

    // round 5
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb5_gen 
            assign sb5[i] = sbox[text4[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr5_gen
            assign sr5[4*i] = sb5[4*i];
            assign sr5[4*i+1] = sb5[4*((i+1) & 2'b11) + 1];
            assign sr5[4*i+2] = sb5[4*((i+2) & 2'b11) + 2];
            assign sr5[4*i+3] = sb5[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc5_gen
            assign mc5[4*i] = gmul2(sr5[4*i]) ^ gmul3(sr5[4*i+1]) ^ sr5[4*i+2] ^ sr5[4*i+3];
            assign mc5[4*i+1] = sr5[4*i] ^ gmul2(sr5[4*i+1]) ^ gmul3(sr5[4*i+2]) ^ sr5[4*i+3];
            assign mc5[4*i+2] = sr5[4*i] ^ sr5[4*i+1] ^ gmul2(sr5[4*i+2]) ^ gmul3(sr5[4*i+3]);
            assign mc5[4*i+3] = gmul3(sr5[4*i]) ^ sr5[4*i+1] ^ sr5[4*i+2] ^ gmul2(sr5[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark5_gen
            assign ark5[i] = mc5[i] ^ subkey5[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text5 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[5]) begin 
                text5 <= {ark5[0], ark5[1], ark5[2], ark5[3], ark5[4], ark5[5], ark5[6], ark5[7], ark5[8], ark5[9], ark5[10], ark5[11], ark5[12], ark5[13], ark5[14], ark5[15]};
            end
        end
    end

    reg [127:0] subkey6;
    wire [7:0] sb6 [0:15];
    wire [7:0] sr6 [0:15];
    wire [7:0] mc6 [0:15];
    wire [7:0] ark6 [0:15];
    reg [127:0] text6;

    // round 6
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb6_gen 
            assign sb6[i] = sbox[text5[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr6_gen
            assign sr6[4*i] = sb6[4*i];
            assign sr6[4*i+1] = sb6[4*((i+1) & 2'b11) + 1];
            assign sr6[4*i+2] = sb6[4*((i+2) & 2'b11) + 2];
            assign sr6[4*i+3] = sb6[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc6_gen
            assign mc6[4*i] = gmul2(sr6[4*i]) ^ gmul3(sr6[4*i+1]) ^ sr6[4*i+2] ^ sr6[4*i+3];
            assign mc6[4*i+1] = sr6[4*i] ^ gmul2(sr6[4*i+1]) ^ gmul3(sr6[4*i+2]) ^ sr6[4*i+3];
            assign mc6[4*i+2] = sr6[4*i] ^ sr6[4*i+1] ^ gmul2(sr6[4*i+2]) ^ gmul3(sr6[4*i+3]);
            assign mc6[4*i+3] = gmul3(sr6[4*i]) ^ sr6[4*i+1] ^ sr6[4*i+2] ^ gmul2(sr6[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark6_gen
            assign ark6[i] = mc6[i] ^ subkey6[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text6 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[6]) begin 
                text6 <= {ark6[0], ark6[1], ark6[2], ark6[3], ark6[4], ark6[5], ark6[6], ark6[7], ark6[8], ark6[9], ark6[10], ark6[11], ark6[12], ark6[13], ark6[14], ark6[15]};
            end
        end
    end

    reg [127:0] subkey7;
    wire [7:0] sb7 [0:15];
    wire [7:0] sr7 [0:15];
    wire [7:0] mc7 [0:15];
    wire [7:0] ark7 [0:15];
    reg [127:0] text7;

    // round 7
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb7_gen 
            assign sb7[i] = sbox[text6[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr7_gen
            assign sr7[4*i] = sb7[4*i];
            assign sr7[4*i+1] = sb7[4*((i+1) & 2'b11) + 1];
            assign sr7[4*i+2] = sb7[4*((i+2) & 2'b11) + 2];
            assign sr7[4*i+3] = sb7[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc7_gen
            assign mc7[4*i] = gmul2(sr7[4*i]) ^ gmul3(sr7[4*i+1]) ^ sr7[4*i+2] ^ sr7[4*i+3];
            assign mc7[4*i+1] = sr7[4*i] ^ gmul2(sr7[4*i+1]) ^ gmul3(sr7[4*i+2]) ^ sr7[4*i+3];
            assign mc7[4*i+2] = sr7[4*i] ^ sr7[4*i+1] ^ gmul2(sr7[4*i+2]) ^ gmul3(sr7[4*i+3]);
            assign mc7[4*i+3] = gmul3(sr7[4*i]) ^ sr7[4*i+1] ^ sr7[4*i+2] ^ gmul2(sr7[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark7_gen
            assign ark7[i] = mc7[i] ^ subkey7[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text7 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[7]) begin 
                text7 <= {ark7[0], ark7[1], ark7[2], ark7[3], ark7[4], ark7[5], ark7[6], ark7[7], ark7[8], ark7[9], ark7[10], ark7[11], ark7[12], ark7[13], ark7[14], ark7[15]};
            end
        end
    end

    reg [127:0] subkey8;
    wire [7:0] sb8 [0:15];
    wire [7:0] sr8 [0:15];
    wire [7:0] mc8 [0:15];
    wire [7:0] ark8 [0:15];
    reg [127:0] text8;

    // round 8
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb8_gen 
            assign sb8[i] = sbox[text7[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr8_gen
            assign sr8[4*i] = sb8[4*i];
            assign sr8[4*i+1] = sb8[4*((i+1) & 2'b11) + 1];
            assign sr8[4*i+2] = sb8[4*((i+2) & 2'b11) + 2];
            assign sr8[4*i+3] = sb8[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc8_gen
            assign mc8[4*i] = gmul2(sr8[4*i]) ^ gmul3(sr8[4*i+1]) ^ sr8[4*i+2] ^ sr8[4*i+3];
            assign mc8[4*i+1] = sr8[4*i] ^ gmul2(sr8[4*i+1]) ^ gmul3(sr8[4*i+2]) ^ sr8[4*i+3];
            assign mc8[4*i+2] = sr8[4*i] ^ sr8[4*i+1] ^ gmul2(sr8[4*i+2]) ^ gmul3(sr8[4*i+3]);
            assign mc8[4*i+3] = gmul3(sr8[4*i]) ^ sr8[4*i+1] ^ sr8[4*i+2] ^ gmul2(sr8[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark8_gen
            assign ark8[i] = mc8[i] ^ subkey8[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text8 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[8]) begin 
                text8 <= {ark8[0], ark8[1], ark8[2], ark8[3], ark8[4], ark8[5], ark8[6], ark8[7], ark8[8], ark8[9], ark8[10], ark8[11], ark8[12], ark8[13], ark8[14], ark8[15]};
            end
        end
    end

    reg [127:0] subkey9;
    wire [7:0] sb9 [0:15];
    wire [7:0] sr9 [0:15];
    wire [7:0] mc9 [0:15];
    wire [7:0] ark9 [0:15];
    reg [127:0] text9;

    // round 9
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb9_gen 
            assign sb9[i] = sbox[text8[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr9_gen
            assign sr9[4*i] = sb9[4*i];
            assign sr9[4*i+1] = sb9[4*((i+1) & 2'b11) + 1];
            assign sr9[4*i+2] = sb9[4*((i+2) & 2'b11) + 2];
            assign sr9[4*i+3] = sb9[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: mc9_gen
            assign mc9[4*i] = gmul2(sr9[4*i]) ^ gmul3(sr9[4*i+1]) ^ sr9[4*i+2] ^ sr9[4*i+3];
            assign mc9[4*i+1] = sr9[4*i] ^ gmul2(sr9[4*i+1]) ^ gmul3(sr9[4*i+2]) ^ sr9[4*i+3];
            assign mc9[4*i+2] = sr9[4*i] ^ sr9[4*i+1] ^ gmul2(sr9[4*i+2]) ^ gmul3(sr9[4*i+3]);
            assign mc9[4*i+3] = gmul3(sr9[4*i]) ^ sr9[4*i+1] ^ sr9[4*i+2] ^ gmul2(sr9[4*i+3]);
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark9_gen
            assign ark9[i] = mc9[i] ^ subkey9[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            text9 <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[9]) begin 
                text9 <= {ark9[0], ark9[1], ark9[2], ark9[3], ark9[4], ark9[5], ark9[6], ark9[7], ark9[8], ark9[9], ark9[10], ark9[11], ark9[12], ark9[13], ark9[14], ark9[15]};
            end
        end
    end

    reg [127:0] subkey10;
    wire [7:0] sb10 [0:15];
    wire [7:0] sr10 [0:15];
    wire [7:0] ark10 [0:15];

    // round 10
    generate
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: sb10_gen 
            assign sb10[i] = sbox[text9[127 - 8*i -: 8]];
        end
    endgenerate
    
    generate 
        for (i=0; i<(AES_DATA_WIDTH/32); i=i+1) begin: sr10_gen
            assign sr10[4*i] = sb10[4*i];
            assign sr10[4*i+1] = sb10[4*((i+1) & 2'b11) + 1];
            assign sr10[4*i+2] = sb10[4*((i+2) & 2'b11) + 2];
            assign sr10[4*i+3] = sb10[4*((i+3) & 2'b11) + 3];
        end
    endgenerate

    generate 
        for (i=0; i<(AES_DATA_WIDTH/8); i=i+1) begin: ark10_gen
            assign ark10[i] = sr10[i] ^ subkey10[127-8*i -: 8];
        end
    endgenerate

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            cyphertext <= 128'b0;
        end
        else if(!stall && !stall1) begin 
            if (validR[10]) begin 
                cyphertext <= {ark10[0], ark10[1], ark10[2], ark10[3], ark10[4], ark10[5], ark10[6], ark10[7], ark10[8], ark10[9], ark10[10], ark10[11], ark10[12], ark10[13], ark10[14], ark10[15]};
            end
        end
    end

    // g function for key expansion
    function [31:0] g_func_key;
        input [31:0] x;
        input [7:0] rc;

        reg [7:0] y1, y2, y3, y4;
        begin 
            y1 = sbox[x[31:24]];
            y2 = sbox[x[23:16]];
            y3 = sbox[x[15:8]];
            y4 = sbox[x[7:0]];
            g_func_key = {rc, 8'b0, 8'b0, 8'b0} ^ {y2, y3, y4, y1};
        end
    endfunction

    function [127:0] next_subkey;
        input [127:0] key_in;
        input [7:0] rc;

        reg [31:0] w0, w1, w2, w3, w4, w5, w6, w7;
        begin 
            w0 = key_in[127:96];
            w1 = key_in[95:64];
            w2 = key_in[63:32];
            w3 = key_in[31:0];

            w4 = w0 ^ g_func_key(w3, rc);
            w5 = w1 ^ w4;
            w6 = w2 ^ w5;
            w7 = w3 ^ w6;

            next_subkey = {w4, w5, w6, w7};
        end
    endfunction

    // key expansion

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey0 <= 128'b0;
        end
        else if(!stall && !stall1 && key_valid) begin
            if (start) begin 
                subkey0 <= key;
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey1 <= 128'b0;
        end
        else if(!stall && !stall1 && key_valid) begin 
            if (validR[0]) begin 
                subkey1 <= next_subkey(subkey0, RC[15:8]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey2 <= 128'b0;
        end
        else if(!stall && !stall1 && key_valid) begin 
            if (validR[1]) begin 
                subkey2 <= next_subkey(subkey1, RC[23:16]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey3 <= 128'b0;
        end
        else if(!stall && !stall1 & key_valid) begin 
            if (validR[2]) begin 
                subkey3 <= next_subkey(subkey2, RC[31:24]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey4 <= 128'b0;
        end
        else if (!stall && !stall1 && key_valid) begin 
            if (validR[3]) begin 
                subkey4 <= next_subkey(subkey3, RC[39:32]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey5 <= 128'b0;
        end
        else if (!stall && !stall1 & key_valid) begin 
            if (validR[4]) begin 
                subkey5 <= next_subkey(subkey4, RC[47:40]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey6 <= 128'b0;
        end
        else if (!stall && !stall1 & key_valid) begin 
            if (validR[5]) begin 
                subkey6 <= next_subkey(subkey5, RC[55:48]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey7 <= 128'b0;
        end
        else if (!stall && !stall1 && key_valid) begin 
            if (validR[6]) begin 
                subkey7 <= next_subkey(subkey6, RC[63:56]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey8 <= 128'b0;
        end
        else if (!stall && !stall1 && key_valid) begin 
            if (validR[7]) begin 
                subkey8 <= next_subkey(subkey7, RC[71:64]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey9 <= 128'b0;
        end
        else if (!stall && !stall1 && key_valid) begin 
            if (validR[8]) begin 
                subkey9 <= next_subkey(subkey8, RC[79:72]);
            end
        end
    end

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            subkey10 <= 128'b0;
        end
        else if (!stall && !stall1 && key_valid) begin 
            if (validR[9]) begin 
                subkey10 <= next_subkey(subkey9, RC[87:80]);
            end
        end
    end

    
endmodule
