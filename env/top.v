`timescale 1ns/1ps

module top #(
    parameter CTRL_ADDR_WIDTH = 8,
    parameter MEM_ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter AES_DATA_WIDTH = 128,
    parameter AES_KEY_WIDTH = 128,
    parameter TOTAL = 400
) (
    input clk,
    input aresetn,

    // ========================================================
    // EXTERNAL PORT 1: AXI4-LITE SLAVE (CPU to Control Dashboard)
    // ========================================================
    input  [CTRL_ADDR_WIDTH-1:0] s_axi_ctrl_awaddr,
    input                        s_axi_ctrl_awvalid,
    output                       s_axi_ctrl_awready,
    input  [DATA_WIDTH-1:0]      s_axi_ctrl_wdata,
    input  [DATA_WIDTH/8-1:0]    s_axi_ctrl_wstrb,
    input                        s_axi_ctrl_wvalid,
    output                       s_axi_ctrl_wready,
    output [1:0]                 s_axi_ctrl_bresp,
    output                       s_axi_ctrl_bvalid,
    input                        s_axi_ctrl_bready,
    input  [CTRL_ADDR_WIDTH-1:0] s_axi_ctrl_araddr,
    input                        s_axi_ctrl_arvalid,
    output                       s_axi_ctrl_arready,
    output [DATA_WIDTH-1:0]      s_axi_ctrl_rdata,
    output                       s_axi_ctrl_rvalid,
    input                        s_axi_ctrl_rready,
    output [1:0]                 s_axi_ctrl_rresp,

    // ========================================================
    // EXTERNAL PORT 2: AXI4 SLAVE (CPU to Memory Port B)
    // ========================================================
    input  [MEM_ADDR_WIDTH-1:0]  s_axi_mem_b_awaddr,
    input                        s_axi_mem_b_awvalid,
    output                       s_axi_mem_b_awready,
    input  [DATA_WIDTH-1:0]      s_axi_mem_b_wdata,
    input  [DATA_WIDTH/8-1:0]    s_axi_mem_b_wstrb,
    input                        s_axi_mem_b_wvalid,
    output                       s_axi_mem_b_wready,
    output [1:0]                 s_axi_mem_b_bresp,
    output                       s_axi_mem_b_bvalid,
    input                        s_axi_mem_b_bready,
    input  [MEM_ADDR_WIDTH-1:0]  s_axi_mem_b_araddr,
    input                        s_axi_mem_b_arvalid,
    output                       s_axi_mem_b_arready,
    output [DATA_WIDTH-1:0]      s_axi_mem_b_rdata,
    output                       s_axi_mem_b_rvalid,
    input                        s_axi_mem_b_rready,
    output [1:0]                 s_axi_mem_b_rresp
);

    // ========================================================
    // INTERNAL INTERCONNECT (AES Master -> Memory Port A)
    // ========================================================
    wire [MEM_ADDR_WIDTH-1:0]  int_axi_awaddr;
    wire                       int_axi_awvalid;
    wire                       int_axi_awready;
    wire [DATA_WIDTH-1:0]      int_axi_wdata;
    wire [DATA_WIDTH/8-1:0]    int_axi_wstrb;
    wire                       int_axi_wvalid;
    wire                       int_axi_wready;
    wire [1:0]                 int_axi_bresp;
    wire                       int_axi_bvalid;
    wire                       int_axi_bready;
    wire [MEM_ADDR_WIDTH-1:0]  int_axi_araddr;
    wire                       int_axi_arvalid;
    wire                       int_axi_arready;
    wire [DATA_WIDTH-1:0]      int_axi_rdata;
    wire                       int_axi_rvalid;
    wire                       int_axi_rready;
    wire [1:0]                 int_axi_rresp;

    // ========================================================
    // 1. INSTANTIATE AES TOP (IP Core)
    // ========================================================
    aes_top #(
        .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH),
        .CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .AES_DATA_WIDTH(AES_DATA_WIDTH),
        .AES_KEY_WIDTH(AES_KEY_WIDTH)
    ) U_AES_TOP (
        .clk(clk),
        .aresetn(aresetn),

        // Connect Control Dashboard directly to top-level external ports
        .s_axi_ctrl_awaddr (s_axi_ctrl_awaddr),
        .s_axi_ctrl_awvalid(s_axi_ctrl_awvalid),
        .s_axi_ctrl_awready(s_axi_ctrl_awready),
        .s_axi_ctrl_wdata  (s_axi_ctrl_wdata),
        .s_axi_ctrl_wstrb  (s_axi_ctrl_wstrb),
        .s_axi_ctrl_wvalid (s_axi_ctrl_wvalid),
        .s_axi_ctrl_wready (s_axi_ctrl_wready),
        .s_axi_ctrl_bresp  (s_axi_ctrl_bresp),
        .s_axi_ctrl_bvalid (s_axi_ctrl_bvalid),
        .s_axi_ctrl_bready (s_axi_ctrl_bready),
        .s_axi_ctrl_araddr (s_axi_ctrl_araddr),
        .s_axi_ctrl_arvalid(s_axi_ctrl_arvalid),
        .s_axi_ctrl_arready(s_axi_ctrl_arready),
        .s_axi_ctrl_rdata  (s_axi_ctrl_rdata),
        .s_axi_ctrl_rvalid (s_axi_ctrl_rvalid),
        .s_axi_ctrl_rready (s_axi_ctrl_rready),
        .s_axi_ctrl_rresp  (s_axi_ctrl_rresp),

        // Connect Datapath Master to Internal Interconnect
        .m_axi_mem_awaddr  (int_axi_awaddr),
        .m_axi_mem_awvalid (int_axi_awvalid),
        .m_axi_mem_awready (int_axi_awready),
        .m_axi_mem_wdata   (int_axi_wdata),
        .m_axi_mem_wstrb   (int_axi_wstrb),
        .m_axi_mem_wvalid  (int_axi_wvalid),
        .m_axi_mem_wready  (int_axi_wready),
        .m_axi_mem_bresp   (int_axi_bresp),
        .m_axi_mem_bvalid  (int_axi_bvalid),
        .m_axi_mem_bready  (int_axi_bready),
        .m_axi_mem_araddr  (int_axi_araddr),
        .m_axi_mem_arvalid (int_axi_arvalid),
        .m_axi_mem_arready (int_axi_arready),
        .m_axi_mem_rdata   (int_axi_rdata),
        .m_axi_mem_rvalid  (int_axi_rvalid),
        .m_axi_mem_rready  (int_axi_rready),
        .m_axi_mem_rresp   (int_axi_rresp)
    );

    // ========================================================
    // 2. INSTANTIATE DUAL-PORT MEMORY
    // ========================================================
    axi_mem #(
        .ADDR_WIDTH(MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .AES_DATA_WIDTH(AES_DATA_WIDTH),
        .AES_KEY_WIDTH(AES_KEY_WIDTH)
    ) U_AXI_MEM (
        .clk(clk),
        .aresetn(aresetn),

        // Connect Port A to Internal Interconnect (Driven by AES Master)
        .s_axi_a_awaddr  (int_axi_awaddr),
        .s_axi_a_awvalid (int_axi_awvalid),
        .s_axi_a_awready (int_axi_awready),
        .s_axi_a_wdata   (int_axi_wdata),
        .s_axi_a_wstrb   (int_axi_wstrb),
        .s_axi_a_wvalid  (int_axi_wvalid),
        .s_axi_a_wready  (int_axi_wready),
        .s_axi_a_bresp   (int_axi_bresp),
        .s_axi_a_bvalid  (int_axi_bvalid),
        .s_axi_a_bready  (int_axi_bready),
        .s_axi_a_araddr  (int_axi_araddr),
        .s_axi_a_arvalid (int_axi_arvalid),
        .s_axi_a_arready (int_axi_arready),
        .s_axi_a_rdata   (int_axi_rdata),
        .s_axi_a_rvalid  (int_axi_rvalid),
        .s_axi_a_rready  (int_axi_rready),
        .s_axi_a_rresp   (int_axi_rresp),

        // Connect Port B directly to top-level external ports (Driven by Testbench CPU)
        .s_axi_b_awaddr  (s_axi_mem_b_awaddr),
        .s_axi_b_awvalid (s_axi_mem_b_awvalid),
        .s_axi_b_awready (s_axi_mem_b_awready),
        .s_axi_b_wdata   (s_axi_mem_b_wdata),
        .s_axi_b_wstrb   (s_axi_mem_b_wstrb),
        .s_axi_b_wvalid  (s_axi_mem_b_wvalid),
        .s_axi_b_wready  (s_axi_mem_b_wready),
        .s_axi_b_bresp   (s_axi_mem_b_bresp),
        .s_axi_b_bvalid  (s_axi_mem_b_bvalid),
        .s_axi_b_bready  (s_axi_mem_b_bready),
        .s_axi_b_araddr  (s_axi_mem_b_araddr),
        .s_axi_b_arvalid (s_axi_mem_b_arvalid),
        .s_axi_b_arready (s_axi_mem_b_arready),
        .s_axi_b_rdata   (s_axi_mem_b_rdata),
        .s_axi_b_rvalid  (s_axi_mem_b_rvalid),
        .s_axi_b_rready  (s_axi_mem_b_rready),
        .s_axi_b_rresp   (s_axi_mem_b_rresp)
    );

endmodule