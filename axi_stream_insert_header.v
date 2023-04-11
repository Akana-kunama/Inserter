module axi_stream_insert_header #(
	parameter DATA_WD = 32,
	parameter DATA_BYTE_WD = DATA_WD / 8
) (
	input clk,
	input rst_n,

	// AXI Stream input original data
	input valid_in,
	input [DATA_WD-1 : 0] data_in,
	input [DATA_BYTE_WD-1 : 0] keep_in,
	input last_in,
	output reg ready_in,

	// The header to be inserted to AXI Stream input
	input valid_insert,
	input [DATA_WD-1 : 0] header_insert,
	input [DATA_BYTE_WD-1 : 0] keep_insert,
	output reg ready_insert,

	// AXI Stream output with header inserted
	output reg valid_out,
	output reg [DATA_WD-1 : 0] data_out,
	output reg [DATA_BYTE_WD-1 : 0] keep_out,
	output reg last_out,
	input ready_out
);

	reg [DATA_WD-1 : 0] data_in_t;					//data_in信号打一拍，用于数据拼接输出
	reg ready_in_t;									//ready_in信号打一拍，用于提取上升沿和下降沿
	reg [DATA_BYTE_WD-1 : 0] keep_insert_lock;		//keep_insert信号寄存，用于确定最后一个输出数据有效位数

	wire ready_in_up, ready_in_down;				//取ready_in上升沿用户添加头部数据，取ready_in下降沿用于确定尾部数据
	assign ready_in_up = ~ready_in_t && ready_in;    
	assign ready_in_down = ready_in_t && ~ready_in;	 

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_in <= 0;
		end
		else if (last_in) begin// 如果此时输入的是最后一个数据
			ready_in <= 0;      //将允许输入关闭
		end
		else if (ready_out && valid_insert && valid_in) begin //如果此时 输出、输入、插入都被允许
			ready_in <= 1;  // 那么允许输入 data
		end
		else begin
			ready_in <= ready_in;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_in_t <= 0;
		end
		else begin
			ready_in_t <= ready_in;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_insert <= 0;
		end 
		else if (ready_in) begin  // 此时允许传输数据data（data正在传输）
			ready_insert <= 0;    // 将插入允许关闭
		end
		else if (ready_out && valid_insert && valid_in) begin //当ready_in 不为1的时候才能够允许插入，且需要有
			ready_insert <= 1;     // data优先级更高
		end
		else begin
			ready_insert <= ready_insert;  // 持续允许插入
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			data_in_t <= 0;              
		end
		else if (ready_in) begin  //允许输入信号的时候打一排便于后续拼接
			data_in_t <= data_in;    
		end
		else begin
			data_in_t <= data_in_t;  //将data_in_t保持住
		end
	end


	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			data_out <= 0;
			keep_out <= 0;
			last_out <= 0;
			valid_out <= 0;
			keep_insert_lock <= 0;
		end
		else if (ready_in_up) begin  //ready_in上升沿 
			case (keep_insert)       //判断header 有效位数
				4'b1111:data_out <= header_insert;  
				4'b0111:data_out <= {header_insert[23:0],data_in[DATA_WD-1:24]};
				4'b0011:data_out <= {header_insert[15:0],data_in[DATA_WD-1:16]};
				4'b0001:data_out <= {header_insert[7:0],data_in[DATA_WD-1:8]};
				4'b0000:data_out <= data_in;
				default : data_out <= data_out;
			endcase
			valid_out <= 1;  //头部拼接结束后   将输出通道打开
			keep_out <= 4'b1111; // 头部全部有效
			last_out <= 0;       
			keep_insert_lock <= keep_insert; // 将本节包头进行存储
		end
		else if (ready_in) begin  //ready_in的高电平，data_in_t是上一周期的data_in
			case (keep_insert_lock)
				4'b1111:data_out <= data_in_t;
				4'b0111:data_out <= {data_in_t[23:0],data_in[DATA_WD-1:24]};
				4'b0011:data_out <= {data_in_t[15:0],data_in[DATA_WD-1:16]};
				4'b0001:data_out <= {data_in_t[7:0],data_in[DATA_WD-1:8]};
				4'b0000:data_out <= data_in;
				default : data_out <= data_out;
			endcase
			valid_out <= 1;  //阶段结束使能输出
			keep_out <= 4'b1111; 
			last_out <= 0;
			keep_insert_lock <= keep_insert_lock;
		end
		else if (ready_in_down) begin // 当ready_in下降的时候，接入最后一帧数据
			case ({keep_insert_lock, keep_in})   //  比对包头有效位和最后一帧的有效位
				16'b1111_1111:begin             // 都是4byte有效
					data_out <= data_in_t;     //  直接作为最后一字节输出
					valid_out <= 1;
					keep_out <= 4'b1111;
					last_out <= 1;
				end
				16'b1111_1110:begin         // 包头4byte有效而最后一帧3byte有效
					data_out <= {data_in_t[DATA_WD-1:8],8'b0};     //末端补零
					valid_out <= 1;
					keep_out <= 4'b1110;
					last_out <= 1;
				end
				16'b1111_1100:begin
					data_out <= {data_in_t[DATA_WD-1:16],16'b0};
					valid_out <= 1;
					keep_out <= 4'b1100;
					last_out <= 1;
				end
				16'b1111_1000:begin
					data_out <= {data_in_t[DATA_WD-1:24],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				16'b0111_1111:begin     // 包头4byte有效而最后一帧3byte有效
					data_out <= {data_in_t[23:0],8'b0};    //包头3byte有效的话，输入过程中会将后续输入的头1byte补入，因而后续仅剩后3byte，末尾补零
					valid_out <= 1;
					keep_out <= 4'b1110;
					last_out <= 1;
				end
				16'b0111_1110:begin                     //包头3byte有效的话，输入过程中会将后续输入的头1byte补入，因而后续仅剩后2byte，末尾补零
					data_out <= {data_in_t[23:8],16'b0};
					valid_out <= 1;
					keep_out <= 4'b1100;
					last_out <= 1;
				end
				16'b0111_1100:begin
					data_out <= {data_in_t[23:16],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				16'b0011_1111:begin                     //包头2byte有效的话，输入过程中会将后续输入的头2byte补入，因而后续仅剩后2byte，末尾补零
					data_out <= {data_in_t[15:0],16'b0};
					valid_out <= 1;
					keep_out <= 4'b1100;
					last_out <= 1;
				end
				16'b0011_1110:begin                      //包头2byte有效的话，输入过程中会将后续输入的头2byte补入，因而后续仅剩后1byte，末尾补零
					data_out <= {data_in_t[15:8],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				16'b0001_1111:begin
					data_out <= {data_in_t[7:0],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				default : begin
					data_out <= data_in_t;
					valid_out <= 1;
					keep_out <= 4'b0000;
					last_out <= 1;
				end
			endcase
			keep_insert_lock <= keep_insert_lock;
		end
		else begin // ready_in 失能的时候
			data_out <= data_out;
			keep_out <= keep_out;
			keep_insert_lock <= keep_insert_lock;
			last_out <= 0;
			valid_out <= 0;
		end
	end
endmodule