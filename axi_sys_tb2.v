`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/04/11 11:36:45
// Design Name: 
// Module Name: axi_sys_tb2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axi_sys_tb2(
    );
    parameter DATA_WD = 32;
    parameter DATA_BYTE_WD = DATA_WD / 8;

    // Inputs
    reg clk;
    reg rst_n;
    reg valid_in;
    reg [DATA_WD-1 : 0] data_in;
    reg [DATA_BYTE_WD-1 : 0] keep_in;
    reg last_in;
    wire ready_in;
    reg valid_insert;
    reg [DATA_WD-1 : 0] header_insert;
    reg [DATA_BYTE_WD-1 : 0] keep_insert;
    wire ready_insert;

    // Outputs
    wire valid_out;
    wire [DATA_WD-1 : 0] data_out;
    wire [DATA_BYTE_WD-1 : 0] keep_out;
    wire last_out;
    reg ready_out;

    // Instantiate the Unit Under Test (UUT)
    axi_stream_insert_header #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .keep_in(keep_in),
        .last_in(last_in),
        .ready_in(ready_in),
        .valid_out(valid_out),
        .data_out(data_out),
        .keep_out(keep_out),
        .last_out(last_out),
        .ready_out(ready_out),
        .valid_insert(valid_insert),
        .header_insert(header_insert),
        .keep_insert(keep_insert),
        .ready_insert(ready_insert)
    );
    
    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset generator
    initial begin
        rst_n = 0;
        #10;
        rst_n = 1;
    end
    
    initial begin
        ready_out = 0;
        valid_in  = 0;
        valid_insert = 0;
        # 5    ready_out =1;
        # 5    valid_insert = 1;
        # 5    valid_in = 1;  
    end
    
    reg[2:0] insert_index; //指定有效位数
    reg[1:0] input_index; 
    
    initial begin
        insert_index = 0;
        input_index = 0;
        last_in = 0;
    end
    always@(posedge clk)
        begin
            insert_index = $urandom_range(0, 5);
            input_index  = $urandom_range(0, 4);
            case(insert_index)
                0:
                    keep_insert = 4'b0000;
                1:
                    keep_insert = 4'b0001;
                2:
                    keep_insert = 4'b0011;
                3:
                    keep_insert = 4'b0111;
               default:  
                    keep_insert = 4'b1111;
            endcase
            case(input_index)
                0:begin//只有最后一拍会出现有0
                    keep_in = 4'b1000;
                    last_in =1;
                end
                1: begin
                    keep_in = 4'b1100;
                    last_in =1;
                end
                2:begin
                    keep_in = 4'b1110;
                    last_in =1;
                end
               default:begin  
                    keep_in = 4'b1111;
                    last_in =0;
                end
            endcase
            data_in = $urandom; // 32 bit 随机数
            header_insert = $urandom;
            end    
endmodule
