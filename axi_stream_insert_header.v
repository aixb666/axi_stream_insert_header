module axi_stream_insert_header #(
	parameter	DATA_WD = 32,
	parameter	DATA_BYTE_WD = DATA_WD / 8
	) (
	input	clk,
	input	rst_n,
	
	//AXI Stream input original data
	input							valid_in,//����������Ч
	input	[DATA_WD - 1 : 0 ]		data_in,//��������
	input	[DATA_BYTE_WD - 1 :0 ]	keep_in,//data_in����Чλ
	input							last_in,//data_in�����һ��ָ�j
	output							ready_in,//���ݿ�������ָʾ
	
	//AXI Stream output with header inserted
	output	reg						valid_out,//���������Ч
	output	reg [DATA_WD - 1 : 0 ]	data_out,//�������
	output	reg [DATA_BYTE_WD - 1 : 0 ]	keep_out,//data_out����Чλ
	output	reg						last_out,//data_out�����һ��ָ�j
	input							ready_out,//���ݿ������ָʾ
	
	//The header to be inserted to AXI Stream input
	input							valid_insert,//����������Ч
	input	[DATA_WD - 1 : 0 ]		header_insert,//��������
	input	[DATA_BYTE_WD - 1 : 0 ]	keep_insert,//header_insert����Чλ
	output	reg						ready_insert//�������ݿ�������ָʾ
	);
	
	reg	[DATA_WD - 1 : 0 ]			data_out_reg;
	reg								ctr_ready_in;//ready_in���ƣ������Ƿ������������
	parameter	[DATA_WD - 1 : 0]	xxx = 32'hxxxx;//��λxxx
	parameter	[DATA_WD / 8 : 0]	xxx_0 = 4'b0000;//��λ0000
	parameter	[DATA_WD / 8 : 0]	xxx_1 = 4'b1111;//��λ1111
	reg								num_header_0;//header��Чλ��0�ĸ���
	reg								num_data_0;//data��Чλ��0�ĸ���
	reg								n;//n=1����header���������ݣ�n=0����header���������Ѿ������q
	reg								new_data = 1;//�����µ���Ч����ʱ��د1���Տ�ʼ���о�د1
	reg	[DATA_WD - 1 : 0 ]			data_in_reg_1;//����د������ʱ��د������
	reg	[DATA_WD - 1 : 0 ]			data_in_reg_2;//������һ������ʱ��һ������
	reg	[DATA_BYTE_WD - 1 : 0 ]		keep_insert_reg;
	reg	[DATA_BYTE_WD - 1 : 0 ]		keep_in_reg;

	//���ݿ�������ָʾ
	assign	ready_in = ctr_ready_in;
	
	//���ݿ������ʱ�����ݽ������
	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			data_out <= 32'h0000;
		end
		else begin
			data_out <= ready_out ? data_out_reg :data_out;
		end
	end
	
	//header_insertد0��������
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
	
	//data_inد0��������
	always @(last_in) begin
		num_header_0 <= 0;
		if (keep_in_reg[0] == 1'b0) begin
			num_data_0 <= num_data_0 + 1;
			keep_in_reg = keep_in_reg / 2;;
		end
	end
	
	//�����������жϣ�����clk�½��ض�last_in���ж�ȡ����Ϊ������������clk�½��ؽ��У�������new_dataֻ�����¸��غϲ��ܱ�ʹ�ã�
	always @(negedge clk) begin
		new_data <= last_in;
		keep_in_reg <= keep_in;
		if (valid_insert) begin
			n <= 1;
			keep_insert_reg <= keep_insert;
		end
	end
	
	//��Ҫ���ݴ�����
	always @(valid_in && ready_out) begin
		if (ctr_ready_in) begin
			data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , xxx[DATA_WD / 2 : 4 * num_header_0]};
			ctr_ready_in <= 1'b0;
			last_out <= 1'b1;
			keep_out <= {keep_in[DATA_WD / 8 : num_header_0] , xxx_0[num_header_0 - 1 : 0]};
		end
		else if (~last_in && n) begin//��һ�ģ���header�в��
			data_in_reg_1 <= data_in;
			n <= 0;
			data_out_reg <= {16'h0000 , header_insert[(4 * num_header_0 - 1) : 0] , data_in_reg_1[DATA_WD / 2 : 4 * num_header_0]};
			last_out <= 1'b0;
			keep_out <= 4'b1111;
		end
		else if (~last_in && ~n) begin//���ǖc��د��
			data_in_reg_2 <= data_in;
			data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , data_in_reg_2[DATA_WD / 2 : 4 * num_header_0]};
			data_in_reg_1 <= data_in_reg_2;
			last_out <= 1'b0;
			keep_out <= 4'b1111;
		end
		else if (last_in && n) begin//�c��د�ģ���header�в��
			data_in_reg_1 <= data_in;
			n <= 0;
			if ((num_data_0 + num_header_0) >= DATA_WD * 2 / 8) begin//data��Ч��header��Ч��λ������32
				data_out_reg <= {16'h0000 , header_insert[(4 * num_header_0 - 1) : 0] , data_in_reg_1[DATA_WD / 2 : 4 * num_data_0] , xxx[(DATA_WD - 4 * (num_data_0 + num_header_0)) : 0]};
				last_out <= 1'b1;
				keep_out <= {keep_insert[num_header_0 : 0] , keep_in[DATA_WD / 8 : num_data_0 - 1] , xxx_0[(num_data_0 + num_header_0) : 0]};
			end
			else if ((num_data_0 + num_header_0) < DATA_WD * 2 / 8) begin//data��Ч��header��Ч��λ��С��32??�����WҪ�������ʱ�����ڴ���ʣ����ź�
				data_out_reg <= {16'h0000 , header_insert[(4 * num_header_0 - 1) : 0] , data_in_reg_1[DATA_WD / 2 : 4 * num_header_0]};
				ctr_ready_in <= 1'b1;
				last_out <= 1'b0;
				keep_out <= 4'b1111;
			end
		end
		else if (last_in && ~n) begin//�c��د�ģ���header�޲��
			data_in_reg_2 <= data_in;
			if ((num_data_0 + num_header_0) >= DATA_WD * 2 / 8) begin//data�c��د����Ч��header��Ч�ĞSλ������32
				data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , data_in_reg_2[DATA_WD / 2 : 4 * num_data_0] , xxx[(DATA_WD - 4 * (num_data_0 + num_header_0)) : 0]};
				data_in_reg_1 <= data_in_reg_2;
				last_out <= 1'b1;
				keep_out <= {xxx_1[num_header_0 : 0] , keep_in[DATA_WD / 8 : num_data_0 - 1] , xxx_0[(num_data_0 + num_header_0) : 0]};
			end
			else if ((num_data_0 + num_header_0) < DATA_WD * 2 / 8) begin//data�c��د����Ч��header��Ч�ĞSλ��С��32??�����WҪ�������ʱ�����ڴ���ʣ����ź�
				data_out_reg <= {16'h0000 , data_in_reg_1[(4 * num_header_0 - 1) : 0] , data_in_reg_2[DATA_WD / 2 : 4 * num_header_0]};
				ctr_ready_in <= 1'b1;
				last_out <= 1'b0;
				keep_out <= 4'b1111;
				data_in_reg_1 <= data_in_reg_2;
			end
		end
	end
endmodule