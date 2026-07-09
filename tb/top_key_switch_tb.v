`timescale 1ns/1ps

module top_key_switch_tb;

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
    // MAIN EXECUTION: DYNAMIC KEY SWITCH & VERIFICATION
    // ========================================================
    reg [31:0] w0, w1, w2, w3;
    reg [31:0] read_val;
    integer i, error_count, old_key_count, new_key_count;
    time start_time, pause_time, resume_time, penalty_ns;

    time hw_start_time, hw_end_time, total_execution_ns;
    real throughput_gbps;

    initial begin
        $dumpfile("tb_dynamic_reconfig.vcd");
        $dumpvars(0, top_key_switch_tb);
        aresetn = 0; #100 aresetn = 1; #50;
        
        $display("========================================================");
        $display("[SYSTEM] Booting Dynamic Key Reconfiguration Test...");
        
        // 1. LOAD 100 BLOCKS (FIPS -> Zeros -> Seq)
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

        // 2. INITIAL KEY CONFIG
        write_ctrl(8'h08, 32'h09CF4F3C); write_ctrl(8'h0C, 32'hABF71588);
        write_ctrl(8'h10, 32'h28AED2A6); write_ctrl(8'h14, 32'h2B7E1516);
        write_ctrl(8'h00, 32'h0000_0004); // key_valid = 1

        // 3. START ENGINE
        $display("[CPU] Pulsing Start (Original Key)...");
        write_ctrl(8'h00, 32'h0000_0005);

        wait (U_TOP.U_AES_TOP.U_AXI_CTRL.start == 1'b1);
        hw_start_time = $time;

    // 4. WAIT FOR 45 BLOCKS, THEN INITIATE HITLESS SWAP
        wait (U_TOP.U_AES_TOP.U_AXI_AES_MASTER.data_count == 180);
        pause_time = $time; // <--- START THE STOPWATCH
        $display("\n[CPU] *** 45 BLOCKS READ. INITIATING HITLESS KEY SWAP ***");
        
        // Lock the active key in the AES core
        write_ctrl(8'h00, 32'h0000_0001); // start=1, key_valid=0 
        
        // Overwrite shadow registers (Hardware continues encrypting with old key!)
        write_ctrl(8'h08, 32'hFFFFFFFF); write_ctrl(8'h0C, 32'hFFFFFFFF); 
        write_ctrl(8'h10, 32'hFFFFFFFF); write_ctrl(8'h14, 32'hFFFFFFFF);
        
        // 5. LATCH NEW KEY
        write_ctrl(8'h00, 32'h0000_0005); // start=1, key_valid=1
        
        // STOP THE STOPWATCH & CALCULATE
        resume_time = $time;
        penalty_ns = resume_time - pause_time;
        $display("\n[METRICS] Shadow Register Update Overhead: %0d ns (%0d AXI-Lite clock cycles)", penalty_ns, penalty_ns/10);
        
        // Catch the 1-cycle pulse the exact nanosecond it happens!
        wait (U_TOP.U_AES_TOP.U_AXI_AES_MASTER.batch_done == 1'b1);
        hw_end_time = $time;
        
        // CALCULATE FINAL GBPS:
        total_execution_ns = hw_end_time - hw_start_time;
        throughput_gbps = 12800.0 / total_execution_ns; 
        
        $display("\n[METRICS] Total Execution Time: %0d ns", total_execution_ns);
        $display("[METRICS] Dynamic Key-Switch Throughput: %0.3f Gbps", throughput_gbps);

        // --------------------------------------------------------
        // WAIT FOR COMPLETION (THE ARCHITECTURALLY CORRECT WAY)
        // --------------------------------------------------------
        $display("[CPU] Polling Control Dashboard for Completion...");
        read_val = 32'b0;
        while ((read_val & 32'h0000_0008) == 0) begin
            #500; // Wait 500ns before polling again
            read_ctrl_silent(8'h04, read_val); 
        end
        write_ctrl(8'h00, 32'h0000_0004); // CPU clears the flags
                        
        // 6. VERIFY DATA TEARING
        $display("\n[VERIFICATION] Checking Blocks for Data Tearing...");
        error_count = 0; old_key_count = 0; new_key_count = 0;
        
        for (i = 0; i < 100; i = i + 1) begin
            read_mem((i*16) + 32'h00, w0); read_mem((i*16) + 32'h04, w1);
            read_mem((i*16) + 32'h08, w2); read_mem((i*16) + 32'h0C, w3);

            if (i % 3 == 0) begin // Pattern A
                if (w0 == 32'h196a0b32 && w1 == 32'hdc118597 && w2 == 32'h02dc09fb && w3 == 32'h3925841d) old_key_count = old_key_count + 1;
                else if (w0 == 32'hde389d0e && w1 == 32'h10ef618c && w2 == 32'he27dd84a && w3 == 32'h41f7f0df) new_key_count = new_key_count + 1;
                else error_count = error_count + 1;
            end 
            else if (i % 3 == 1) begin // Pattern B
                if (w0 == 32'hb91b546f && w1 == 32'h3e42f047 && w2 == 32'h1ab899b3 && w3 == 32'h7df76b0c) old_key_count = old_key_count + 1;
                else if (w0 == 32'h38bfc92c && w1 == 32'h89644845 && w2 == 32'h877d5fcd && w3 == 32'ha1f6258c) new_key_count = new_key_count + 1;
                else error_count = error_count + 1;
            end 
            else begin // Pattern C
                if (w0 == 32'hd6e4d64b && w1 == 32'h27d8d055 && w2 == 32'hc5c7573a && w3 == 32'h8df4e9aa) old_key_count = old_key_count + 1;
                else if (w0 == 32'h896a09f6 && w1 == 32'h51f69ac0 && w2 == 32'h4d2807a6 && w3 == 32'h0a90e5b7) new_key_count = new_key_count + 1;
                else error_count = error_count + 1;
            end
        end

        $display("========================================================");
        if (error_count == 0) begin
            $display(" [PASS] NO DATA TEARING DETECTED!");
            $display("        -> %0d Blocks encrypted flawlessly with ORIGINAL Key.", old_key_count);
            $display("        -> %0d Blocks encrypted flawlessly with NEW Key.", new_key_count);
        end else begin
            $display(" [FAIL] Found %0d corrupted blocks (Data Tearing Occurred!).", error_count);
        end
        $display("========================================================\n");

        #100 $finish; 
    end
    
endmodule
