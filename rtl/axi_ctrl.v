`timescale 1ns/1ps

module axi_ctrl #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter AES_DATA_WIDTH = 128,
    parameter AES_KEY_WIDTH = 128
) (
    // global
    input clk,
    input aresetn,

    // write address
    input [ADDR_WIDTH-1:0] s_axi_awaddr,
    input s_axi_awvalid,
    output s_axi_awready,

    // write data
    input [DATA_WIDTH-1:0] s_axi_wdata,
    input [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input s_axi_wvalid,
    output s_axi_wready,

    // write response
    output reg [1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input s_axi_bready,

    // read address
    input [ADDR_WIDTH-1:0] s_axi_araddr,
    input s_axi_arvalid,
    output s_axi_arready,

    // read data
    output reg [DATA_WIDTH-1:0] s_axi_rdata,
    output reg s_axi_rvalid,
    input s_axi_rready,
    output reg [1:0] s_axi_rresp,

    // to the AES control
    output stop,
    output key_valid,
    output start,

    // from the AES pipeline
    input busy, 
    input empty, 
    input done, 
    input error,

    // to the AES pipeline
    output [AES_KEY_WIDTH-1:0] key
);

    localparam OKAY = 2'b00;
    localparam EXOKAY = 2'b01;
    localparam SLVERR = 2'b10;
    localparam DECERR = 2'b11;

    localparam IDLE = 2'b00;
    localparam BUSY = 2'b01;
    localparam ERROR = 2'b10;
    localparam DONE = 2'b11;

    // register bank
    reg [DATA_WIDTH-1:0] key_in [AES_DATA_WIDTH/DATA_WIDTH-1:0];
    
    // reg key_status;
    reg [7:0] ctrl_reg;

    reg [DATA_WIDTH-1:0] wdata;
    reg [DATA_WIDTH/8-1:0] wstrb;
    reg [ADDR_WIDTH-1:0] awaddr;

    reg aw_hs;
    reg w_hs;
    reg ar_hs;

    assign s_axi_awready = (~aw_hs) & aresetn;
    assign s_axi_wready = (~w_hs) & aresetn;
    assign s_axi_arready = (~ar_hs) & (~s_axi_rvalid) & aresetn;


    assign key = {key_in[3], key_in[2], key_in[1], key_in[0]};

    assign start = ctrl_reg[0];
    assign stop = ctrl_reg[1];
    assign key_valid = ctrl_reg[2];

    // write address
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            awaddr <= {ADDR_WIDTH{1'b0}};
            aw_hs <= 1'b0;
        end
        else begin 
            if (s_axi_awvalid && s_axi_awready && !aw_hs) begin 
                awaddr <= s_axi_awaddr;
                aw_hs <= 1'b1;
            end
            if (s_axi_bvalid && s_axi_bready) begin 
                aw_hs <= 1'b0;
            end
        end
    end

    // write data 
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            wdata <= {DATA_WIDTH{1'b0}};
            wstrb <= {DATA_WIDTH/8{1'b0}};
            w_hs <= 1'b0;
        end
        else begin 
            if (s_axi_wvalid && s_axi_wready && !w_hs) begin 
                wdata <= s_axi_wdata;
                wstrb <= s_axi_wstrb;
                w_hs <= 1'b1;
            end
            if (s_axi_bvalid && s_axi_bready) begin 
                w_hs <= 1'b0;
            end 
        end
    end

    wire write;
    assign write = aw_hs && w_hs && ~s_axi_bvalid;

    reg sticky_done;

    // address decoding and write data
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            key_in[0] <= {DATA_WIDTH{1'b0}};
            key_in[1] <= {DATA_WIDTH{1'b0}};
            key_in[2] <= {DATA_WIDTH{1'b0}};
            key_in[3] <= {DATA_WIDTH{1'b0}};
            ctrl_reg <= 8'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= OKAY;
            sticky_done <= 1'b0;
        end
        else begin 
            if (write) begin
                case(awaddr[7:2]) 
                    6'h00: begin 
                        if(wstrb[0]) ctrl_reg <= wdata[7:0];
                        s_axi_bresp <= OKAY;

                        if(wstrb[0] && wdata[0]) sticky_done <= 1'b0;
                    end
                    6'h02: begin 
                        if (wstrb[0]) key_in[0][7:0]   <= wdata[7:0];
                        if (wstrb[1]) key_in[0][15:8]  <= wdata[15:8];
                        if (wstrb[2]) key_in[0][23:16] <= wdata[23:16];
                        if (wstrb[3]) key_in[0][31:24] <= wdata[31:24];
                        s_axi_bresp <= OKAY;
                    end
                    6'h03: begin 
                        if (wstrb[0]) key_in[1][7:0]   <= wdata[7:0];
                        if (wstrb[1]) key_in[1][15:8]  <= wdata[15:8];
                        if (wstrb[2]) key_in[1][23:16] <= wdata[23:16];
                        if (wstrb[3]) key_in[1][31:24] <= wdata[31:24];
                        s_axi_bresp <= OKAY;
                    end
                    6'h04: begin 
                        if (wstrb[0]) key_in[2][7:0]   <= wdata[7:0];
                        if (wstrb[1]) key_in[2][15:8]  <= wdata[15:8];
                        if (wstrb[2]) key_in[2][23:16] <= wdata[23:16];
                        if (wstrb[3]) key_in[2][31:24] <= wdata[31:24];
                        s_axi_bresp <= OKAY;
                    end
                    6'h05: begin 
                        if (wstrb[0]) key_in[3][7:0]   <= wdata[7:0];
                        if (wstrb[1]) key_in[3][15:8]  <= wdata[15:8];
                        if (wstrb[2]) key_in[3][23:16] <= wdata[23:16];
                        if (wstrb[3]) key_in[3][31:24] <= wdata[31:24];
                        s_axi_bresp <= OKAY;
                    end
                    default: begin 
                        s_axi_bresp <= SLVERR;
                    end
                endcase
                s_axi_bvalid <= 1'b1;
            end
            else begin 
                // auto clear the start bit when the AES finishes
                if (done) begin
                    ctrl_reg[0] <= 1'b0;

                    sticky_done <= 1'b1;
                end
            end
            if (s_axi_bvalid && s_axi_bready) begin 
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // address decoding and read data
    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            ar_hs <= 1'b0;
            s_axi_rdata <= {DATA_WIDTH{1'b0}};
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= OKAY;
        end
        else begin 
            if (s_axi_arvalid && s_axi_arready && !ar_hs) begin 
                ar_hs <= 1'b1;
                case(s_axi_araddr[7:2]) 
                    6'h01: begin 
                        s_axi_rdata <= {{28{1'b0}}, sticky_done, error, busy, empty};
                        s_axi_rresp <= OKAY;
                    end
                    default: begin 
                        s_axi_rresp <= SLVERR;
                    end
                endcase
                s_axi_rvalid <= 1'b1;
            end
            if (s_axi_rvalid && s_axi_rready) begin 
                s_axi_rvalid <= 1'b0;
                ar_hs <= 1'b0;
            end
        end
    end
    
endmodule