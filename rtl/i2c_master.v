/*
Original work Copyright (c) 2015-2017 Alex Forencich
Modified work Copyright (c) 2020 Alex Bucknall

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps
`include "i2c_defines.v"

/*
 * I2C master
 */

module i2c_master (
    input  wire        clk,
    input  wire        rst,

    /*
     * Control interface
     */
    input  wire [6:0]  cmd_addr,
    input  wire        cmd_start,
    input  wire        cmd_read,
    input  wire        cmd_write,
    input  wire        cmd_write_multiple,
    input  wire        cmd_stop,
    input  wire        cmd_valid,
    output wire        cmd_ready,

    input  wire [7:0]  data_in,
    input  wire        data_in_valid,
    output wire        data_in_ready,
    input  wire        data_in_last,

    output wire [7:0]  data_out,
    output wire        data_out_valid,
    input  wire        data_out_ready,
    output wire        data_out_last,

    /*
     * I2C I/O interface
     */
    input  wire        scl_i,
    output wire        scl_o,
    output wire        scl_t,
    input  wire        sda_i,
    output wire        sda_o,
    output wire        sda_t,

    /*
     * Controller Status
     */
    output wire        busy,
    output wire        bus_control,
    output wire        bus_active,
    output wire        missed_ack,
    output wire [4:0]  state,

    /*
     * Config
     */
    input  wire [15:0] prescale,
    input  wire        stop_on_idle
);

/*
 * I2C Master is designed to have a state machine for both the controller and the PHY logic;
 * Controller handles incoming commands and the PHY converts this to the I2C protocol.
 */


/* Controller States */
localparam [3:0] 
    CONTROLLER_IDLE         = 4'd0,
    CONTROLLER_ACT_WRITE    = 4'd1,
    CONTROLLER_ACT_READ     = 4'd2,
    CONTROLLER_START        = 4'd3,
    CONTROLLER_START_WAIT   = 4'd4,
    CONTROLLER_ADDR_0       = 4'd5,
    CONTROLLER_ADDR_1       = 4'd6,
    CONTROLLER_WRITE_0      = 4'd7,
    CONTROLLER_WRITE_1      = 4'd8,
    CONTROLLER_WRITE_2      = 4'd9,
    CONTROLLER_READ         = 4'd10,
    CONTROLLER_STOP         = 4'd11;

reg [3:0] controller_state_reg = CONTROLLER_IDLE, controller_state_next;
reg controller_ready_reg = 0;
wire controller_valid_reg = 0;

/* PHY States */
localparam [3:0] 
    PHY_IDLE         = 4'd0,
    PHY_ACT          = 4'd1,
    PHY_REP_START_0  = 4'd2,
    PHY_REP_START_1  = 4'd3,
    PHY_START_0      = 4'd4,
    PHY_START_1      = 4'd5,
    PHY_WRITE_0      = 4'd6,
    PHY_WRITE_1      = 4'd7,
    PHY_WRITE_2      = 4'd8,
    PHY_READ_0       = 4'd9,
    PHY_READ_1       = 4'd10,
    PHY_READ_2       = 4'd11,
    PHY_READ_3       = 4'd12,
    PHY_STOP_0       = 4'd13,
    PHY_STOP_1       = 4'd14,
    PHY_STOP_2       = 4'd15;

reg [3:0] phy_state_reg = PHY_IDLE, phy_state_next;

/* PHY output bits */
reg phy_start_bit;
reg phy_stop_bit;
reg phy_write_bit;
reg phy_read_bit;
reg phy_release_bus;

/* PHY data lines */
reg phy_tx_data;
reg phy_rx_data_reg = 1'b0, phy_rx_data_next;

/* I2C addr */
reg [6:0] addr_reg = 7'd0, addr_next;
/* I2C data */
reg [7:0] data_reg = 8'd0, data_next;
reg last_reg = 1'b0, last_next;

