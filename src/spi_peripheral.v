// SPI peripheral: Mode 0 (sample on SCLK rising)
// Frame: [ R/W(1) | ADDR(7) | DATA(8) ]  — MSB first

module spi_peripheral #(
    parameter ADDR_WIDTH = 7,
    parameter DATA_WIDTH = 8
)(
    input  wire        clk,          // 10 MHz system clk
    input  wire        rst_n,        // async active-low reset
    // raw SPI pins
    input  wire        sclk,         // ui_in[0]
    input  wire        copi,         // ui_in[1]
    input  wire        ncs,          // ui_in[2]
    // register outputs
    output reg  [7:0]  en_reg_out_7_0,
    output reg  [7:0]  en_reg_out_15_8,
    output reg  [7:0]  en_reg_pwm_7_0,
    output reg  [7:0]  en_reg_pwm_15_8,
    output reg  [7:0]  pwm_duty_cycle
);

    // 1) CDC (2FF) into clk domain
    reg sclk_ff1, sclk_ff2;
    reg copi_ff1, copi_ff2;
    reg ncs_ff1,  ncs_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_ff1 <= 1'b0; sclk_ff2 <= 1'b0;
            copi_ff1 <= 1'b0; copi_ff2 <= 1'b0;
            ncs_ff1  <= 1'b1; ncs_ff2  <= 1'b1; // idle high
        end else begin
            sclk_ff1 <= sclk; sclk_ff2 <= sclk_ff1;
            copi_ff1 <= copi; copi_ff2 <= copi_ff1;
            ncs_ff1  <= ncs;  ncs_ff2  <= ncs_ff1;
        end
    end

    wire sclk_sync = sclk_ff2;
    wire copi_sync = copi_ff2;
    wire ncs_sync  = ncs_ff2;

    // 2) Edge detect
    reg sclk_q, ncs_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_q <= 1'b0;
            ncs_q  <= 1'b1;
        end else begin
            sclk_q <= sclk_sync;
            ncs_q  <= ncs_sync;
        end
    end

    wire sclk_rise =  sclk_sync & ~sclk_q;
    wire ncs_fall  = ~ncs_sync  &  ncs_q;
    wire ncs_rise  =  ncs_sync  & ~ncs_q;
    wire ncs_high  =  ncs_sync;

    // 3) Shift and bit counter
    reg  [4:0]  bit_cnt;     // counts 0..16
    reg  [15:0] shreg;

    // precompute the value AFTER this edge (so we can decode it)
    wire [15:0] shreg_next = {shreg[14:0], copi_sync};  // 15+1=16, MSB-first
    wire        commit_now = (!ncs_high && sclk_rise && (bit_cnt == 5'd15)); //when bit counter counts to 16 bits

    // fields decoded from the *next* value (contains the 16th bit)
    wire        rw_next   = shreg_next[15];
    wire [6:0]  addr_next = shreg_next[14:8];
    wire [7:0]  data_next = shreg_next[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 5'd0;
            shreg   <= 16'd0;
        end else begin
            // start of frame
            if (ncs_fall) begin
                bit_cnt <= 5'd0;
                shreg   <= 16'd0;
            end
            // shift only while nCS low, on SCLK rising edges
            else if (!ncs_high && sclk_rise) begin
                shreg   <= shreg_next;              // includes new bit by shrifting frim right to left
                bit_cnt <= bit_cnt + 5'd1;          // 0..16
            end
            // optional: if CS rises without 16 bits, we just ignore
        end
    end

    // 4) Register file write
    function automatic bit addr_valid(input [6:0] a);
        addr_valid = (a <= 7'h04);
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0   <= 8'h00;
            en_reg_out_15_8  <= 8'h00;
            en_reg_pwm_7_0   <= 8'h00;
            en_reg_pwm_15_8  <= 8'h00;
            pwm_duty_cycle   <= 8'h00;
        end else begin
            // Commit on same edge as 16th bit, but decode shreg_next
            if (commit_now) begin
                if (rw_next && addr_valid(addr_next)) begin
                    case (addr_next)
                        7'h00: en_reg_out_7_0   <= data_next;
                        7'h01: en_reg_out_15_8  <= data_next;
                        7'h02: en_reg_pwm_7_0   <= data_next;
                        7'h03: en_reg_pwm_15_8  <= data_next;
                        7'h04: pwm_duty_cycle   <= data_next;
                        default: ; // ignore
                    endcase
                end
            end
        end
    end

endmodule
