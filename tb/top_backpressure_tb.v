`timescale 1ns/1ps

module top_backpressure_tb;

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


// ========================================================
    // MAIN EXECUTION: STEADY-STATE THROUGHPUT & VERIFICATION
    // ========================================================
    reg [31:0] read_val;
    integer i, error_count;
    time hw_start_time, hw_end_time, total_execution_ns;
    real throughput_gbps;

    // ========================================================
    // FAULT INJECTION: AXI BACKPRESSURE GENERATOR
    // ========================================================
    // The testbench acts as a "God Mode" controller, reaching directly 
    // into the memory module to hijack the ready signals.

    // reg [6:0] rand_val;
    always @(posedge clk) begin
        // rand_val <= $random % 100;
        #1;
        if (aresetn) begin
            if ($unsigned($random) % 100 < 50) begin
                // OVERRIDE: Force the memory to say "I am busy"
                force U_TOP.U_AXI_MEM.s_axi_a_awready = 1'b0;
                force U_TOP.U_AXI_MEM.s_axi_a_wready = 1'b0;
            end else begin
                // LET GO: Allow the memory's native logic to take control again
                release U_TOP.U_AXI_MEM.s_axi_a_awready;
                release U_TOP.U_AXI_MEM.s_axi_a_wready;
            end
        end
    end

    initial begin
        $dumpfile("top_backpressure_tb.vcd");
        $dumpvars(0, top_backpressure_tb);
        aresetn = 0;
        #100 aresetn = 1; #50;
        
        $display("========================================================");
        $display("[SYSTEM] Booting Steady-State Throughput Test...");
        
        // --------------------------------------------------------
        // 1. LOAD 100 BLOCKS (FIPS -> Zeros -> Seq)
        // --------------------------------------------------------
        $display("[CPU] Loading 100 Rotating Blocks into Memory...");
        for (i = 0; i < 100; i = i + 1) begin
            if (i % 3 == 0) begin
                write_mem((i*16) + 32'h00, 32'he0370734); write_mem((i*16) + 32'h04, 32'h313198a2);
                write_mem((i*16) + 32'h08, 32'h885a308d); write_mem((i*16) + 32'h0C, 32'h3243f6a8);
            end else if (i % 3 == 1) begin
                write_mem((i*16) + 32'h00, 32'h00000000); write_mem((i*16) + 32'h04, 32'h00000000);
                write_mem((i*16) + 32'h08, 32'h00000000); write_mem((i*16) + 32'h0C, 32'h00000000);
            end else begin
                write_mem((i*16) + 32'h00, 32'hccddeeff); write_mem((i*16) + 32'h04, 32'h8899aabb);
                write_mem((i*16) + 32'h08, 32'h44556677); write_mem((i*16) + 32'h0C, 32'h00112233);
            end
        end

        // --------------------------------------------------------
        // 2. CONFIGURE KEY & START HARDWARE
        // --------------------------------------------------------
        write_ctrl(8'h08, 32'h09CF4F3C); write_ctrl(8'h0C, 32'hABF71588);
        write_ctrl(8'h10, 32'h28AED2A6); write_ctrl(8'h14, 32'h2B7E1516);
        write_ctrl(8'h00, 32'h0000_0004); // key_valid = 1

        $display("[CPU] Pulsing Start...");
        
        write_ctrl(8'h00, 32'h0000_0005); // start=1, key_valid=1
        // Start the stopwatch the exact nanosecond the hardware registers the command
        wait (U_TOP.U_AES_TOP.U_AXI_CTRL.start == 1'b1);
        hw_start_time = $time;
        
        // --------------------------------------------------------
        // 3. WAIT FOR COMPLETION & STOP TIMER
        // --------------------------------------------------------
        wait (U_TOP.U_AES_TOP.U_AXI_AES_MASTER.batch_done == 1'b1);
        hw_end_time = $time;
        write_ctrl(8'h00, 32'h0000_0004); // CPU clears start flag

        // --------------------------------------------------------
        // 4. CALCULATE PERFORMANCE METRICS
        // --------------------------------------------------------
        total_execution_ns = hw_end_time - hw_start_time;
        throughput_gbps = 12800.0 / total_execution_ns; // 100 blocks * 128 bits = 12,800 bits
        
        $display("\n[METRICS] Total Execution Time: %0d ns", total_execution_ns);
        $display("[METRICS] Steady-State Throughput:  %0.3f Gbps", throughput_gbps);

        // --------------------------------------------------------
        // 5. HARDWARE VERIFICATION LOOP (CORRECTNESS CHECK)
        // --------------------------------------------------------
        $display("\n[VERIFICATION] Checking all 100 Ciphertext Blocks for absolute correctness...");
        error_count = 0;
        
        for (i = 0; i < 100; i = i + 1) begin
            if (i % 3 == 0) begin // Pattern A: FIPS
                read_mem((i*16) + 32'h00, read_val); if (read_val != 32'h196a0b32) error_count = error_count + 1;
                read_mem((i*16) + 32'h04, read_val); if (read_val != 32'hdc118597) error_count = error_count + 1;
                read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h02dc09fb) error_count = error_count + 1;
                read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h3925841d) error_count = error_count + 1;
            end else if (i % 3 == 1) begin // Pattern B: Zeros
                read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hb91b546f) error_count = error_count + 1;
                read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h3e42f047) error_count = error_count + 1;
                read_mem((i*16) + 32'h08, read_val); if (read_val != 32'h1ab899b3) error_count = error_count + 1;
                read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h7df76b0c) error_count = error_count + 1;
            end else begin // Pattern C: Sequential
                read_mem((i*16) + 32'h00, read_val); if (read_val != 32'hd6e4d64b) error_count = error_count + 1;
                read_mem((i*16) + 32'h04, read_val); if (read_val != 32'h27d8d055) error_count = error_count + 1;
                read_mem((i*16) + 32'h08, read_val); if (read_val != 32'hc5c7573a) error_count = error_count + 1;
                read_mem((i*16) + 32'h0C, read_val); if (read_val != 32'h8df4e9aa) error_count = error_count + 1;
            end
        end

        $display("========================================================");
        if (error_count == 0) begin
            $display(" [PASS] 100/100 BLOCKS MATCHED PERFECTLY!");
        end else begin
            $display(" [FAIL] Found %0d corrupted words.", error_count);
        end
        $display("========================================================\n");

        #100 $finish;
    end

endmodule
