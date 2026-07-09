`timescale 1ns/1ps

module axi_aes #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter AES_DATA_WIDTH = 128,
    parameter AES_KEY_WIDTH = 128,
    parameter ADDRESS = 0,
    parameter TOTAL = 400
) (
    // global
    input clk,
    input aresetn,

    // write address
    output reg [ADDR_WIDTH-1:0] m_axi_awaddr,
    output m_axi_awvalid,
    input m_axi_awready,

    // write data
    output reg [DATA_WIDTH-1:0] m_axi_wdata,
    output reg [DATA_WIDTH/8-1:0] m_axi_wstrb,
    output m_axi_wvalid,
    input m_axi_wready,

    // write response
    input [1:0] m_axi_bresp,
    input m_axi_bvalid,
    output m_axi_bready,

    // read address
    output reg [ADDR_WIDTH-1:0] m_axi_araddr,
    output m_axi_arvalid,
    input m_axi_arready,

    // read data
    input [DATA_WIDTH-1:0] m_axi_rdata,
    input m_axi_rvalid,
    output m_axi_rready,
    input [1:0] m_axi_rresp,

    // from the AES control
    input key_valid,
    input start,
    input stop,

    output error,
    output reg batch_done,

    // from the AES datapath
    input aes_done,
    input aes_full,
    input [AES_DATA_WIDTH-1:0] cyphertext,
    input aes_ready,
    input stall,
    input just_done_reg,

    // to the AES datapath
    output reg [AES_DATA_WIDTH-1:0] plaintext,
    output reg aes_start,
    output stall1
);

    localparam OKAY = 2'b00;
    localparam EXOKAY = 2'b01;
    localparam SLVERR = 2'b10;
    localparam DECERR = 2'b11;

    localparam IDLE = 2'b00;
    localparam READ0 = 2'b01;
    localparam READ1 = 2'b10;
    localparam WRITE_START = 2'b01;
    localparam WRITE_BUSY = 2'b10;


    // M_AXI interface with slave memory
    reg [1:0] op_r, op_w;
    reg [31:0] addr_count, data_count;
    reg [ADDR_WIDTH-1:0] address, w_address;

    reg arvalid;
    reg rready;
    reg awvalid;
    reg wvalid;
    reg bready;

    reg [31:0] w_count, aw_count, b_count;
    reg writing;
    reg [1:0] write_count;
    reg new_write;
    reg read_done;
    
    reg error_flag;

    assign m_axi_arvalid = arvalid;
    // assign m_axi_rready = rready;
    assign m_axi_rready = rready & ~stall & ~stall1;
    assign m_axi_awvalid = awvalid;
    assign m_axi_wvalid = wvalid;
    assign m_axi_bready = bready;

    assign error = error_flag;


    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            op_r <= READ0;
            address <= 32'b0;
            // address <= src_addr;
            addr_count <= 32'b0;
            data_count <= 32'b0;
            rready <= 1'b0;
            arvalid <= 1'b0;
            m_axi_araddr <= 32'b0;
            aes_start <= 1'b0;
            plaintext <= 128'b0;
            read_done <= 1'b0;
        end
        else begin 
            aes_start <= 1'b0;
            if (batch_done) read_done <= 1'b0;

            case(op_r) 
                
                READ0: begin 
                 
                    if (start && ~stop && ~aes_full && ~stall && ~stall1 && ~read_done) begin 
                        if (aes_ready) begin
                            op_r <= READ1;
                            m_axi_araddr <= ADDRESS;
                            address <= ADDRESS;
                            addr_count <= 32'b0;
                            data_count <= 32'b0;
                            arvalid <= 1'b1;
                            rready <= 1'b1;
                        end
                    end
                    else op_r <= READ0;
                    
                    
                end
                READ1: begin 
                    if (arvalid & m_axi_arready) begin 
                        arvalid <= 1'b0; // as both valid and ready asserted so have to bring them down
                        if (addr_count == TOTAL-1) begin 
                            arvalid <= 1'b0;
                            address <= address + 32'd4;
                        end
                        else begin 
                            addr_count <= addr_count + 1'b1;
                            m_axi_araddr <= address + 32'd4;
                            address <= address + 32'd4;
                            arvalid <= 1'b1;
                        end
                    end

                    // if (rready & m_axi_rvalid) begin 
                    if (m_axi_rready & m_axi_rvalid) begin
                        if (m_axi_rresp != OKAY) begin 
                            op_r <= IDLE; 
                            arvalid <= 1'b0;
                            rready <= 1'b0;
                        end
                        else begin 
                            plaintext[32*(data_count[1:0])+:32] <= m_axi_rdata;
                            if (&data_count[1:0]) begin 
                                aes_start <= 1'b1;
                            end

                            if (data_count == TOTAL - 1) begin 
                                rready <= 1'b0;
                                op_r <= READ0; // starts reading if again asked
                                read_done <= 1'b1;
                            end
                            else begin 
                                data_count <= data_count + 1'b1;
                            end
                        end
                        
                    end

                end
                IDLE: begin 
                    aes_start <= 1'b0;
                    if (key_valid && start && ~stop && ~aes_full && ~stall && ~stall1) begin 
                        if (m_axi_rresp == OKAY) op_r <= READ1; // to continue reading
                    end 
                end
                default: begin 
                        op_r <= READ0;
                    end
                
            endcase
        end
    end

    

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            op_w <= WRITE_START;
            w_address <= 32'b0;
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            bready <= 1'b0;
            aw_count <= 2'b00;
            w_count <= 2'b00;
            b_count <= 2'b00;
            write_count <= 2'b11;
            new_write <= 1'b0;
            batch_done <= 1'b0;
        end
        else begin 
            batch_done <= 1'b0; 
            case(op_w) 
                WRITE_START: begin 
                    if (aes_done) begin 
                        op_w <= WRITE_BUSY;
                        awvalid <= 1'b1;
                        wvalid <= 1'b1;
                        bready <= 1'b1;
                        w_address <= ADDRESS;
                        m_axi_awaddr <= ADDRESS;
                        m_axi_wdata <= cyphertext[31:0];
                        m_axi_wstrb <= 4'b1111;
                        write_count <= 2'b00;
                        aw_count <= 32'b0;
                        w_count <= 32'b0;
                        b_count <= 32'b0;
                    end

                end
                WRITE_BUSY: begin 
                    if (awvalid & m_axi_awready) begin 
                        awvalid <= 1'b0;
                        if (aw_count == TOTAL-1) begin 
                            awvalid <= 1'b0;
                            w_address <= w_address + 32'd4;
                        end
                        else begin 
                            m_axi_awaddr <= w_address + 32'd4;
                            w_address <= w_address + 32'd4;
                            awvalid <= 1'b1;
                            aw_count <= aw_count + 1'b1;
                        end
                    end
                    
                    if (wvalid & m_axi_wready) begin 
                        wvalid <= 1'b0;
                        write_count <= write_count + 1'b1;

                        if (w_count == TOTAL - 1) begin
                            wvalid <= 1'b0;
                            write_count <= 2'b0;
                        end
                        else if (w_count[1:0]==2'b11 ) begin 
                            if (aes_done || writing) begin
                                wvalid <= 1'b1;
                                m_axi_wdata <= cyphertext[31:0];
                                w_count <= w_count + 1'b1;
                            end
                            else begin // if pause or end
                                op_w <= IDLE;
                            end
                            
                            
                        end
                        else begin 
                            wvalid <= 1'b1;
                            m_axi_wdata <= cyphertext[32*(w_count[1:0]+1)+:32];
                            w_count <= w_count + 1'b1;
                        end
                    end

                    if(bready && m_axi_bvalid) begin 
                        if (m_axi_bresp != OKAY) begin 
                            op_w <= WRITE_START;
                            awvalid <= 1'b0;
                            wvalid <= 1'b0;
                            bready <= 1'b0;
                            batch_done <= 1'b0;
                        end
                        else begin 
                            if (b_count == TOTAL - 1) begin 
                                op_w <= WRITE_START;
                                batch_done <= 1'b1;
                            end
                            else begin 
                                b_count <= b_count + 1'b1;
                                batch_done <= 1'b0;
                            end
                        end
                    end
                    
                end
                IDLE: begin 
                    if (aes_done) begin 
                        op_w <= WRITE_BUSY;
                        awvalid <= 1'b1;
                        wvalid <= 1'b1;
                        bready <= 1'b1;
                        m_axi_awaddr <= w_address + 32'd4;
                        w_address <= w_address + 32'd4;
                        m_axi_wdata <= cyphertext[31:0];
                        m_axi_wstrb <= 4'b1111;
                        write_count <= write_count + 1'b1;
                        // w_count <= w_count + 1'b1;
                    end

                    if (bready && m_axi_bvalid) begin 
                        if (m_axi_bresp != OKAY) begin 
                            op_w <= WRITE_START;
                            bready <= 1'b0;
                            awvalid <= 1'b0;
                            wvalid <= 1'b0;
                        end
                        else begin 
                            if (b_count == TOTAL - 1) begin 
                                b_count <= 32'b0;
                                bready <= 1'b0;
                                
                                op_w <= WRITE_START; 
                                batch_done <= 1'b1;
                            end
                            else begin 
                                b_count <= b_count + 1'b1;
                            end
                        end
                    end
                    
                end
                default: op_w <= WRITE_START;
            endcase
        end
    end

    reg data_in_flight;

    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            data_in_flight <= 1'b0;
            writing <= 1'b0;
        end else begin
            if (aes_done) begin 
                    data_in_flight <= 1'b1;
                    writing <= 1'b1;
            end
            else if ((write_count==2'b10 ) && m_axi_wready && wvalid ) begin 
                writing <= 1'b0;
                new_write <= 1'b1;
            end
            if (wvalid & m_axi_wready) new_write <= 1'b0;
        end
    end
    // stalling if the next block is about to crash into unwritten data
    assign stall1 = (wvalid&&m_axi_wready&&(write_count==2'b10))?1'b0:just_done_reg & writing;

    wire read_error;
    wire write_error;
    assign read_error  = rready & m_axi_rvalid & (m_axi_rresp != OKAY);
    assign write_error = bready & m_axi_bvalid & (m_axi_bresp != OKAY);

    always@(posedge clk or negedge aresetn) begin 
        if (!aresetn) begin 
            error_flag <= 1'b0;
        end
        else begin 
            if (read_error || write_error) begin 
                error_flag <= 1'b1;
            end
            else if (start) begin 
                error_flag <= 1'b0;
            end
        end
    end

    
endmodule
