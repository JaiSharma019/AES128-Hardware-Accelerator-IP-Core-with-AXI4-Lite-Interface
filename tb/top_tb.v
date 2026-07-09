`timescale 1ns/1ps

module top_tb;

    // ========================================================
    // PARAMETERS & SIGNALS
    // ========================================================
    parameter CTRL_ADDR_WIDTH = 8;
    parameter MEM_ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter AES_DATA_WIDTH = 128;
    parameter AES_KEY_WIDTH = 128;
    parameter TOTAL = 400;

    reg clk;
    reg aresetn;

    // AXI-Lite Slave (Control Dashboard)
    reg  [CTRL_ADDR_WIDTH-1:0] s_axi_ctrl_awaddr;
    reg                        s_axi_ctrl_awvalid;
    wire                       s_axi_ctrl_awready;
    reg  [DATA_WIDTH-1:0]      s_axi_ctrl_wdata;
    reg  [DATA_WIDTH/8-1:0]    s_axi_ctrl_wstrb;
    reg                        s_axi_ctrl_wvalid;
    wire                       s_axi_ctrl_wready;
    wire [1:0]                 s_axi_ctrl_bresp;
    wire                       s_axi_ctrl_bvalid;
    reg                        s_axi_ctrl_bready;
    reg  [CTRL_ADDR_WIDTH-1:0] s_axi_ctrl_araddr;
    reg                        s_axi_ctrl_arvalid;
    wire                       s_axi_ctrl_arready;
    wire [DATA_WIDTH-1:0]      s_axi_ctrl_rdata;
    wire                       s_axi_ctrl_rvalid;
    reg                        s_axi_ctrl_rready;
    wire [1:0]                 s_axi_ctrl_rresp;

    // AXI4 Slave (Memory Port B)
    reg  [MEM_ADDR_WIDTH-1:0]  s_axi_mem_b_awaddr;
    reg                        s_axi_mem_b_awvalid;
    wire                       s_axi_mem_b_awready;
    reg  [DATA_WIDTH-1:0]      s_axi_mem_b_wdata;
    reg  [DATA_WIDTH/8-1:0]    s_axi_mem_b_wstrb;
    reg                        s_axi_mem_b_wvalid;
    wire                       s_axi_mem_b_wready;
    wire [1:0]                 s_axi_mem_b_bresp;
    wire                       s_axi_mem_b_bvalid;
    reg                        s_axi_mem_b_bready;
    reg  [MEM_ADDR_WIDTH-1:0]  s_axi_mem_b_araddr;
    reg                        s_axi_mem_b_arvalid;
    wire                       s_axi_mem_b_arready;
    wire [DATA_WIDTH-1:0]      s_axi_mem_b_rdata;
    wire                       s_axi_mem_b_rvalid;
    reg                        s_axi_mem_b_rready;
    wire [1:0]                 s_axi_mem_b_rresp;

    // ========================================================
    // DUT INSTANTIATION
    // ========================================================
    top #(
        .CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
        .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .AES_DATA_WIDTH(AES_DATA_WIDTH),
        .AES_KEY_WIDTH(AES_KEY_WIDTH),
        .TOTAL(TOTAL)
    ) U_TOP (
        .clk(clk),
        .aresetn(aresetn),

        // Control Dashboard
        .s_axi_ctrl_awaddr(s_axi_ctrl_awaddr),
        .s_axi_ctrl_awvalid(s_axi_ctrl_awvalid),
        .s_axi_ctrl_awready(s_axi_ctrl_awready),
        .s_axi_ctrl_wdata(s_axi_ctrl_wdata),
        .s_axi_ctrl_wstrb(s_axi_ctrl_wstrb),
        .s_axi_ctrl_wvalid(s_axi_ctrl_wvalid),
        .s_axi_ctrl_wready(s_axi_ctrl_wready),
        .s_axi_ctrl_bresp(s_axi_ctrl_bresp),
        .s_axi_ctrl_bvalid(s_axi_ctrl_bvalid),
        .s_axi_ctrl_bready(s_axi_ctrl_bready),
        .s_axi_ctrl_araddr(s_axi_ctrl_araddr),
        .s_axi_ctrl_arvalid(s_axi_ctrl_arvalid),
        .s_axi_ctrl_arready(s_axi_ctrl_arready),
        .s_axi_ctrl_rdata(s_axi_ctrl_rdata),
        .s_axi_ctrl_rvalid(s_axi_ctrl_rvalid),
        .s_axi_ctrl_rready(s_axi_ctrl_rready),
        .s_axi_ctrl_rresp(s_axi_ctrl_rresp),

        // Memory Port B
        .s_axi_mem_b_awaddr(s_axi_mem_b_awaddr),
        .s_axi_mem_b_awvalid(s_axi_mem_b_awvalid),
        .s_axi_mem_b_awready(s_axi_mem_b_awready),
        .s_axi_mem_b_wdata(s_axi_mem_b_wdata),
        .s_axi_mem_b_wstrb(s_axi_mem_b_wstrb),
        .s_axi_mem_b_wvalid(s_axi_mem_b_wvalid),
        .s_axi_mem_b_wready(s_axi_mem_b_wready),
        .s_axi_mem_b_bresp(s_axi_mem_b_bresp),
        .s_axi_mem_b_bvalid(s_axi_mem_b_bvalid),
        .s_axi_mem_b_bready(s_axi_mem_b_bready),
        .s_axi_mem_b_araddr(s_axi_mem_b_araddr),
        .s_axi_mem_b_arvalid(s_axi_mem_b_arvalid),
        .s_axi_mem_b_arready(s_axi_mem_b_arready),
        .s_axi_mem_b_rdata(s_axi_mem_b_rdata),
        .s_axi_mem_b_rvalid(s_axi_mem_b_rvalid),
        .s_axi_mem_b_rready(s_axi_mem_b_rready),
        .s_axi_mem_b_rresp(s_axi_mem_b_rresp)
    );

    // ========================================================
    // CLOCK & RESET
    // ========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz Clock
    end

    // ========================================================
    // CPU TASKS (Control Dashboard)
    // ========================================================
    task write_ctrl(input [7:0] addr, input [31:0] data);
        reg aw_done, w_done, b_done;
    begin
        aw_done = 0; w_done = 0; b_done = 0; @(negedge clk);
        s_axi_ctrl_awaddr = addr; s_axi_ctrl_awvalid = 1;
        s_axi_ctrl_wdata = data;  s_axi_ctrl_wstrb = 4'b1111; s_axi_ctrl_wvalid = 1;
        s_axi_ctrl_bready = 1;

        while (!aw_done || !w_done || !b_done) begin
            @(posedge clk);
            if (!aw_done && s_axi_ctrl_awready) begin s_axi_ctrl_awvalid <= 0; aw_done = 1; end
            if (!w_done && s_axi_ctrl_wready)   begin s_axi_ctrl_wvalid <= 0; w_done = 1; end
            if (!b_done && s_axi_ctrl_bvalid)   begin s_axi_ctrl_bready <= 0; b_done = 1; end
        end
    end endtask

    task read_ctrl(input [7:0] addr);
        reg ar_done, r_done;
    begin
        ar_done = 0; r_done = 0; @(negedge clk);
        s_axi_ctrl_araddr = addr; s_axi_ctrl_arvalid = 1;
        s_axi_ctrl_rready = 1;

        while (!ar_done || !r_done) begin
            @(posedge clk);
            if (!ar_done && s_axi_ctrl_arready) begin s_axi_ctrl_arvalid <= 0; ar_done = 1; end
            if (!r_done && s_axi_ctrl_rvalid) begin 
                $display("[%0t ns] [CPU Read] Status Register [0x04] = %h", $time, s_axi_ctrl_rdata);
                s_axi_ctrl_rready <= 0; r_done = 1; 
            end
        end
    end endtask

    // ========================================================
    // CPU TASKS (Memory Port B)
    // ========================================================
    task write_mem(input [31:0] addr, input [31:0] data);
        reg aw_done, w_done, b_done;
    begin
        aw_done = 0; w_done = 0; b_done = 0; @(negedge clk);
        s_axi_mem_b_awaddr = addr; s_axi_mem_b_awvalid = 1;
        s_axi_mem_b_wdata = data;  s_axi_mem_b_wstrb = 4'b1111; s_axi_mem_b_wvalid = 1;
        s_axi_mem_b_bready = 1;

        while (!aw_done || !w_done || !b_done) begin
            @(posedge clk);
            if (!aw_done && s_axi_mem_b_awready) begin s_axi_mem_b_awvalid <= 0; aw_done = 1; end
            if (!w_done && s_axi_mem_b_wready)   begin s_axi_mem_b_wvalid <= 0; w_done = 1; end
            if (!b_done && s_axi_mem_b_bvalid)   begin s_axi_mem_b_bready <= 0; b_done = 1; end
        end
    end endtask

    task read_mem(input [31:0] addr, output [31:0] data_out);
        reg ar_done, r_done;
    begin
        ar_done = 0; r_done = 0; @(negedge clk);
        s_axi_mem_b_araddr = addr; s_axi_mem_b_arvalid = 1;
        s_axi_mem_b_rready = 1;

        while (!ar_done || !r_done) begin
            @(posedge clk);
            if (!ar_done && s_axi_mem_b_arready) begin s_axi_mem_b_arvalid <= 0; ar_done = 1; end
            if (!r_done && s_axi_mem_b_rvalid) begin 
                data_out = s_axi_mem_b_rdata;
                s_axi_mem_b_rready <= 0; r_done = 1; 
            end
        end
    end endtask

    task read_ctrl_silent(input [7:0] addr, output [31:0] data_out);
        reg ar_done, r_done;
    begin
        ar_done = 0; r_done = 0; @(negedge clk);
        s_axi_ctrl_araddr = addr; s_axi_ctrl_arvalid = 1;
        s_axi_ctrl_rready = 1;

        while (!ar_done || !r_done) begin
            @(posedge clk);
            if (!ar_done && s_axi_ctrl_arready) begin s_axi_ctrl_arvalid <= 0; ar_done = 1; end
            if (!r_done && s_axi_ctrl_rvalid) begin 
                data_out = s_axi_ctrl_rdata; // Return the data to the testbench variable!
                s_axi_ctrl_rready <= 0; r_done = 1; 
            end
        end
    end endtask

    // // ========================================================
    // // MAIN EXECUTION
    // // ========================================================
    // reg [31:0] read_val;

    // initial begin
    //     $dumpfile("top_tb.vcd");
    //     $dumpvars(0, top_tb);

    //     // 1. Initialize Signals
    //     aresetn = 0;
    //     s_axi_ctrl_awvalid = 0; s_axi_ctrl_wvalid = 0; s_axi_ctrl_bready = 0;
    //     s_axi_ctrl_arvalid = 0; s_axi_ctrl_rready = 0;
    //     s_axi_mem_b_awvalid = 0; s_axi_mem_b_wvalid = 0; s_axi_mem_b_bready = 0;
    //     s_axi_mem_b_arvalid = 0; s_axi_mem_b_rready = 0;

    //     #100 aresetn = 1;
    //     #50;

    //     $display("========================================================");
    //     $display("[SYSTEM] Booting Full Integrated SoC Testbench...");
        
    //     // --------------------------------------------------------
    //     // PHASE 1: CPU Loads Plaintexts into Memory (Port B)
    //     // --------------------------------------------------------
    //     $display("[CPU] Writing Plaintexts into Memory (Port B)...");
    //     // Block 1 (FIPS)
    //     write_mem(32'h00, 32'he0370734);
    //     write_mem(32'h04, 32'h313198a2);
    //     write_mem(32'h08, 32'h885a308d);
    //     write_mem(32'h0C, 32'h3243f6a8);
    //     // Block 2 (Zeros)
    //     write_mem(32'h10, 32'h00000000);
    //     write_mem(32'h14, 32'h00000000);
    //     write_mem(32'h18, 32'h00000000);
    //     write_mem(32'h1C, 32'h00000000);
    //     // Block 3 (Sequential)
    //     write_mem(32'h20, 32'hccddeeff);
    //     write_mem(32'h24, 32'h8899aabb);
    //     write_mem(32'h28, 32'h44556677);
    //     write_mem(32'h2C, 32'h00112233);

    //     // --------------------------------------------------------
    //     // PHASE 2: CPU Configures AES Control Dashboard
    //     // --------------------------------------------------------
    //     $display("[CPU] Programming AES-128 Key...");
    //     write_ctrl(8'h08, 32'h09CF4F3C);
    //     write_ctrl(8'h0C, 32'hABF71588);
    //     write_ctrl(8'h10, 32'h28AED2A6);
    //     write_ctrl(8'h14, 32'h2B7E1516);
        
    //     write_ctrl(8'h00, 32'h0000_0004); // Set key_valid bit

    //     // --------------------------------------------------------
    //     // PHASE 3: EXECUTION & MONITORING
    //     // --------------------------------------------------------
    //     $display("\n[CPU] Checking initial status...");
    //     read_ctrl(8'h04); // Expect 0x00000001 (Empty)

    //     $display("\n[CPU] Pulsing Start for 12-Word Batch...");
    //     write_ctrl(8'h00, 32'h0000_0005); // Set Start = 1 (and keep key_valid = 1)
        
    //     read_ctrl(8'h04); // Expect 0x00000003 or 0x00000002 (Busy)

    //     $display("[CPU] Waiting for DMA and AES to process...");
    //     // #5000; // Wait for the DMA to fetch, encrypt, and write everything back
    //     #25000;
    //     read_ctrl(8'h04); // Expect 0x00000009 (Done=1, Empty=1)
    //     write_ctrl(8'h00, 32'h0000_0004); // CPU clears the start/done flags

    //     // --------------------------------------------------------
    //     // PHASE 4: CPU Reads Back Cyphertext from Memory (Port B)
    //     // --------------------------------------------------------
    //     $display("\n========================================================");
    //     $display("[RESULTS] Reading Cyphertexts from Dual-Port Memory:");

    //     $display("\n--- Block 1 (FIPS-197) ---");
    //     read_mem(32'h0C, read_val); $display("   Word 3: %h (Expected: 3925841d)", read_val);
    //     read_mem(32'h08, read_val); $display("   Word 2: %h (Expected: 02dc09fb)", read_val);
    //     read_mem(32'h04, read_val); $display("   Word 1: %h (Expected: dc118597)", read_val);
    //     read_mem(32'h00, read_val); $display("   Word 0: %h (Expected: 196a0b32)", read_val);

    //     $display("\n--- Block 2 (All Zeros) ---");
    //     read_mem(32'h1C, read_val); $display("   Word 3: %h (Expected: 7df76b0c)", read_val);
    //     read_mem(32'h18, read_val); $display("   Word 2: %h (Expected: 1ab899b3)", read_val);
    //     read_mem(32'h14, read_val); $display("   Word 1: %h (Expected: 3e42f047)", read_val);
    //     read_mem(32'h10, read_val); $display("   Word 0: %h (Expected: b91b546f)", read_val);

    //     $display("\n--- Block 3 (Sequential) ---");
    //     read_mem(32'h2C, read_val); $display("   Word 3: %h (Expected: 8df4e9aa)", read_val);
    //     read_mem(32'h28, read_val); $display("   Word 2: %h (Expected: c5c7573a)", read_val);
    //     read_mem(32'h24, read_val); $display("   Word 1: %h (Expected: 27d8d055)", read_val);
    //     read_mem(32'h20, read_val); $display("   Word 0: %h (Expected: d6e4d64b)", read_val);
    //     $display("========================================================\n");

    //     #100 $finish;
    // end

    // ========================================================
    // MAIN EXECUTION (SELF-CHECKING)
    // ========================================================
    reg [31:0] read_val;
    integer i, error_count;
    time start_time, end_time, elapsed_time;

        integer old_key_count, new_key_count;


    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        aresetn = 0;
        s_axi_ctrl_awvalid = 0; s_axi_ctrl_wvalid = 0; s_axi_ctrl_bready = 0;
        s_axi_ctrl_arvalid = 0; s_axi_ctrl_rready = 0;
        s_axi_mem_b_awvalid = 0; s_axi_mem_b_wvalid = 0; s_axi_mem_b_bready = 0;
        s_axi_mem_b_arvalid = 0; s_axi_mem_b_rready = 0;

        #100 aresetn = 1;
        #50;

        $display("========================================================");
        $display("[SYSTEM] Booting 100-Block Stress Test...");
        
        // --------------------------------------------------------
        // 1. AUTOMATED BULK MEMORY LOAD
        // --------------------------------------------------------
        // $display("[CPU] Loading 100 FIPS blocks (400 words) into Memory...");
        // for (i = 0; i < 100; i = i + 1) begin
        //     write_mem((i*16) + 32'h00, 32'he0370734);
        //     write_mem((i*16) + 32'h04, 32'h313198a2);
        //     write_mem((i*16) + 32'h08, 32'h885a308d);
        //     write_mem((i*16) + 32'h0C, 32'h3243f6a8);
        // end
        $display("[CPU] Loading 100 Rotating Blocks (FIPS -> Zeros -> Seq)...");
        for (i = 0; i < 100; i = i + 1) begin
            if (i % 3 == 0) begin
                // Pattern A: FIPS
                write_mem((i*16) + 32'h00, 32'he0370734);
                write_mem((i*16) + 32'h04, 32'h313198a2);
                write_mem((i*16) + 32'h08, 32'h885a308d);
                write_mem((i*16) + 32'h0C, 32'h3243f6a8);
            end 
            else if (i % 3 == 1) begin
                // Pattern B: Zeros
                write_mem((i*16) + 32'h00, 32'h00000000);
                write_mem((i*16) + 32'h04, 32'h00000000);
                write_mem((i*16) + 32'h08, 32'h00000000);
                write_mem((i*16) + 32'h0C, 32'h00000000);
            end 
            else begin
                // Pattern C: Sequential
                write_mem((i*16) + 32'h00, 32'hccddeeff);
                write_mem((i*16) + 32'h04, 32'h8899aabb);
                write_mem((i*16) + 32'h08, 32'h44556677);
                write_mem((i*16) + 32'h0C, 32'h00112233);
            end
        end

        // --------------------------------------------------------
        // 2. CONFIGURATION
        // --------------------------------------------------------
        $display("[CPU] Programming AES-128 Key...");
        write_ctrl(8'h08, 32'h09CF4F3C);
        write_ctrl(8'h0C, 32'hABF71588);
        write_ctrl(8'h10, 32'h28AED2A6);
        write_ctrl(8'h14, 32'h2B7E1516);
        write_ctrl(8'h00, 32'h0000_0004); // Set key_valid bit

    //     // --------------------------------------------------------
    //     // 3. HARDWARE EXECUTION & AUTOMATED POLLING
    //     // --------------------------------------------------------
    //     $display("[CPU] Pulsing Start...");
        
    //     start_time = $time; // <--- START THE STOPWATCH
    //     write_ctrl(8'h00, 32'h0000_0005); 
        
    //     // Polling Loop: Keep checking the dashboard until Bit 3 (Done) is 1
    //     read_val = 32'b0;
    //     while ((read_val & 32'h0000_0008) == 0) begin
    //         #500; // Wait 500ns
    //         read_ctrl_silent(8'h04, read_val); // Read silently
    //     end
        
    //     end_time = $time; // <--- STOP THE STOPWATCH
    //     elapsed_time = end_time - start_time;
        
    //     $display("\n[SYSTEM] Hardware finished exactly in: %0t ns, %0t (start) %0t (end)", elapsed_time, start_time, end_time);
        
    //     write_ctrl(8'h00, 32'h0000_0004); // CPU clears the flags

    //     // --------------------------------------------------------
    //     // 4. AUTOMATED DATA VERIFICATION
    //     // --------------------------------------------------------
    //     // $display("\n[VERIFICATION] Checking all 100 Ciphertext Blocks...");
    //     // error_count = 0;
        
    //     // for (i = 0; i < 100; i = i + 1) begin
    //     //     read_mem((i*16) + 32'h00, read_val);
    //     //     if (read_val != 32'h196a0b32) error_count = error_count + 1;
            
    //     //     read_mem((i*16) + 32'h04, read_val);
    //     //     if (read_val != 32'hdc118597) error_count = error_count + 1;
            
    //     //     read_mem((i*16) + 32'h08, read_val);
    //     //     if (read_val != 32'h02dc09fb) error_count = error_count + 1;
            
    //     //     read_mem((i*16) + 32'h0C, read_val);
    //     //     if (read_val != 32'h3925841d) error_count = error_count + 1;
    //     // end
    //     $display("\n[VERIFICATION] Checking all 100 Ciphertext Blocks for independence...");
    //     error_count = 0;
        
    //     for (i = 0; i < 100; i = i + 1) begin
    //         if (i % 3 == 0) begin
    //             // Check Pattern A: FIPS
    //             read_mem((i*16) + 32'h00, read_val); if (read_val != 32'h196a0b32) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h04, read_val); if (read_val != 32'hdc118597) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h02dc09fb) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h3925841d) error_count = error_count + 1;
    //         end 
    //         else if (i % 3 == 1) begin
    //             // Check Pattern B: Zeros
    //             read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hb91b546f) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h3e42f047) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h1ab899b3) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h7df76b0c) error_count = error_count + 1;
    //         end 
    //         else begin
    //             // Check Pattern C: Sequential
    //             read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hd6e4d64b) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h27d8d055) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h08, read_val); if (read_val != 32'hc5c7573a) error_count = error_count + 1;
    //             read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h8df4e9aa) error_count = error_count + 1;
    //         end
    //     end

    //     $display("========================================================");
    //     if (error_count == 0) begin
    //         $display(" [PASS] 100/100 BLOCKS MATCHED PERFECTLY!");
    //         $display("        Zero data corruption during heavy backpressure.");
    //     end else begin
    //         $display(" [FAIL] Found %0d corrupted words.", error_count);
    //     end
    //     $display("========================================================\n");

    //     #100 $finish;
    // end

// // --------------------------------------------------------
//         // 3. HARDWARE EXECUTION & DYNAMIC KEY SWAP (PIPELINE DRAIN)
//         // --------------------------------------------------------
//         $display("[CPU] Pulsing Start (Original Key)...");
        
//         write_ctrl(8'h00, 32'h0000_0005); // start=1, key_valid=1
//         start_time = $time; 
        
//         #2000; // Let it encrypt the first ~45 blocks
        
//         $display("\n[CPU] *** PAUSING HARDWARE AT %0d ns ***", ($time-start_time));
//         write_ctrl(8'h00, 32'h0000_0001); // start=1, key_valid=0 (Initiate Pipeline Drain!)
        
//         #500; // Wait a few clock cycles for the AES pipeline to fully drain to memory
// --------------------------------------------------------
        // 3. HARDWARE EXECUTION & DYNAMIC KEY SWAP (PIPELINE DRAIN)
        // --------------------------------------------------------
        $display("[CPU] Pulsing Start (Original Key)...");
        write_ctrl(8'h00, 32'h0000_0005); // start=1, key_valid=1
        start_time = $time; 
        
        // --- THE UPGRADE: EVENT-DRIVEN TRIGGER ---
        // Instead of guessing #2000, wait exactly until the DMA fetches 180 words (45 blocks)
        wait (U_TOP.U_AES_TOP.U_AXI_AES_MASTER.data_count == 180); 
        // -----------------------------------------
        
        $display("\n[CPU] *** EXACTLY 45 BLOCKS READ! PAUSING HARDWARE AT %0d ns ***", ($time-start_time));
        write_ctrl(8'h00, 32'h0000_0001); // start=1, key_valid=0 (Initiate Pipeline Drain!)
        
        // #500; // Wait a few clock cycles for the AES pipeline to fully drain to memory
        
        $display("[CPU] Safely Overwriting AES Key in Dashboard...");
        
        $display("[CPU] Safely Overwriting AES Key in Dashboard...");
        write_ctrl(8'h08, 32'hFFFFFFFF); 
        write_ctrl(8'h0C, 32'hFFFFFFFF); 
        write_ctrl(8'h10, 32'hFFFFFFFF); 
        write_ctrl(8'h14, 32'hFFFFFFFF); 

        $display("[CPU] Resuming Hardware with New Key...");
        write_ctrl(8'h00, 32'h0000_0005); // start=1, key_valid=1 (Wake up Read FSM!)
        
        // Wait for the final batch_done signal
        read_val = 32'b0;
        while ((read_val & 32'h0000_0008) == 0) begin
            #500; 
            read_ctrl_silent(8'h04, read_val); 
        end
        end_time = $time;
        
$display("\n[VERIFICATION] Performing STRICT Mathematical Check on all 100 Blocks...");
        error_count = 0;
        old_key_count = 0;
        new_key_count = 0;
        
        for (i = 0; i < 100; i = i + 1) begin
            // ---------------------------------------------------------
            // ORIGINAL KEY CHECK (Blocks generated before the pause)
            // ---------------------------------------------------------
            if (i < 49) begin 
                if (i % 3 == 0) begin // Pattern A
                    read_mem((i*16) + 32'h00, read_val); if (read_val != 32'h196a0b32) error_count = error_count + 1;
                    read_mem((i*16) + 32'h04, read_val); if (read_val != 32'hdc118597) error_count = error_count + 1;
                    read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h02dc09fb) error_count = error_count + 1;
                    read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h3925841d) error_count = error_count + 1;
                end else if (i % 3 == 1) begin // Pattern B
                    read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hb91b546f) error_count = error_count + 1;
                    read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h3e42f047) error_count = error_count + 1;
                    read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h1ab899b3) error_count = error_count + 1;
                    read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h7df76b0c) error_count = error_count + 1;
                end else begin // Pattern C
                    read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hd6e4d64b) error_count = error_count + 1;
                    read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h27d8d055) error_count = error_count + 1;
                    read_mem((i*16) + 32'h08, read_val); if (read_val != 32'hc5c7573a) error_count = error_count + 1;
                    read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h8df4e9aa) error_count = error_count + 1;
                end
                
                if (error_count == 0) old_key_count = old_key_count + 1;
            end 
            // ---------------------------------------------------------
            // NEW KEY CHECK (Blocks generated after the pause)
            // ---------------------------------------------------------
            // else if (i > 55) begin 
            //     if (i % 3 == 0) begin // Pattern A (New Key)
            //         read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hcd2fae9b) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h0772718e) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h3d7265be) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h6828b6d8) error_count = error_count + 1;
            //     end else if (i % 3 == 1) begin // Pattern B (New Key)
            //         read_mem((i*16) + 32'h00, read_val); if (read_val != 32'h6023cb43) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h04, read_val); if (read_val != 32'he75c44ea) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h08, read_val); if (read_val != 32'hfa736200) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h84f3ebf2) error_count = error_count + 1;
            //     end else begin // Pattern C (New Key)
            //         read_mem((i*16) + 32'h00, read_val); if (read_val != 32'he86c8f10) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h04, read_val); if (read_val != 32'hd8e02d6b) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h08, read_val); if (read_val != 32'hb5dfad94) error_count = error_count + 1;
            //         read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h86ab5158) error_count = error_count + 1;
            //     end
            // ---------------------------------------------------------
            // NEW KEY CHECK (Blocks generated after the pause)
            // ---------------------------------------------------------
            else if (i >= 49) begin 
                if (i % 3 == 0) begin // Pattern A (New Key)
                    read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hde389d0e) error_count = error_count + 1;
                    read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h10ef618c) error_count = error_count + 1;
                    read_mem((i*16) + 32'h08, read_val); if (read_val != 32'he27dd84a) error_count = error_count + 1;
                    read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h41f7f0df) error_count = error_count + 1;
                end else if (i % 3 == 1) begin // Pattern B (New Key)
                    read_mem((i*16) + 32'h00, read_val); if (read_val != 32'h38bfc92c) error_count = error_count + 1;
                    read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h89644845) error_count = error_count + 1;
                    read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h877d5fcd) error_count = error_count + 1;
                    read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'ha1f6258c) error_count = error_count + 1;
                end else begin // Pattern C (New Key)
                    read_mem((i*16) + 32'h00, read_val); if (read_val != 32'h896a09f6) error_count = error_count + 1;
                    read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h51f69ac0) error_count = error_count + 1;
                    read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h4d2807a6) error_count = error_count + 1;
                    read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h0a90e5b7) error_count = error_count + 1;
                end
                
                if (error_count == 0) new_key_count = new_key_count + 1;
            end
        end

        $display("========================================================");
        if (error_count == 0) begin
            $display(" [PASS] NO DATA TEARING DETECTED!");
            $display("        -> %0d Blocks strictly matched ORIGINAL Key.", old_key_count);
            $display("        -> %0d Blocks strictly matched NEW Key.", new_key_count);
        end else begin
            $display(" [FAIL] Found %0d corrupted words (Data Tearing Occurred!).", error_count);
        end
        $display("========================================================\n");

// ---------------------------------------------------------
        // GOLDEN MODEL DEBUGGER
        // ---------------------------------------------------------
        $display("\n[DEBUG] Let's see what the hardware ACTUALLY produced for the New Key:");
        
        $display("--- Pattern A (FIPS) Block 96 ---");
        read_mem((96*16) + 32'h00, read_val); $display("Word 0: %h", read_val);
        read_mem((96*16) + 32'h04, read_val); $display("Word 1: %h", read_val);
        read_mem((96*16) + 32'h08, read_val); $display("Word 2: %h", read_val);
        read_mem((96*16) + 32'h0C, read_val); $display("Word 3: %h", read_val);

        $display("--- Pattern B (Zeros) Block 97 ---");
        read_mem((97*16) + 32'h00, read_val); $display("Word 0: %h", read_val);
        read_mem((97*16) + 32'h04, read_val); $display("Word 1: %h", read_val);
        read_mem((97*16) + 32'h08, read_val); $display("Word 2: %h", read_val);
        read_mem((97*16) + 32'h0C, read_val); $display("Word 3: %h", read_val);
        
        $display("--- Pattern C (Seq) Block 98 ---");
        read_mem((98*16) + 32'h00, read_val); $display("Word 0: %h", read_val);
        read_mem((98*16) + 32'h04, read_val); $display("Word 1: %h", read_val);
        read_mem((98*16) + 32'h08, read_val); $display("Word 2: %h", read_val);
        read_mem((98*16) + 32'h0C, read_val); $display("Word 3: %h", read_val);

        #100 $finish; // <--- The magic command to stop the simulation!
                end

    // ========================================================
    // AUTOMATED PERFORMANCE METRICS TRACKER
    // ========================================================
    time hw_start_time, first_write_time, hw_end_time;
    time latency_ns, total_execution_ns;
    real throughput_gbps;

    initial begin
        // 1. Wait for the hardware to wake up
        wait (U_TOP.U_AES_TOP.U_AXI_CTRL.start == 1'b1);
        hw_start_time = $time;

        // 2. Wait for the FIRST ciphertext to drop onto the bus
        wait (U_TOP.U_AES_TOP.U_AXI_AES_MASTER.m_axi_wvalid == 1'b1);
        first_write_time = $time;
        
        // Calculate and print Latency (No division needed, $time is already in ns!)
        latency_ns = first_write_time - hw_start_time;
        $display("\n========================================================");
        $display("[METRICS] Initial System Latency: %0d ns (%0d clock cycles)", latency_ns, latency_ns/10);

        // 3. Wait for the hardware to completely finish the 400-word job
        wait (U_TOP.U_AES_TOP.U_AXI_AES_MASTER.batch_done == 1'b1);
        hw_end_time = $time;

        // Calculate and print Throughput
        // 400 words * 32 bits = 12,800 bits.
        total_execution_ns = hw_end_time - hw_start_time;
        throughput_gbps = 12800.0 / total_execution_ns;
        
        $display("[METRICS] Total Execution Time: %0d ns", total_execution_ns);
        $display("[METRICS] Hardware Throughput:  %0.3f Gbps", throughput_gbps);
        $display("========================================================\n");
    end

endmodule