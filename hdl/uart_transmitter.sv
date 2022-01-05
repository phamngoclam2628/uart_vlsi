//-----------------------------------------------------------------------------------------------------------
//    Copyright (C) 2021 by Dolphin Technology
//    All right reserved.
//
//    Copyright Notification
//    No part may be reproduced except as authorized by written permission.
//
//    Module: uart_protocol.uart_protocol.sv
//    Company: Dolphin Technology
//    Author: lampn0
//    Date: 15:14:49 12/03/21
//-----------------------------------------------------------------------------------------------------------
module uart_transmitter #(
  parameter DATA_SIZE       = 8,
            SIZE_FIFO       = 8,
            BIT_COUNT_SIZE  = $clog2(DATA_SIZE+1)
  )  (
  input                             sys_clk         ,
  input                             clk             , // Clock
  input                             reset_n         , // Asynchronous reset active low
  input                             write_data      ,
  input         [DATA_SIZE - 1 : 0] bus_data        ,
  output  logic                     serial_data_out ,
  output  logic [            7 : 0] status_register 
);

// -------------------------------------------------------------
// Signal Declaration
// -------------------------------------------------------------
logic [DATA_SIZE      + 1 : 0]  TX_shift_reg;
logic [BIT_COUNT_SIZE - 1 : 0]  bit_count;
logic [DATA_SIZE      - 1 : 0]  data_out;
logic                           bit_count_done;
logic                           load_TX_shift_reg;
logic                           shift;
logic                           clear;
logic                           write;
logic                           full;
logic                           empty;
logic                           bit_parity;
logic                           error_write_data;

assign status_register = {5'b0,empty,full,error_write_data};
/*===============================================---------------------
  |   5'b0  | empty | full  | error_write_data  | <== Status Register
  ===============================================---------------------
*/

assign bit_parity = ^data_out;
assign serial_data_out = TX_shift_reg[0];

uart_control_transmitter
uart_control_transmitter(
  .clk              (clk              ),
  .reset_n          (reset_n          ),
  .error_write_data (error_write_data ),
  .full             (full             ),
  .empty            (empty            ),
  .bit_count_done   (bit_count_done   ),
  .clear            (clear            ),
  .shift            (shift            ),
  .write_data       (write_data       ),
  .load_TX_shift_reg(load_TX_shift_reg),
  .write            (write            )
  );

uart_fifo #(
  .DATA_SIZE (DATA_SIZE),
  .SIZE_FIFO (SIZE_FIFO))
uart_fifo_transmitter(
  .clk     (sys_clk          ),
  .reset_n (reset_n          ),
  .write   (write            ),
  .empty   (empty            ),
  .full    (full             ),
  .data_in (bus_data         ),
  .read    (load_TX_shift_reg),
  .data_out(data_out         )
  );

// -------------------------------------------------------------
// Counter
// -------------------------------------------------------------
always_ff @(posedge clk or negedge reset_n) begin : proc_counter
  if(~reset_n) begin
    bit_count <= 0;
  end
  else if(shift) begin
    bit_count <= bit_count + 1'b1;
  end
  else if (clear) begin
    bit_count <= 0;
  end
  else begin
    bit_count <= bit_count;
  end
end

always_comb begin : proc_count_done
  bit_count_done = (bit_count == 9);
end

// -------------------------------------------------------------
// TX Shift Register
// -------------------------------------------------------------
always_ff @(posedge clk or negedge reset_n) begin : proc_tx_shift_reg
  if(~reset_n) begin
    TX_shift_reg <= {(DATA_SIZE+2){1'b1}};
  end
  else if(load_TX_shift_reg) begin
    TX_shift_reg <= {bit_parity,data_out,1'b0};
  end
  else if (shift) begin
    TX_shift_reg <= {1'b1,TX_shift_reg[DATA_SIZE+1:1]};
  end
  else begin
    TX_shift_reg <= TX_shift_reg;
  end
end

endmodule : uart_transmitter