reg mode_read_reg = 1'b0, mode_read_next;
reg mode_write_multiple_reg = 1'b0, mode_write_multiple_next;
reg mode_stop_reg = 1'b0, mode_stop_next;

reg [16:0] delay_reg = 17'd0, delay_next;
reg delay_scl_reg = 1'b0, delay_scl_next;
reg delay_sda_reg = 1'b0, delay_sda_next;

reg [3:0] bit_count_reg = 4'd0, bit_count_next;

reg cmd_ready_reg = 1'b0, cmd_ready_next;

reg data_in_ready_reg = 1'b0, data_in_ready_next;

reg [7:0] data_out_reg = 8'd0, data_out_next;
reg data_out_valid_reg = 1'b0, data_out_valid_next;
reg data_out_last_reg = 1'b0, data_out_last_next;

reg scl_i_reg = 1'b1;
reg sda_i_reg = 1'b1;

reg scl_o_reg = 1'b1, scl_o_next;
reg sda_o_reg = 1'b1, sda_o_next;

reg last_scl_i_reg = 1'b1;
reg last_sda_i_reg = 1'b1;

reg busy_reg = 1'b0;
reg bus_active_reg = 1'b0;
reg bus_control_reg = 1'b0, bus_control_next;
reg missed_ack_reg = 1'b0, missed_ack_next;

assign cmd_ready = cmd_ready_reg;

assign data_in_ready = data_in_ready_reg;

assign data_out = data_out_reg;
assign data_out_valid = data_out_valid_reg;
assign data_out_last = data_out_last_reg;

assign scl_o = scl_o_reg;
assign scl_t = scl_o_reg;
assign sda_o = sda_o_reg;
assign sda_t = sda_o_reg;

assign busy = busy_reg;
assign bus_active = bus_active_reg;
assign bus_control = bus_control_reg;
assign missed_ack = missed_ack_reg;

wire scl_posedge = scl_i_reg & ~last_scl_i_reg;
wire scl_negedge = ~scl_i_reg & last_scl_i_reg;
wire sda_posedge = sda_i_reg & ~last_sda_i_reg;
wire sda_negedge = ~sda_i_reg & last_sda_i_reg;

wire start_bit = sda_negedge & scl_i_reg;
wire stop_bit = sda_posedge & scl_i_reg;

