`timescale 1ns/1ps

module aes_top #(
    parameter MEM_ADDR_WIDTH = 32,
    parameter CTRL_ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter AES_DATA_WIDTH = 128,
    parameter AES_KEY_WIDTH = 128
) (
    input clk,
    input aresetn,

    // --------------------------------------------------------
    // EXTERNAL PORT 1: AXI4-LITE SLAVE (Control Dashboard)
    // --------------------------------------------------------
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

    // --------------------------------------------------------
    // EXTERNAL PORT 2: AXI4-LITE MASTER (DMA to System Memory)
    // --------------------------------------------------------
    output [MEM_ADDR_WIDTH-1:0]  m_axi_mem_awaddr,
    output                       m_axi_mem_awvalid,
    input                        m_axi_mem_awready,
    output [DATA_WIDTH-1:0]      m_axi_mem_wdata,
    output [DATA_WIDTH/8-1:0]    m_axi_mem_wstrb,
    output                       m_axi_mem_wvalid,
    input                        m_axi_mem_wready,
    input  [1:0]                 m_axi_mem_bresp,
    input                        m_axi_mem_bvalid,
    output                       m_axi_mem_bready,
    output [MEM_ADDR_WIDTH-1:0]  m_axi_mem_araddr,
    output                       m_axi_mem_arvalid,
    input                        m_axi_mem_arready,
    input  [DATA_WIDTH-1:0]      m_axi_mem_rdata,
    input                        m_axi_mem_rvalid,
    output                       m_axi_mem_rready,
    input  [1:0]                 m_axi_mem_rresp
);

    // ========================================================
    // INTERNAL INTERCONNECT WIRES
    // ========================================================
    
    wire ctrl_start;
    wire ctrl_stop;
    wire ctrl_key_valid;
    wire [AES_KEY_WIDTH-1:0] ctrl_key;

    wire aes_busy;
    wire aes_empty;
    wire aes_done;
    wire dma_error;

    wire [AES_DATA_WIDTH-1:0] dma_plaintext;
    wire [AES_DATA_WIDTH-1:0] aes_cyphertext;
    wire dma_aes_start;
    wire aes_ready;

    wire stall;
    wire stall1;
    wire just_done;
    wire just_done_reg;
    wire dma_batch_done;


    // ========================================================
    // 1. THE CONTROL DASHBOARD (SLAVE)
    // ========================================================
    axi_ctrl #(
        .ADDR_WIDTH(CTRL_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .AES_DATA_WIDTH(AES_DATA_WIDTH),
        .AES_KEY_WIDTH(AES_KEY_WIDTH)
    ) U_AXI_CTRL (
        .clk(clk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_ctrl_awaddr),
        .s_axi_awvalid(s_axi_ctrl_awvalid),
        .s_axi_awready(s_axi_ctrl_awready),
        .s_axi_wdata(s_axi_ctrl_wdata),
        .s_axi_wstrb(s_axi_ctrl_wstrb),
        .s_axi_wvalid(s_axi_ctrl_wvalid),
        .s_axi_wready(s_axi_ctrl_wready),
        .s_axi_bresp(s_axi_ctrl_bresp),
        .s_axi_bvalid(s_axi_ctrl_bvalid),
        .s_axi_bready(s_axi_ctrl_bready),
        .s_axi_araddr(s_axi_ctrl_araddr),
        .s_axi_arvalid(s_axi_ctrl_arvalid),
        .s_axi_arready(s_axi_ctrl_arready),
        .s_axi_rdata(s_axi_ctrl_rdata),
        .s_axi_rvalid(s_axi_ctrl_rvalid),
        .s_axi_rready(s_axi_ctrl_rready),
        .s_axi_rresp(s_axi_ctrl_rresp),
        
        .stop(ctrl_stop),
        .key_valid(ctrl_key_valid),
        .start(ctrl_start),
        .busy(aes_busy),
        .empty(aes_empty),
        // .done(aes_done),
        .done(dma_batch_done),
        .error(dma_error),
        .key(ctrl_key)
    );

    // ========================================================
    // 2. THE DMA ENGINE (MASTER)
    // ========================================================
    axi_aes #(
        .ADDR_WIDTH(MEM_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .AES_DATA_WIDTH(AES_DATA_WIDTH),
        .AES_KEY_WIDTH(AES_KEY_WIDTH),
        .TOTAL(400) 
    ) U_AXI_AES_MASTER (
        .clk(clk),
        .aresetn(aresetn),
        .m_axi_awaddr(m_axi_mem_awaddr),
        .m_axi_awvalid(m_axi_mem_awvalid),
        .m_axi_awready(m_axi_mem_awready),
        .m_axi_wdata(m_axi_mem_wdata),
        .m_axi_wstrb(m_axi_mem_wstrb),
        .m_axi_wvalid(m_axi_mem_wvalid),
        .m_axi_wready(m_axi_mem_wready),
        .m_axi_bresp(m_axi_mem_bresp),
        .m_axi_bvalid(m_axi_mem_bvalid),
        .m_axi_bready(m_axi_mem_bready),
        .m_axi_araddr(m_axi_mem_araddr),
        .m_axi_arvalid(m_axi_mem_arvalid),
        .m_axi_arready(m_axi_mem_arready),
        .m_axi_rdata(m_axi_mem_rdata),
        .m_axi_rvalid(m_axi_mem_rvalid),
        .m_axi_rready(m_axi_mem_rready),
        .m_axi_rresp(m_axi_mem_rresp),
        
        .key_valid(ctrl_key_valid),
        .start(ctrl_start),
        .stop(ctrl_stop),
        .error(dma_error),
        .aes_done(aes_done),
        .aes_full(aes_busy|dma_aes_start),
        .cyphertext(aes_cyphertext),
        .plaintext(dma_plaintext),
        .aes_start(dma_aes_start),
        .aes_ready(aes_ready),
        .stall(stall),
        .stall1(stall1),
        .just_done_reg(just_done_reg),
        .batch_done(dma_batch_done)
        
    );

    // ========================================================
    // 3. THE CRYPTO DATAPATH
    // ========================================================
    aes #(
        .AES_DATA_WIDTH(AES_DATA_WIDTH),
        .AES_KEY_WIDTH(AES_KEY_WIDTH)
    ) U_AES_DATAPATH (
        .clk(clk),
        .aresetn(aresetn),
        .plaintext(dma_plaintext),
        .key(ctrl_key),
        .cyphertext(aes_cyphertext),
        .start(dma_aes_start),
        .busy(aes_busy),
        .empty(aes_empty),
        .done(aes_done),
        .aes_ready(aes_ready),
        .key_valid(ctrl_key_valid),
        .stall(stall),
        .stall1(stall1),
        .just_done(just_done),
        .just_done_reg(just_done_reg)
    );

endmodule