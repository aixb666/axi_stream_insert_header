module axi_stream_insert_header #(
	parameter	DATA_WD = 32,
	parameter	DATA_BYTE_WD = DATA_WD / 8
	) (
	input	clk,
	input	rst_n,
	
	//AXI Stream input original data
	input							valid_in,//输入数据有效
	input	[DATA_WD - 1 : 0 ]		data_in,//输入数据
	input	[DATA_BYTE_WD - 1 :0 ]	keep_in,//data_in中有效位
	input							last_in,//data_in中最后一拍指礿
	output							ready_in,//数据可以输入指示
	
	//AXI Stream output with header inserted
	output	reg						valid_out,//输出数据有效
	output	reg [DATA_WD - 1 : 0 ]	data_out,//输出数据
	output	reg [DATA_BYTE_WD - 1 : 0 ]	keep_out,//data_out中有效位
	output	reg						last_out,//data_out中最后一拍指礿
	input							ready_out,//数据可以输出指示
	
	//The header to be inserted to AXI Stream input
	input							valid_insert,//插入数据有效
	input	[DATA_WD - 1 : 0 ]		header_insert,//插入数据
	input	[DATA_BYTE_WD - 1 : 0 ]	keep_insert,//header_insert中有效位
	output	reg						ready_insert//插入数据可以输入指示
	);
	
	reg	[DATA_WD - 1 : 0 ]			data_out_reg;
	reg								ctr_ready_in;//ready_in控制，控制是否继续输入数捿
	parameter	[DATA_WD - 1 : 0]	xxx = 32'hxxxx;//补位xxx
	parameter	[DATA_WD / 8 : 0]	xxx_0 = 4'b0000;//补位0000
	parameter	[DATA_WD / 8 : 0]	xxx_1 = 4'b1111;//补位1111
	reg								num_header_0;//header有效位中0的个敿
	reg								num_data_0;//data有效位中0的个敿
	reg								n;//n=1代表header刚输入数据；n=0代表header输入数据已经被处琿
	reg								new_data = 1;//输入新的有效数据时变丿1，刚弿始运行就丿1
	reg	[DATA_WD - 1 : 0 ]			data_in_reg_1;//满足丿种条件时存丿拍数捿
	reg	[DATA_WD - 1 : 0 ]			data_in_reg_2;//满足另一种条件时存一拍数捿
	reg	[DATA_BYTE_WD - 1 : 0 ]		keep_insert_reg;
	reg	[DATA_BYTE_WD - 1 : 0 ]		keep_in_reg;

	//数据可以输入指示
	assign	ready_in = ctr_ready_in;
	
	//数据可以输出时对数据进行输出
	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			data_out <= 32'h0000;
		end
		else begin
			data_out <= ready_out ? data_out_reg :data_out;
		end
	end
	
	//header_insert丿0个数计算
	always @(posedge clk) begin
		if (new_data) begin
			new_data <= 0;
			num_header_0 <= 0;
			if (keep_insert_reg == 4'b0000) begin
			 num_header_0 <= 4;
			end
			else if (keep_insert_reg[3] == 1'b1) begin
				num_header_0 <= num_header_0 + 1;
				keep_insert_reg = keep_insert_reg * 2;
			end
		end
	end
	
	//data_in丿0个数计算
	always @(last_in) begin
		num_header_0 <= 0;
		if (keep_in_reg[0] == 1'b0) begin
			num_data_0 <= num_data_0 + 1;
			keep_in_reg = keep_in_reg / 2;;
		end
	end
	
	//新数据输入判断（利用clk下降沿对last_in进行读取，因为其他操作都在clk下降沿进行，承以在new_data只能在下个回合才能被使用＿
	always @(negedge clk) begin
		new_data <= last_in;
		keep_in_reg <= keep_in;
		if (valid_insert) begin
			n <= 1;
			keep_insert_reg <= keep_insert;
		end
	end
	
	//主要数据处理部分
	always @(valid_in && ready_out) begin
		if (ctr_ready_in) begin
			data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , xxx[DATA_WD / 2 : 4 * num_header_0]};
			ctr_ready_in <= 1'b0;
			last_out <= 1'b1;
			keep_out <= {keep_in[DATA_WD / 8 : num_header_0] , xxx_0[num_header_0 - 1 : 0]};
		end
		else if (~last_in && n) begin//第一拍，且header有插兿
			data_in_reg_1 <= data_in;
			n <= 0;
			data_out_reg <= {16'h0000 , header_insert[(4 * num_header_0 - 1) : 0] , data_in_reg_1[DATA_WD / 2 : 4 * num_header_0]};
			last_out <= 1'b0;
			keep_out <= 4'b1111;
		end
		else if (~last_in && ~n) begin//不是朿后丿拿
			data_in_reg_2 <= data_in;
			data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , data_in_reg_2[DATA_WD / 2 : 4 * num_header_0]};
			data_in_reg_1 <= data_in_reg_2;
			last_out <= 1'b0;
			keep_out <= 4'b1111;
		end
		else if (last_in && n) begin//朿后丿拍，且header有插兿
			data_in_reg_1 <= data_in;
			n <= 0;
			if ((num_data_0 + num_header_0) >= DATA_WD * 2 / 8) begin//data无效和header无效总位数大亿32
				data_out_reg <= {16'h0000 , header_insert[(4 * num_header_0 - 1) : 0] , data_in_reg_1[DATA_WD / 2 : 4 * num_data_0] , xxx[(DATA_WD - 4 * (num_data_0 + num_header_0)) : 0]};
				last_out <= 1'b1;
				keep_out <= {keep_insert[num_header_0 : 0] , keep_in[DATA_WD / 8 : num_data_0 - 1] , xxx_0[(num_data_0 + num_header_0) : 0]};
			end
			else if ((num_data_0 + num_header_0) < DATA_WD * 2 / 8) begin//data无效和header无效总位数小亿32??导致霿要再引入个时钟周期处理剩余的信号
				data_out_reg <= {16'h0000 , header_insert[(4 * num_header_0 - 1) : 0] , data_in_reg_1[DATA_WD / 2 : 4 * num_header_0]};
				ctr_ready_in <= 1'b1;
				last_out <= 1'b0;
				keep_out <= 4'b1111;
			end
		end
		else if (last_in && ~n) begin//朿后丿拍，且header无插兿
			data_in_reg_2 <= data_in;
			if ((num_data_0 + num_header_0) >= DATA_WD * 2 / 8) begin//data朿后丿拍无效和header无效的濻位数大亿32
				data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , data_in_reg_2[DATA_WD / 2 : 4 * num_data_0] , xxx[(DATA_WD - 4 * (num_data_0 + num_header_0)) : 0]};
				data_in_reg_1 <= data_in_reg_2;
				last_out <= 1'b1;
				keep_out <= {xxx_1[num_header_0 : 0] , keep_in[DATA_WD / 8 : num_data_0 - 1] , xxx_0[(num_data_0 + num_header_0) : 0]};
			end
			else if ((num_data_0 + num_header_0) < DATA_WD * 2 / 8) begin//data朿后丿拍无效和header无效的濻位数小亿32??导致霿要再引入个时钟周期处理剩余的信号
				data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , data_in_reg_2[DATA_WD / 2 : 4 * num_header_0]};
				ctr_ready_in <= 1'b1;
				last_out <= 1'b0;
				keep_out <= 4'b1111;
				data_in_reg_1 <= data_in_reg_2;
			end
		end
	end
endmodule