/* Controller Logic */
always @* begin
    /* Default state to IDLE */
    controller_state_next = CONTROLLER_IDLE;

    /* Clear PHY bits */
    phy_start_bit = 1'b0;
    phy_stop_bit = 1'b0;
    phy_write_bit = 1'b0;
    phy_read_bit = 1'b0;
    phy_tx_data = 1'b0;
    phy_release_bus = 1'b0;

    /* load registers */
    addr_next = addr_reg;
    data_next = data_reg;
    last_next = last_reg;

    mode_read_next = mode_read_reg;
    mode_write_multiple_next = mode_write_multiple_reg;
    mode_stop_next = mode_stop_reg;

    bit_count_next = bit_count_reg;

    cmd_ready_next = 1'b0;

    data_in_ready_next = 1'b0;

    data_out_next = data_out_reg;
    data_out_valid_next = data_out_valid_reg & ~data_out_ready;
    data_out_last_next = data_out_last_reg;

    missed_ack_next = 1'b0;

    // generate delays
    if (phy_state_reg != PHY_IDLE && phy_state_reg != PHY_ACT) begin
        // wait for phy operation
        controller_state_next = controller_state_reg;
    end else begin
        case (controller_state_reg)
            /* I2C bus idles */
            CONTROLLER_IDLE: begin
                // line idle
                cmd_ready_next = 1'b1;

                if (cmd_ready & cmd_valid) begin
                    // command valid
                    if (cmd_read ^ (cmd_write | cmd_write_multiple)) begin
                        // read or write command
                        addr_next = cmd_addr;
                        mode_read_next = cmd_read;
                        mode_write_multiple_next = cmd_write_multiple;
                        mode_stop_next = cmd_stop;

                        cmd_ready_next = 1'b0;

                        // start bit
                        if (bus_active) begin
                            controller_state_next = CONTROLLER_START_WAIT;
                        end else begin
                            phy_start_bit = 1'b1;
                            bit_count_next = 4'd8;
                            controller_state_next = CONTROLLER_ADDR_0;
                        end
                    end else begin
                        // invalid or unspecified - ignore
                        controller_state_next = CONTROLLER_IDLE;
                    end
                end else begin
                    controller_state_next = CONTROLLER_IDLE;
                end
            end
            /* I2C bus active with current address and r/w mode */
            CONTROLLER_ACT_WRITE: begin
                cmd_ready_next = 1'b1;
                if (cmd_ready & cmd_valid) begin
                    // command valid
                    if (cmd_read ^ (cmd_write | cmd_write_multiple)) begin
                        // read or write command
                        addr_next = cmd_addr;
                        mode_read_next = cmd_read;
                        mode_write_multiple_next = cmd_write_multiple;
                        mode_stop_next = cmd_stop;

                        cmd_ready_next = 1'b0;
                        
                        if (cmd_start || cmd_addr != addr_reg || cmd_read) begin
                            // address or mode mismatch or forced start - repeated start

                            // repeated start bit
                            phy_start_bit = 1'b1;
                            bit_count_next = 4'd8;
                            controller_state_next = CONTROLLER_ADDR_0;
                        end 
                        else begin
                            // address and mode match

                            // start write
                            data_in_ready_next = 1'b1;
                            controller_state_next = CONTROLLER_WRITE_0;
                        end
                    end 
                    else if (cmd_stop && !(cmd_read || cmd_write || cmd_write_multiple)) begin
                        // stop command
                        phy_stop_bit = 1'b1;
                        controller_state_next = CONTROLLER_IDLE;
                    end 
                    else begin
                        // invalid or unspecified - ignore
                        controller_state_next = CONTROLLER_ACT_WRITE;
                    end
                end 
                else begin
                    if (stop_on_idle & cmd_ready & ~cmd_valid) begin
                        // no waiting command and stop_on_idle selected, issue stop condition
                        phy_stop_bit = 1'b1;
                        controller_state_next = CONTROLLER_IDLE;
                    end 
                    else begin
                        controller_state_next = CONTROLLER_ACT_WRITE;
                    end
                end
            end
            /* I2C bus active to current address */
            CONTROLLER_ACT_READ: begin
                // line active to current address
                cmd_ready_next = ~data_out_valid;

                if (cmd_ready & cmd_valid) begin
                    // command valid
                    if (cmd_read ^ (cmd_write | cmd_write_multiple)) begin
                        // read or write command
                        addr_next = cmd_addr;
                        mode_read_next = cmd_read;
                        mode_write_multiple_next = cmd_write_multiple;
                        mode_stop_next = cmd_stop;

                        cmd_ready_next = 1'b0;
                        
                        if (cmd_start || cmd_addr != addr_reg || cmd_write) begin
                            // address or mode mismatch or forced start - repeated start

                            // write nack for previous read
                            phy_write_bit = 1'b1;
                            phy_tx_data = 1'b1;
                            // repeated start bit
                            controller_state_next = CONTROLLER_START;
                        end 
                        else begin
                            // address and mode match

                            // write ack for previous read
                            phy_write_bit = 1'b1;
                            phy_tx_data = 1'b0;
                            // start next read
                            bit_count_next = 4'd8;
                            data_next = 8'd0;
                            controller_state_next = CONTROLLER_READ;
                        end
                    end 
                    else if (cmd_stop && !(cmd_read || cmd_write || cmd_write_multiple)) begin
                        // stop command
                        // write nack for previous read
                        phy_write_bit = 1'b1;
                        phy_tx_data = 1'b1;
                        // send stop bit
                        controller_state_next = CONTROLLER_STOP;
                    end 
                    else begin
                        // invalid or unspecified - ignore
                        controller_state_next = CONTROLLER_ACT_READ;
                    end
                end 
                else begin
                    if (stop_on_idle & cmd_ready & ~cmd_valid) begin
                        // no waiting command and stop_on_idle selected, issue stop condition
                        // write ack for previous read
                        phy_write_bit = 1'b1;
                        phy_tx_data = 1'b1;
                        // send stop bit
                        controller_state_next = CONTROLLER_STOP;
                    end 
                    else begin
                        controller_state_next = CONTROLLER_ACT_READ;
                    end
                end
            end
            /* Wait for bus to idle */ 
            CONTROLLER_START_WAIT: begin
                if(bus_active) begin
                    controller_state_next = CONTROLLER_START_WAIT;
                end
                else begin
                    phy_start_bit = 1'b1;
                    bit_count_next = 4'd8;
                    controller_state_next = CONTROLLER_ADDR_0;
                end
            end
            /* Send start bit */
            CONTROLLER_START: begin
                phy_start_bit = 1'b1;
                bit_count_next = 4'd8;
                controller_state_next = CONTROLLER_ADDR_0;                
            end
            /* Send addr byte 0 */
            CONTROLLER_ADDR_0: begin
                bit_count_next = bit_count_reg - 1;
                if (bit_count_reg > 1) begin
                    // send address
                    phy_write_bit = 1'b1;
                    phy_tx_data = addr_reg[bit_count_reg-2];
                    controller_state_next = CONTROLLER_ADDR_0;
                end else if (bit_count_reg > 0) begin
                    // send read/write bit
                    phy_write_bit = 1'b1;
                    phy_tx_data = mode_read_reg;
                    controller_state_next = CONTROLLER_ADDR_0;
                end else begin
                    // read ack bit
                    phy_read_bit = 1'b1;
                    controller_state_next = CONTROLLER_ADDR_1;
                end
            end
            /* Send addr byte 1 */
            CONTROLLER_ADDR_1: begin
                // read ack bit
                missed_ack_next = phy_rx_data_reg;

                if (mode_read_reg) begin
                    // start read
                    bit_count_next = 4'd8;
                    data_next = 8'b0;
                    controller_state_next = CONTROLLER_READ;
                end else begin
                    // start write
                    data_in_ready_next = 1'b1;
                    controller_state_next = CONTROLLER_WRITE_0;
                end
            end
            /* Start write */
            CONTROLLER_WRITE_0: begin
                data_in_ready_next = 1'b1;

                if (data_in_ready & data_in_valid) begin
                    // got data, start write
                    data_next = data_in;
                    last_next = data_in_last;
                    bit_count_next = 4'd8;
                    data_in_ready_next = 1'b0;
                    controller_state_next = CONTROLLER_WRITE_1;
                end else begin
                    // wait for data
                    controller_state_next = CONTROLLER_WRITE_0;
                end
            end
            /* Cont. write */
            CONTROLLER_WRITE_1: begin
                // send data
                bit_count_next = bit_count_reg - 1;
                if (bit_count_reg > 0) begin
                    // write data bit
                    phy_write_bit = 1'b1;
                    phy_tx_data = data_reg[bit_count_reg-1];
                    controller_state_next = CONTROLLER_WRITE_1;
                end else begin
                    // read ack bit
                    phy_read_bit = 1'b1;
                    controller_state_next = CONTROLLER_WRITE_2;
                end
            end
            /* End write */
            CONTROLLER_WRITE_2: begin
                // read ack bit
                missed_ack_next = phy_rx_data_reg;

                if (mode_write_multiple_reg && !last_reg) begin
                    // more to write
                    controller_state_next = CONTROLLER_WRITE_0;
                end else if (mode_stop_reg) begin
                    // last cycle and stop selected
                    phy_stop_bit = 1'b1;
                    controller_state_next = CONTROLLER_IDLE;
                end else begin
                    // otherwise, return to bus active state
                    controller_state_next = CONTROLLER_ACT_WRITE;
                end
            end
            /* Read data */
            CONTROLLER_READ: begin
                // read data

                bit_count_next = bit_count_reg - 1;
                data_next = {data_reg[6:0], phy_rx_data_reg};
                if (bit_count_reg > 0) begin
                    // read next bit
                    phy_read_bit = 1'b1;
                    controller_state_next = CONTROLLER_READ;
                end else begin
                    // output data word
                    data_out_next = data_next;
                    data_out_valid_next = 1'b1;
                    data_out_last_next = 1'b0;
                    if (mode_stop_reg) begin
                        // send nack and stop
                        data_out_last_next = 1'b1;
                        phy_write_bit = 1'b1;
                        phy_tx_data = 1'b1;
                        controller_state_next = CONTROLLER_STOP;
                    end else begin
                        // return to bus active state
                        controller_state_next = CONTROLLER_ACT_READ;
                    end
                end
            end
        /* Stop */
            CONTROLLER_STOP: begin
                // send stop bit
                phy_stop_bit = 1'b1;
                controller_state_next = CONTROLLER_IDLE;
            end
        endcase
    end
