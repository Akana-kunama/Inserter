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

	reg [DATA_WD-1 : 0] data_in_t;					//data_in�źŴ�һ�ģ���������ƴ�����
	reg ready_in_t;									//ready_in�źŴ�һ�ģ�������ȡ�����غ��½���
	reg [DATA_BYTE_WD-1 : 0] keep_insert_lock;		//keep_insert�źżĴ棬����ȷ�����һ�����������Чλ��

	wire ready_in_up, ready_in_down;				//ȡready_in�������û����ͷ�����ݣ�ȡready_in�½�������ȷ��β������
	assign ready_in_up = ~ready_in_t && ready_in;    
	assign ready_in_down = ready_in_t && ~ready_in;	 

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_in <= 0;
		end
		else if (last_in) begin// �����ʱ����������һ������
			ready_in <= 0;      //����������ر�
		end
		else if (ready_out && valid_insert && valid_in) begin //�����ʱ ��������롢���붼������
			ready_in <= 1;  // ��ô�������� data
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
		else if (ready_in) begin  // ��ʱ����������data��data���ڴ��䣩
			ready_insert <= 0;    // ����������ر�
		end
		else if (ready_out && valid_insert && valid_in) begin //��ready_in ��Ϊ1��ʱ����ܹ�������룬����Ҫ��
			ready_insert <= 1;     // data���ȼ�����
		end
		else begin
			ready_insert <= ready_insert;  // �����������
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			data_in_t <= 0;              
		end
		else if (ready_in) begin  //���������źŵ�ʱ���һ�ű��ں���ƴ��
			data_in_t <= data_in;    
		end
		else begin
			data_in_t <= data_in_t;  //��data_in_t����ס
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
		else if (ready_in_up) begin  //ready_in������ 
			case (keep_insert)       //�ж�header ��Чλ��
				4'b1111:data_out <= header_insert;  
				4'b0111:data_out <= {header_insert[23:0],data_in[DATA_WD-1:24]};
				4'b0011:data_out <= {header_insert[15:0],data_in[DATA_WD-1:16]};
				4'b0001:data_out <= {header_insert[7:0],data_in[DATA_WD-1:8]};
				4'b0000:data_out <= data_in;
				default : data_out <= data_out;
			endcase
			valid_out <= 1;  //ͷ��ƴ�ӽ�����   �����ͨ����
			keep_out <= 4'b1111; // ͷ��ȫ����Ч
			last_out <= 0;       
			keep_insert_lock <= keep_insert; // �����ڰ�ͷ���д洢
		end
		else if (ready_in) begin  //ready_in�ĸߵ�ƽ��data_in_t����һ���ڵ�data_in
			case (keep_insert_lock)
				4'b1111:data_out <= data_in_t;
				4'b0111:data_out <= {data_in_t[23:0],data_in[DATA_WD-1:24]};
				4'b0011:data_out <= {data_in_t[15:0],data_in[DATA_WD-1:16]};
				4'b0001:data_out <= {data_in_t[7:0],data_in[DATA_WD-1:8]};
				4'b0000:data_out <= data_in;
				default : data_out <= data_out;
			endcase
			valid_out <= 1;  //�׶ν���ʹ�����
			keep_out <= 4'b1111; 
			last_out <= 0;
			keep_insert_lock <= keep_insert_lock;
		end
		else if (ready_in_down) begin // ��ready_in�½���ʱ�򣬽������һ֡����
			case ({keep_insert_lock, keep_in})   //  �ȶ԰�ͷ��Чλ�����һ֡����Чλ
				16'b1111_1111:begin             // ����4byte��Ч
					data_out <= data_in_t;     //  ֱ����Ϊ���һ�ֽ����
					valid_out <= 1;
					keep_out <= 4'b1111;
					last_out <= 1;
				end
				16'b1111_1110:begin         // ��ͷ4byte��Ч�����һ֡3byte��Ч
					data_out <= {data_in_t[DATA_WD-1:8],8'b0};     //ĩ�˲���
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
				16'b0111_1111:begin     // ��ͷ4byte��Ч�����һ֡3byte��Ч
					data_out <= {data_in_t[23:0],8'b0};    //��ͷ3byte��Ч�Ļ�����������лὫ���������ͷ1byte���룬���������ʣ��3byte��ĩβ����
					valid_out <= 1;
					keep_out <= 4'b1110;
					last_out <= 1;
				end
				16'b0111_1110:begin                     //��ͷ3byte��Ч�Ļ�����������лὫ���������ͷ1byte���룬���������ʣ��2byte��ĩβ����
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
				16'b0011_1111:begin                     //��ͷ2byte��Ч�Ļ�����������лὫ���������ͷ2byte���룬���������ʣ��2byte��ĩβ����
					data_out <= {data_in_t[15:0],16'b0};
					valid_out <= 1;
					keep_out <= 4'b1100;
					last_out <= 1;
				end
				16'b0011_1110:begin                      //��ͷ2byte��Ч�Ļ�����������лὫ���������ͷ2byte���룬���������ʣ��1byte��ĩβ����
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
		else begin // ready_in ʧ�ܵ�ʱ��
			data_out <= data_out;
			keep_out <= keep_out;
			keep_insert_lock <= keep_insert_lock;
			last_out <= 0;
			valid_out <= 0;
		end
	end
endmodule