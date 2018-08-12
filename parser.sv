


module parser #(
  parameter IP_DATA_WIDTH  = 64,
  parameter MSG_COUNT_LEN  = 2,
  parameter MSG_LENGTH_LEN = 2,
  parameter OP_DATA_WIDTH  = 256,
  parameter OP_BM_WIDTH    = OP_DATA_WIDTH/8,
  parameter MAX_MSG_SIZE   = 32
)
(
  input  logic                    clk,
  input  logic                    reset_n,
  input  logic                    in_valid,
  input  logic                    in_startofpayload,
  input  logic                    in_endofpayload,
  input  logic [IP_DATA_WIDTH-1:0] in_data,
  output logic                    in_ready, 
  input  logic                    in_empty,
  input  logic                    in_error,

  output logic                    out_valid,
  output logic [OP_DATA_WIDTH-1:0]out_data,
  output logic [OP_BM_WIDTH-1:0]  out_bytemask
);


  logic [0:IP_DATA_WIDTH/8-1][7:0]     in_arr; //wire to access input data in chunks of bytes
  logic [0:IP_DATA_WIDTH/8-1][7:0]     temp_arr,temp_arr_nxt; 
  logic [MSG_LENGTH_LEN-1:0][7:0]      msg_len, msg_len_nxt; //stores the msg length that needs to be sent out in  next output
  logic [$clog2(IP_DATA_WIDTH/8)-1:0]  msg_len_index, msg_len_index_nxt; //points to the byte in the current payload that contains the msg_len
  logic [$clog2(MAX_MSG_SIZE/8):0]       msg_burst_len, msg_burst_len_nxt; //number of in_data to be counted to makeup 1 msg  
  logic [$clog2(MAX_MSG_SIZE/8):0]       count_msg_burst_len, count_msg_burst_len_nxt;
  logic [$clog2(IP_DATA_WIDTH/8)-1:0]  temp_num_byte_nxt, temp_num_byte;
  logic                                end_of_msg;

  logic [0:OP_DATA_WIDTH/8-1][7:0]     op_data_arr, op_data_arr_nxt;
  logic                                out_valid_nxt;
  logic [$clog2(MAX_MSG_SIZE)-1:0]     num_byte_msg_nxt, num_byte_msg;
  logic                                temp_valid_nxt, temp_valid;  //indicates there is data in temp_arr from previous burst to be included in current output payload
  logic [OP_BM_WIDTH-1:0]              out_bytemask_nxt;
  logic                                msg_len_index_nv, msg_len_index_nv_nxt;

  typedef enum logic [1:0] {IDLE, MSG_START,  MSG_OUT, MSG_WAIT} state_type;

  state_type state, next;


  always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
       state               <= IDLE;
       msg_len_index       <= 'd2;
       msg_burst_len       <= '0;
       msg_len             <= '0;
       count_msg_burst_len <= '0;
       out_valid           <= '0;
       num_byte_msg        <= '0;
       temp_valid          <= '0;
       temp_num_byte       <= '0;
       out_bytemask        <= '0;
       msg_len_index_nv    <= '0;
       foreach(op_data_arr[i,j])
         op_data_arr[i][j]   <=  '0;
       foreach(temp_arr[i,j])
         temp_arr[i][j]   <=  '0;
    end
    else begin
       state               <= next;
       msg_len_index       <= msg_len_index_nxt;
       msg_burst_len       <= msg_burst_len_nxt;
       msg_len             <= msg_len_nxt;
       count_msg_burst_len <= count_msg_burst_len_nxt;
       out_valid           <= out_valid_nxt;
       num_byte_msg        <= num_byte_msg_nxt;
       temp_valid          <= temp_valid_nxt;
       temp_num_byte       <= temp_num_byte_nxt;
       out_bytemask        <= out_bytemask_nxt;
       msg_len_index_nv    <= msg_len_index_nv_nxt;
       for(int i =0;i <= OP_DATA_WIDTH/8-1; ++i)
         op_data_arr[i] <= op_data_arr_nxt[i];
       for(int i =0;i <= IP_DATA_WIDTH/8-1; ++i)
         temp_arr[i] <= temp_arr_nxt[i];
    end
  end
  //wire connection from input IP_DATA_WIDTH bits to IP_DATA_WIDTH/8 bytes 
  genvar i;
  for(i=0; i <= IP_DATA_WIDTH/8-1; ++i) begin
    assign in_arr[i] = in_data[8*(7-i) +: 8];
  end

  //wire connection from input OP_DATA_WIDTH/8 bytes to OP_DATA_WIDTH bits 
  genvar j;
  for(j=0; j <= OP_DATA_WIDTH/8-1 ; ++j) begin
    assign out_data[8*j+:8] = op_data_arr[j];
  end

  always_comb
  begin
    //default assignment to avoid latches
    msg_len_nxt              = msg_len;
    msg_burst_len_nxt        = msg_burst_len;
    msg_len_index_nxt        = msg_len_index;
    count_msg_burst_len_nxt  = count_msg_burst_len;
    out_valid_nxt            = out_valid;
    next                     = state;
    num_byte_msg_nxt         = num_byte_msg;
    temp_valid_nxt           = temp_valid;
    temp_num_byte_nxt        = temp_num_byte;
    out_bytemask_nxt         = out_bytemask;
    msg_len_index_nv_nxt     = msg_len_index_nv;
    for(int i =0;i <= OP_DATA_WIDTH/8-1; ++i)
       op_data_arr_nxt[i] = op_data_arr[i];
    for(int i =0;i <= IP_DATA_WIDTH/8-1; ++i)
       temp_arr_nxt[i] = temp_arr[i];

    case (state)
      //We assume minimum msg_length will be 8 bytes, hence minimum two payloads are required for the first msg to be sent out
      //hence IDLE never makes out_valid_nxt to 1'b1
      IDLE: 
        if(in_valid && in_startofpayload) begin
          next                    =  MSG_START;
          out_valid_nxt           =  '0;
          msg_len_nxt             =  in_arr[msg_len_index +: 2];
          msg_burst_len_nxt       =  msg_len_index+ MSG_LENGTH_LEN + in_arr[msg_len_index +:2] >> $clog2(IP_DATA_WIDTH/8); //integer remonder
          msg_len_index_nxt       =  msg_len_index+ MSG_LENGTH_LEN + in_arr[msg_len_index +:2] - (msg_burst_len_nxt << $clog2(IP_DATA_WIDTH/8));  //integer modulo
          count_msg_burst_len_nxt =  count_msg_burst_len + 1;
          num_byte_msg_nxt        =  IP_DATA_WIDTH/8 - (msg_len_index+2);
          for(int i= msg_len_index+2; i<= IP_DATA_WIDTH/8-1; ++i) begin
            op_data_arr_nxt[i-msg_len_index-2]    = in_arr[i];
            out_bytemask_nxt[i-msg_len_index-2]       = 1'b1;
          end
        end
        else begin
          next = IDLE;
          out_valid_nxt           =  '0;
        end
      MSG_START:
      begin
         if (in_valid) begin
           if(count_msg_burst_len == msg_burst_len) begin  //We have recieved one full msg and hence needs to output the msg in next clock cycle
           // special case where msg_length is split between two input payloads i.e in_arr{7} has bytw[1] of msglength 
           //in_arr[0] has byte[0] of msg length
             if (msg_len_index == 7) begin    
                count_msg_burst_len_nxt = 3'b000;   
                msg_len_nxt[1]          = in_arr[msg_len_index];
                msg_len_index_nxt       = '0;
                msg_burst_len_nxt       = '0;
                msg_len_index_nxt       = '0;
                next                    = MSG_WAIT;
                out_valid_nxt           = 1'b1;
             end
             else begin
             //ordinary case where msg length in within one payload
                count_msg_burst_len_nxt = 3'b001;
                msg_len_nxt             = in_arr[msg_len_index +: 2];
                msg_burst_len_nxt       = msg_len_index+ MSG_LENGTH_LEN + in_arr[msg_len_index +:2] >> $clog2(IP_DATA_WIDTH/8); //integere remonder
                msg_len_index_nxt       = msg_len_index+ MSG_LENGTH_LEN + in_arr[msg_len_index +:2] - (msg_burst_len_nxt << $clog2(IP_DATA_WIDTH/8));  //interger modulo
                next                    = MSG_START;
                out_valid_nxt           = 1'b1;
             end
             //in this cycle we have recieved the last byte of the msg  
             if(temp_valid == 1'b0) begin  //case where no data from previous payload needs to be sent in current output payload
               for(int i= 0; i<= msg_len_index-1; ++i) begin
                 op_data_arr_nxt[i+num_byte_msg]    = in_arr[i];
                 out_bytemask_nxt[i+num_byte_msg]   = 1'b1;
               end
               for(int i = num_byte_msg+msg_len_index;i <= OP_DATA_WIDTH/8-1; ++i) begin //setting the bytes of output payload to zero which contain valid msg bytes
                 op_data_arr_nxt[i]    = '0;
                 out_bytemask_nxt[i]   = 1'b0;
               end
             end
             else begin  // this is the case where tmp array had valid data that also needs to be sent in current output payload
               for(int i= 0; i<= temp_num_byte; ++i) begin
                 op_data_arr_nxt[i]    = temp_arr[i];
                 out_bytemask_nxt[i]   = 1'b1;
               end
               for(int i= temp_num_byte; i<= temp_num_byte+msg_len_index-1; ++i) begin
                 op_data_arr_nxt[i]    = in_arr[i-temp_num_byte];
                 out_bytemask_nxt[i]   = 1'b1;
               end
               for(int i = temp_num_byte+msg_len_index;i <= OP_DATA_WIDTH/8-1; ++i) begin //setting the bytes of output payload to zero which contain valid msg bytes
                 op_data_arr_nxt[i]    = '0;
                 out_bytemask_nxt[i]   = 1'b0;
               end
             end
             // storing the extra bytes that we recieved in  last in_data of the current msg  but they need to be stored as they are the
             //start bytes of the next msg
             if (msg_len_index <= 6) begin
               for(int i= msg_len_index +2; i<= IP_DATA_WIDTH/8-1; ++i)
                 temp_arr_nxt[i-msg_len_index-2]    = in_arr[i];
               temp_valid_nxt          = 1'b1;
               temp_num_byte_nxt       = IP_DATA_WIDTH/8 - (msg_len_index+2);
               num_byte_msg_nxt        = temp_num_byte_nxt;
             end
             else begin
               temp_valid_nxt          = 1'b0;
               temp_num_byte_nxt       = '0;
               num_byte_msg_nxt        = '0;
             end
           end
           //this else means the msg payload doesnt end in current in_data hence the full in_data is accumulated in out_arr
           else begin
             out_bytemask_nxt        = '0;
             out_valid_nxt           = 1'b0;
             count_msg_burst_len_nxt = count_msg_burst_len + 1;
             num_byte_msg_nxt        = num_byte_msg + IP_DATA_WIDTH/8;
             temp_valid_nxt          = 1'b0;
             temp_num_byte_nxt       = '0;
             if(temp_valid == 1'b0) begin
               for(int i= 0; i<= IP_DATA_WIDTH/8-1; ++i) begin
                 op_data_arr_nxt[i+num_byte_msg]    = in_arr[i];
                 out_bytemask_nxt[i+num_byte_msg]   = 1'b1;
               end
             end
             else begin
               for(int i= 0; i<= temp_num_byte; ++i) begin
                 op_data_arr_nxt[i]    = temp_arr[i];
                 out_bytemask_nxt[i]   = 1'b1;
               end
               for(int i= temp_num_byte; i<= temp_num_byte+IP_DATA_WIDTH/8-1; ++i) begin
                 op_data_arr_nxt[i]    = in_arr[i-temp_num_byte];
                 out_bytemask_nxt[i]   = 1'b1;
               end
             end
           end
         end
         if (in_endofpayload == 1'b1) begin
           next = IDLE;
         end
      end // end case item


      //This is wait state where the msg_len was split in two in_data 
      //hence we wait one cyucle to accumulate the msg_len
      MSG_WAIT:
      begin
        next                    = MSG_START;
        msg_len_nxt[0]          = in_arr[0];
        msg_burst_len_nxt       = ({msg_len_index[1],msg_len_nxt[0]}+ 1) >> $clog2(IP_DATA_WIDTH/8); //integere remonder
        msg_len_index_nxt       = ({msg_len_index[1],msg_len_nxt[0]}+ 1) - (msg_burst_len_nxt << $clog2(IP_DATA_WIDTH/8));  //interger modulo
        count_msg_burst_len_nxt = count_msg_burst_len + 1;
        for(int i= 1; i<= IP_DATA_WIDTH/8-1; ++i)   // we read all data bytes as we know msg cant end in this ip_data for sure
            temp_arr_nxt[i-1]    = in_arr[i];
        temp_valid_nxt          = 1'b1;
        temp_num_byte_nxt       = IP_DATA_WIDTH/8 - 1;
        num_byte_msg_nxt        = temp_num_byte_nxt;
        out_valid_nxt           = 1'b0;
      end  //end case item
    endcase

  end




endmodule
