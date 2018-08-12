
`timescale 1ns/1ps
`include "parser.sv"

module tb_parser();

  parameter IP_DATA_WIDTH  = 64;
  parameter MSG_COUNT_LEN  = 2;
  parameter MSG_LENGTH_LEN = 2;
  parameter OP_DATA_WIDTH  = 256;
  parameter OP_BM_WIDTH    = OP_DATA_WIDTH/8;
  parameter MAX_MSG_SIZE   = 3;


  logic                    clk;
  logic                    reset_n;
  logic                    in_valid;
  logic                    in_startofpayload;
  logic                    in_endofpayload;
  logic [IP_DATA_WIDTH-1:0] in_data;
  logic                    in_ready;
  logic                    in_empty;
  logic                    in_error;

  logic                    out_valid;
  logic [OP_DATA_WIDTH-1:0]out_data;
  logic [OP_BM_WIDTH-1:0]  out_bytemask;


  parser dut(.*);

  initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
  end

  initial begin
    reset_n = 1'b1;
    #15;
    reset_n = 1'b0;
    in_startofpayload <= 1'b0;
    in_endofpayload   <= 1'b0;
    #30;
    reset_n = 1'b1;
    in_valid = 1'b0;
    in_empty = 3'b000;
    #100;
    //for(int i =0; i <= 9; ++i) begin
      write();
    //end
  end


  task write ();
   @(posedge clk);
   //for (int i =0; i <= 10; ++i) begin
     in_valid <= 1'b1;
     in_startofpayload <= 1'b1;
     in_data  <= 64'h0008000962626262; 
     @(posedge clk);
     in_startofpayload <= 1'b0;
     in_data <= 64'h6262626262000b43;
     @(posedge clk);
     in_data <= 64'h4343434343434343;
     @(posedge clk);
     in_data <= 64'h4343000e72727272;
     @(posedge clk);
     in_data <= 64'h7272727272727272;
     @(posedge clk);
     in_data <= 64'h7272000856565656;
     @(posedge clk);
     in_data <= 64'h5656565600118989;
     @(posedge clk);
     in_data <= 64'h8989898989898989;
     @(posedge clk);
     in_data <= 64'h8989898989898900;
     @(posedge clk);
     in_data <= 64'h0a30303030303030;

     @(posedge clk);
     in_valid <= 1'b0;

     @(posedge clk);
     in_valid <= 1'b1;
     in_data <= 64'h3030300010282828;
     @(posedge clk);
     in_data <= 64'h2828282828282828;
     @(posedge clk);
     in_data <= 64'h2828282828000d54;
     @(posedge clk);
     in_data <= 64'h5454545454545454;
     @(posedge clk);
     in_data <= 64'h5454545400000000;
     in_empty <= 3'b100;
     in_endofpayload <= 1'b1;
     @(posedge clk);
     in_valid <= 1'b0;
     in_data <= 64'h0000000000000000;
     in_endofpayload <= 1'b0;
   //end
   endtask
 
  

endmodule
