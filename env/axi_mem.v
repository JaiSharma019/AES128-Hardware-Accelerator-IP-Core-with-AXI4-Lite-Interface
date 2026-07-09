`timescale 1ns/1ps

module axi_mem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter AES_DATA_WIDTH = 128,
    parameter AES_KEY_WIDTH = 128
) (
    // global
    input clk,
    input aresetn,

    // PORT A
    // write address
    input [ADDR_WIDTH-1:0] s_axi_a_awaddr,
    input s_axi_a_awvalid,
    output s_axi_a_awready,

    // write data
    input [DATA_WIDTH-1:0] s_axi_a_wdata,
    input [DATA_WIDTH/8-1:0] s_axi_a_wstrb,
    input s_axi_a_wvalid,
    output s_axi_a_wready,

    // write response
    output reg [1:0] s_axi_a_bresp,
    output reg s_axi_a_bvalid,
    input s_axi_a_bready,

    // read address
    input [ADDR_WIDTH-1:0] s_axi_a_araddr,
    input s_axi_a_arvalid,
    output s_axi_a_arready,

    // read data
    output reg [DATA_WIDTH-1:0] s_axi_a_rdata,
    output reg s_axi_a_rvalid,
    input s_axi_a_rready,
    output reg [1:0] s_axi_a_rresp,

    // PORT B
    // write address
    input [ADDR_WIDTH-1:0] s_axi_b_awaddr,
    input s_axi_b_awvalid,
    output s_axi_b_awready,

    // write data
    input [DATA_WIDTH-1:0] s_axi_b_wdata,
    input [DATA_WIDTH/8-1:0] s_axi_b_wstrb,
    input s_axi_b_wvalid,
    output s_axi_b_wready,

    // write response
    output reg [1:0] s_axi_b_bresp,
    output reg s_axi_b_bvalid,
    input s_axi_b_bready,

    // read address
    input [ADDR_WIDTH-1:0] s_axi_b_araddr,
    input s_axi_b_arvalid,
    output s_axi_b_arready,

    // read data
    output reg [DATA_WIDTH-1:0] s_axi_b_rdata,
    output reg s_axi_b_rvalid,
    input s_axi_b_rready,
    output reg [1:0] s_axi_b_rresp
);

    localparam OKAY = 2'b00;
    localparam EXOKAY = 2'b01;
    localparam SLVERR = 2'b10;
    localparam DECERR = 2'b11;

    // register bank
    reg [31:0] mem [1023:0];

    reg [DATA_WIDTH-1:0] a_wdata;
    reg [DATA_WIDTH/8-1:0] a_wstrb;
    reg [ADDR_WIDTH-1:0] a_awaddr;
    reg [DATA_WIDTH-1:0] b_wdata;
    reg [DATA_WIDTH/8-1:0] b_wstrb;
    reg [ADDR_WIDTH-1:0] b_awaddr;

    reg a_w_hs;
    reg a_aw_hs;

    reg b_w_hs;
    reg b_aw_hs;

    assign s_axi_a_awready = (~a_aw_hs | (s_axi_a_bvalid & s_axi_a_bready)) & aresetn;
    assign s_axi_a_wready = (~a_w_hs | (s_axi_a_bvalid & s_axi_a_bready)) & aresetn;
    assign s_axi_a_arready = ((~s_axi_a_rvalid) | s_axi_a_rready) & aresetn;
    // // ========================================================
    // // BACKPRESSURE RANDOMIZER LOGIC
    // // ========================================================
    // // Generate a new random number every clock cycle
    // reg [6:0] rand_val;
    // always @(posedge clk) rand_val <= $random % 100;

    // // Create a 50% chance to stall the AXI Write and Address channels
    // wire rand_aw_stall = (rand_val < 50); 
    // wire rand_w_stall  = (rand_val < 50);

    // // Apply the random stalls to the original ready logic
    // assign s_axi_a_awready = (~a_aw_hs || (s_axi_a_bvalid & s_axi_a_bready)) & aresetn & ~rand_aw_stall;//|| s_axi_a_wvalid && s_axi_a_wready
    // assign s_axi_a_wready  = (~a_w_hs || (s_axi_a_bvalid & s_axi_a_bready)) & aresetn & ~rand_w_stall;//|| s_axi_a_awvalid && s_axi_a_awready
    
    // // We leave the Read channel fast to ensure the pipeline fills up quickly before we choke the exit
    // assign s_axi_a_arready = ((~s_axi_a_rvalid) | s_axi_a_rready) & aresetn;
    // // -------

    assign s_axi_b_awready = (~b_aw_hs || s_axi_b_wvalid && s_axi_b_wready) & aresetn;
    assign s_axi_b_wready = (~b_w_hs || s_axi_b_awvalid && s_axi_b_awready) & aresetn;
    assign s_axi_b_arready = ((~s_axi_b_rvalid) | s_axi_b_rready) & aresetn;

    // PORT A
    // write address
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            a_awaddr <= {ADDR_WIDTH{1'b0}};
            a_aw_hs <= 1'b0;
        end
        else begin 
            if (s_axi_a_awvalid && s_axi_a_awready && !a_aw_hs) begin 
                a_awaddr <= s_axi_a_awaddr;
                a_aw_hs <= 1'b1;
            end
            if (s_axi_a_bvalid && s_axi_a_bready) begin 
                a_aw_hs <= 1'b0;
            end
        end
    end

    // write data 
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            a_wdata <= {DATA_WIDTH{1'b0}};
            a_wstrb <= {DATA_WIDTH/8{1'b0}};
            a_w_hs <= 1'b0;
        end
        else begin 
            if (s_axi_a_wvalid && s_axi_a_wready && !a_w_hs) begin 
                a_wdata <= s_axi_a_wdata;
                a_wstrb <= s_axi_a_wstrb;
                a_w_hs <= 1'b1;
            end
            if (s_axi_a_bvalid && s_axi_a_bready) begin 
                a_w_hs <= 1'b0;
            end 
        end
    end

    wire a_write;
    assign a_write = a_aw_hs && a_w_hs && ~s_axi_a_bvalid;
    wire a_overlap;
    assign a_overlap = s_axi_a_awvalid && s_axi_a_awready && s_axi_a_wvalid && s_axi_a_wready;

    wire [ADDR_WIDTH-1:0] curr_a_awaddr;
    wire [DATA_WIDTH-1:0] curr_a_wdata;
    wire [3:0] curr_a_wstrb;
    assign curr_a_awaddr = (a_overlap) ? s_axi_a_awaddr : a_awaddr;
    assign curr_a_wdata = (a_overlap) ? s_axi_a_wdata : a_wdata;
    assign curr_a_wstrb = (a_overlap) ? s_axi_a_wstrb : a_wstrb;

    // address decoding and write data
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            s_axi_a_bvalid <= 1'b0;
            s_axi_a_bresp <= OKAY;
        end
        else begin 
            if (s_axi_a_bvalid && s_axi_a_bready) begin 
                s_axi_a_bvalid <= 1'b0;
            end

            if (a_write || a_overlap) begin
                if (curr_a_awaddr < 32'h00001000) begin 
                    if (curr_a_wstrb[0]) mem[curr_a_awaddr[11:2]][7:0] <= curr_a_wdata[7:0];
                    if (curr_a_wstrb[1]) mem[curr_a_awaddr[11:2]][15:8] <= curr_a_wdata[15:8];
                    if (curr_a_wstrb[2]) mem[curr_a_awaddr[11:2]][23:16] <= curr_a_wdata[23:16];
                    if (curr_a_wstrb[3]) mem[curr_a_awaddr[11:2]][31:24] <= curr_a_wdata[31:24];
                    s_axi_a_bresp <= OKAY;
                end
                else begin 
                    s_axi_a_bresp <= SLVERR;
                end
                s_axi_a_bvalid <= 1'b1;
            end            
        end
    end

    // address decoding and read data
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            // b_ar_hs <= 1'b0;
            s_axi_a_rdata <= {DATA_WIDTH{1'b0}};
            s_axi_a_rvalid <= 1'b0;
            s_axi_a_rresp <= OKAY;
        end
        else begin 
            if (s_axi_a_rvalid && s_axi_a_rready) begin 
                s_axi_a_rvalid <= 1'b0;
            end

            if (s_axi_a_arvalid && s_axi_a_arready ) begin 
                if (s_axi_a_araddr < 32'h00001000) begin 
                    s_axi_a_rdata <= mem[s_axi_a_araddr[11:2]];
                    s_axi_a_rresp <= OKAY;
                end
                else begin 
                    s_axi_a_rresp <= SLVERR;
                    s_axi_a_rdata <= {DATA_WIDTH{1'b0}};
                end
                s_axi_a_rvalid <= 1'b1;
            end
            
        end
    end

    // PORT B
    // write address
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            b_awaddr <= {ADDR_WIDTH{1'b0}};
            b_aw_hs <= 1'b0;
        end
        else begin 
            if (s_axi_b_awvalid && s_axi_b_awready && !b_aw_hs) begin 
                b_awaddr <= s_axi_b_awaddr;
                b_aw_hs <= 1'b1;
            end
            if (s_axi_b_bvalid && s_axi_b_bready) begin 
                b_aw_hs <= 1'b0;
            end
        end
    end

    // write data 
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            b_wdata <= {DATA_WIDTH{1'b0}};
            b_wstrb <= {DATA_WIDTH/8{1'b0}};
            b_w_hs <= 1'b0;
        end
        else begin 
            if (s_axi_b_wvalid && s_axi_b_wready && !b_w_hs) begin 
                b_wdata <= s_axi_b_wdata;
                b_wstrb <= s_axi_b_wstrb;
                b_w_hs <= 1'b1;
            end
            if (s_axi_b_bvalid && s_axi_b_bready) begin 
                b_w_hs <= 1'b0;
            end 
        end
    end

    wire b_write;
    assign b_write = b_aw_hs && b_w_hs && ~s_axi_b_bvalid;
    wire b_overlap;
    assign b_overlap = s_axi_b_awvalid && s_axi_b_awready && s_axi_b_wvalid && s_axi_b_wready;

    wire [ADDR_WIDTH-1:0] curr_b_awaddr;
    wire [DATA_WIDTH-1:0] curr_b_wdata;
    wire [3:0] curr_b_wstrb;
    assign curr_b_awaddr = (b_overlap) ? s_axi_b_awaddr : b_awaddr;
    assign curr_b_wdata = (b_overlap) ? s_axi_b_wdata : b_wdata;
    assign curr_b_wstrb = (b_overlap) ? s_axi_b_wstrb : b_wstrb;

    // address decoding and write data
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            s_axi_b_bvalid <= 1'b0;
            s_axi_b_bresp <= OKAY;
        end
        else begin 
            if (s_axi_b_bvalid && s_axi_b_bready) begin 
                s_axi_b_bvalid <= 1'b0;
            end

            if (b_write || b_overlap) begin
                if (curr_b_awaddr < 32'h00001000) begin 
                    if (curr_b_wstrb[0]) mem[curr_b_awaddr[11:2]][7:0] <= curr_b_wdata[7:0];
                    if (curr_b_wstrb[1]) mem[curr_b_awaddr[11:2]][15:8] <= curr_b_wdata[15:8];
                    if (curr_b_wstrb[2]) mem[curr_b_awaddr[11:2]][23:16] <= curr_b_wdata[23:16];
                    if (curr_b_wstrb[3]) mem[curr_b_awaddr[11:2]][31:24] <= curr_b_wdata[31:24];
                    s_axi_b_bresp <= OKAY;
                end
                else begin 
                    s_axi_b_bresp <= SLVERR;
                end
                s_axi_b_bvalid <= 1'b1;
            end
        end
    end

    // address decoding and read data
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            // b_ar_hs <= 1'b0;
            s_axi_b_rdata <= {DATA_WIDTH{1'b0}};
            s_axi_b_rvalid <= 1'b0;
            s_axi_b_rresp <= OKAY;
        end
        else begin 
            if (s_axi_b_rvalid && s_axi_b_rready) begin 
                s_axi_b_rvalid <= 1'b0;
            end

            if (s_axi_b_arvalid && s_axi_b_arready ) begin
                if (s_axi_b_araddr < 32'h00001000) begin 
                    s_axi_b_rdata <= mem[s_axi_b_araddr[11:2]];
                    s_axi_b_rresp <= OKAY;
                end
                else begin 
                    s_axi_b_rresp <= SLVERR;
                    s_axi_b_rdata <= {DATA_WIDTH{1'b0}};
                end
                s_axi_b_rvalid <= 1'b1;
            end
            
        end
    end
    
    
endmodule