end

/* PHY Logic */
always @* begin

end

/* Sync Controller */
always @(posedge clk) begin
    if (rst) begin
        controller_state_reg <= CONTROLLER_IDLE;
        phy_state_reg <= PHY_IDLE;
        delay_reg <= 17'd0;
        delay_scl_reg <= 1'b0;
        delay_sda_reg <= 1'b0;
        cmd_ready_reg <= 1'b0;
        data_in_ready_reg <= 1'b0;
        data_out_valid_reg <= 1'b0;
        scl_o_reg <= 1'b1;
        sda_o_reg <= 1'b1;
        busy_reg <= 1'b0;
        bus_active_reg <= 1'b0;
        bus_control_reg <= 1'b0;
        missed_ack_reg <= 1'b0;
    end 
    else begin
        controller_state_reg <= controller_state_next;
        phy_state_reg <= phy_state_next;

        delay_reg <= delay_next;
        delay_scl_reg <= delay_scl_next;
        delay_sda_reg <= delay_sda_next;

        cmd_ready_reg <= cmd_ready_next;
        data_in_ready_reg <= data_in_ready_next;
        data_out_valid_reg <= data_out_valid_next;

        scl_o_reg <= scl_o_next;
        sda_o_reg <= sda_o_next;

        busy_reg <= !(controller_state_reg == CONTROLLER_IDLE || controller_state_reg == CONTROLLER_ACT_WRITE || controller_state_reg == CONTROLLER_ACT_READ) || !(phy_state_reg == PHY_IDLE || phy_state_reg == PHY_ACT);

        if (start_bit) begin
            bus_active_reg <= 1'b1;
        end else if (stop_bit) begin
            bus_active_reg <= 1'b0;
        end else begin
            bus_active_reg <= bus_active_reg;
        end

        bus_control_reg <= bus_control_next;
        missed_ack_reg <= missed_ack_next;
    end

    phy_rx_data_reg <= phy_rx_data_next;

    addr_reg <= addr_next;
    data_reg <= data_next;
    last_reg <= last_next;

    mode_read_reg <= mode_read_next;
    mode_write_multiple_reg <= mode_write_multiple_next;
    mode_stop_reg <= mode_stop_next;

    bit_count_reg <= bit_count_next;

    data_out_reg <= data_out_next;
    data_out_last_reg <= data_out_last_next;

    scl_i_reg <= scl_i;
    sda_i_reg <= sda_i;
    last_scl_i_reg <= scl_i_reg;
    last_sda_i_reg <= sda_i_reg;
end

endmodule