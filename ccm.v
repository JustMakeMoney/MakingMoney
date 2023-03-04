// ===============================================================================
//  This confidential and proprietary software may be used only as
//  authorised by a licensing agreement from WNRC@KETI
//    (C) Copyright 2007~ WNRC@KETI
//        ALL RIGHTS RESERVED
//  The entire notice above must be reproduced on all authorised
//  copies and copies may only be made to the extent permitted
//  by a licensing agreement from WNRC@KETI
// ==============================================================================
// PROJECT NAME : GUARDIAN_UPT 
// FILE NAME	: $RCSfile: ccm.v,v $
// AUTHOR		: $Author: yslim $
// DATE			: $Date: 2011/07/01 07:09:36 $
// TAG 			: $Name:  $	 
// REVISION 	: $Revision: 1.1.1.1 $	 
// DESCRIPTION  : 
// ==============================================================================



/********************************************************************************
* Modified History :
*	  Date	|		By	|  Version	| Change Description
*-------------------------------------------------------------------
* 06/21/2005	: Hyeon Seok Lee	|    0.1	| Original
* 04/11/2008	: Hyeon Seok Lee	|    0.2	| CBC-MAC + CTR
*********************************************************************************/


`timescale 1ns/1ps

`define	CCM_IDLE			4'd0
`define	CCM_START			4'd1
`define	CCM_KEY_FIND_START		4'd2
`define	CCM_KEY_FOUND			4'd3
`define	CCM_KEY_NOT_FOUND		4'd4
`define	CCM_ENC_S_0			4'd5
`define	CCM_AUTH_ONLY			4'd6
`define	CCM_ENC				4'd7
`define	CCM_ENC_AUTH			4'd8
`define	CCM_NO_SEC			4'd9
`define	CCM_MIC				4'd10
`define	CCM_FINISH			4'd11

`define	CCM_TX_STS_IDLE			3'd0
`define	CCM_TX_STS_KEY_FOUND		3'd1
`define	CCM_TX_STS_KEY_NOT_FOUND	3'd2
`define	CCM_TX_STS_ENC_OK		3'd3

`define	CCM_RX_STS_IDLE			3'd0
`define	CCM_RX_STS_KEY_FOUND		3'd1
`define	CCM_RX_STS_KEY_NOT_FOUND	3'd2
`define	CCM_RX_STS_MIC_ERR		3'd3
`define	CCM_RX_STS_REPLAY_ERR		3'd4
`define	CCM_RX_STS_DEC_OK		3'd5


`define	MAC_HDR_LENGTH			12'd8
`define	MIC_LENGTH			12'd8
`define	SEC_HDR_LENGTH			12'd6
`define	FRAME_CTRL_OFFSET		12'd4
`define	TKID_0_OFFSET			12'd8
`define	TKID_1_OFFSET			12'd9
`define	SFN_0_OFFSET			12'd10
`define	SFN_1_OFFSET			12'd11
`define	EO_0_OFFSET			12'd12
`define	EO_1_OFFSET			12'd13
`define	CMD_TYPE_OFFSET			12'd14
`define	BEACON_TOKEN_OFFSET		12'd14
`define	KEY_LENGTH			12'd16


// Packet Type
`define	PT_BEACON			4'b0000
`define	PT_ACK				4'b0001
`define	PT_COMMAND			4'b0010
`define	PT_DATA				4'b0011
`define	PT_RTS				4'b0100
`define	PT_CTS				4'b0101


module ccm (
		rst_n,
		clk,
		
		// DPC(Data Path Controller)
		i_dpc_tx_en,	//Data path Controller tx enable
		i_dpc_rx_en, 	//Data path Controller tx enable
		i_dpc_length,	//Data path Controller length 12bit
		i_dpc_data_en,	//Data path Controller data enable
		i_dpc_data,		//Data path Controller data	8bit
		o_dpc_data_en,	//Data path Controller data input enable
		o_dpc_data,		//Data path Controller output data enable 8bit
		o_dpc_wait,		//??
		
		// MAC(Message authentication code)
		i_reg_time_token,	//clock_token 16bit
		o_mac_encrypt_sts,	//encryption_mode_state 3bit
		o_mac_decrypt_sts,	//3bit
		
		// SEC
		o_sec_en,		
		o_sec_ed,
		o_sec_go,
		o_sec_data,		//128bit
		i_sec_data_out_vld,
		i_sec_data,		//128bit
		i_sec_data_req,
		
		// Key Pool
		o_kp_tkid,		//?? 16bit
		o_kp_key_find,	//key Pool key find?
		i_kp_key,		//128
		i_kp_sfn,		//16
		i_kp_key_sts,	//2 10:  KEY_FOUND
		
		// Key Scheduler
		o_ks_en,
		o_ks_key,		//128
		i_ks_key_expand_end
);


input		rst_n;
input		clk;
		
// DPC (Data Path Controller)
input		i_dpc_tx_en;
input		i_dpc_rx_en;
input	[11:0]	i_dpc_length;		// MAC_HDR + payload_length;(include MIC)
input		i_dpc_data_en;
input	[7:0]	i_dpc_data;
output		o_dpc_data_en;
output	[7:0]	o_dpc_data;
output		o_dpc_wait;

// MAC
input	[15:0]	i_reg_time_token;
output	[2:0]	o_mac_encrypt_sts;
output	[2:0]	o_mac_decrypt_sts;
		
// SEC
output		o_sec_en;
output		o_sec_ed;
output		o_sec_go;
output	[127:0]	o_sec_data;
input		i_sec_data_out_vld;
input	[127:0]	i_sec_data;
input		i_sec_data_req;
		
// Key Pool or REG
output	[15:0]	o_kp_tkid;
output		o_kp_key_find;
input	[127:0]	i_kp_key;
input	[15:0]	i_kp_sfn;
input	[1:0]	i_kp_key_sts;

// Key Scheduler
input		i_ks_key_expand_end;
output	[127:0]	o_ks_key;
output		o_ks_en;


// registers & wires for outputs
reg		o_dpc_data_en;
reg	[7:0]	o_dpc_data;
wire		o_dpc_wait;
reg	[2:0]	o_mac_encrypt_sts;
reg	[2:0]	o_mac_decrypt_sts;
reg		o_sec_en;
wire		o_sec_ed;
reg		o_sec_go;
wire	[127:0]	o_sec_data;
reg	[15:0]	o_kp_tkid;
reg		o_kp_key_find;
reg	[127:0]	o_ks_key;
wire		o_ks_en;


// internal registers & wires
reg	[3:0]	ccm_sts;
reg	[63:0]	mac_hdr;
reg	[15:0]	enc_offset; //360
reg	[15:0]	wr_cnt;
reg	[7:0]	wr_fifo[0:15];
reg	[15:0]	rd_cnt;
wire	[103:0]	ccm_nonce;
wire	[15:0]	auth_data_length;
wire	[15:0]	enc_data_length;
wire	[15:0]	enc_blk_cnt_n;
wire	[15:0]	enc_data_rd_cnt;
wire		length_valid;
reg		length_valid_d;
reg	[15:0]	last_wr_blk_cnt;
wire	[7:0]	enc_flags;
wire	[7:0]	auth_flags;
wire		auth_blk_0_n_1_ready;
wire	[127:0]	enc_blk_a;
wire	[127:0]	enc_blk_0;
reg	[127:0]	enc_s_0;
reg	[15:0]	enc_blk_cnt;
reg		temp_data_en;
reg	[127:0]	temp_data_out;
reg	[127:0]	enc_blk_data_in;
wire		last_blk_ready;
wire		ccm_en;
wire	[127:0]	auth_blk_0;
wire	[127:0]	auth_blk_1;
wire		sec_on;
wire	[3:0]	frame_type;
reg	[15:0]	sfn;
reg	[63:0]	mic;
wire	[127:0]	mic_tmp;
reg	[127:0]	auth_data_tmp;
wire	[15:0]	auth_blk_cnt_n;
reg	[15:0]	auth_blk_cnt;
reg	[127:0]	auth_blk_data_in;
wire	[3:0]	auth_length_1;
wire	[3:0]	auth_length_2;
wire	[4:0]	write_point_1;
wire	[4:0]	write_point_2;
wire	[4:0]	write_point_3;
wire	[4:0]	write_point_4;
wire	[4:0]	write_point_5;
wire	[4:0]	write_point_6;
wire	[4:0]	write_point_7;
wire	[4:0]	write_point_8;
wire	[4:0]	write_point_9;
wire	[4:0]	write_point_10;
wire	[4:0]	write_point_11;
wire	[4:0]	write_point_12;
wire	[4:0]	write_point_13;
wire	[4:0]	write_point_14;
wire	[4:0]	write_point_15;
reg	[15:0]	time_token;


assign		ccm_en = (i_dpc_tx_en | i_dpc_rx_en);

integer i;

// ccm_sts
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		ccm_sts <= `CCM_IDLE;
	else if (ccm_en)
		if (ccm_sts == `CCM_IDLE)
			ccm_sts <= `CCM_START;
		else if (ccm_sts == `CCM_START)//assign		sec_on = mac_hdr[27]
			if (wr_cnt == `FRAME_CTRL_OFFSET && sec_on == 1'b0) //4
				ccm_sts <= `CCM_NO_SEC;//TKID_1_OFFSET == 9
			else if (wr_cnt == `TKID_1_OFFSET && i_dpc_data_en == 1'b1)
				ccm_sts <= `CCM_KEY_FIND_START;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_KEY_FIND_START)
			if (i_kp_key_sts == 2'b10)
				ccm_sts <= `CCM_KEY_FOUND;
			else if (i_kp_key_sts == 2'b11)
				ccm_sts <= `CCM_KEY_NOT_FOUND;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_KEY_FOUND)
			if (i_ks_key_expand_end == 1'b1)
				ccm_sts <= `CCM_ENC_S_0;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_ENC_S_0)
			if (i_sec_data_out_vld == 1)
				ccm_sts <= `CCM_AUTH_ONLY;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_AUTH_ONLY)
			if (auth_blk_cnt == auth_blk_cnt_n - 1)		//wire	[15:0]	auth_blk_cnt_n;  reg	[15:0]	auth_blk_cnt;
				if (i_sec_data_out_vld == 1'b1)
					if (enc_data_length == 16'd0)
						ccm_sts <= `CCM_MIC;
					else
						ccm_sts <= `CCM_ENC;
				else
					ccm_sts <= ccm_sts;
			else
				ccm_sts <= ccm_sts;		
		else if (ccm_sts == `CCM_ENC)
			if (i_sec_data_out_vld == 1'b1)
				ccm_sts <= `CCM_ENC_AUTH;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_ENC_AUTH)
			if (i_sec_data_out_vld == 1'b1)
				if (auth_blk_cnt < auth_blk_cnt_n + enc_blk_cnt_n - 1)
					ccm_sts <= `CCM_ENC;
				else
					ccm_sts <= `CCM_MIC;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_NO_SEC)
			if (rd_cnt == i_dpc_length)
				ccm_sts <= `CCM_FINISH;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_KEY_NOT_FOUND)
			if (i_dpc_tx_en == 1'b1)
				ccm_sts <= `CCM_FINISH;
			else if (i_dpc_rx_en == 1'b1 && rd_cnt == auth_data_length + enc_data_length)
				ccm_sts <= `CCM_FINISH;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_MIC)
			if (rd_cnt == auth_data_length + enc_data_length + `MIC_LENGTH)
				ccm_sts <= `CCM_FINISH;
			else
				ccm_sts <= ccm_sts;
		else if (ccm_sts == `CCM_FINISH)
			ccm_sts <= ccm_sts;
		else
			ccm_sts <= ccm_sts;
	else
		ccm_sts <= `CCM_IDLE;


// mac_hdr
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		mac_hdr <= 64'h0;
	else if (ccm_en)
		if (i_dpc_data_en == 1'b1)
			case (wr_cnt) 
				11'd0 : mac_hdr[7:0] <= i_dpc_data;
				11'd1 : mac_hdr[15:8] <= i_dpc_data;
				11'd2 : mac_hdr[23:16] <= i_dpc_data;
				11'd3 : mac_hdr[31:24] <= i_dpc_data;
				11'd4 : mac_hdr[39:32] <= i_dpc_data;
				11'd5 : mac_hdr[47:40] <= i_dpc_data;
				11'd6 : mac_hdr[55:48] <= i_dpc_data;
				11'd7 : mac_hdr[63:56] <= i_dpc_data;
				default : mac_hdr <= mac_hdr;
			endcase
		else
			mac_hdr <= mac_hdr;
	else
		mac_hdr <= 64'h0;

wire	[15:0]	auth_pay_length;
assign		auth_pay_length = auth_data_length - `MAC_HDR_LENGTH - `SEC_HDR_LENGTH; // 

// enc_blk_cnt_n, auth_blk_cnt_n
assign	enc_blk_cnt_n = (enc_data_length + 15) >> 4;
assign	auth_blk_cnt_n = ((auth_pay_length + 15) >> 4) + 2;

assign		auth_length_1 = auth_pay_length[3:0];
assign		auth_length_2 = enc_data_length[3:0];

assign		sec_on = mac_hdr[27];
assign		frame_type = mac_hdr[19:16];

//[15:0]enc_offset
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		enc_offset <= 16'h0;
	else if (ccm_en)
		if (wr_cnt == `EO_0_OFFSET && i_dpc_data_en == 1'b1)//wr_cnt == 12
			enc_offset[7:0] <= i_dpc_data[7:0];
		else if (wr_cnt == `EO_1_OFFSET && i_dpc_data_en == 1'b1)
			enc_offset[15:8] <= i_dpc_data[7:0];
		else
			enc_offset <= enc_offset;
	else
		enc_offset <= 16'h0;


// sfn
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		sfn <= 16'h0;
	else if (ccm_en)
		if (wr_cnt == `SFN_0_OFFSET && i_dpc_data_en == 1'b1)
			sfn[7:0] <= i_dpc_data[7:0];
		else if (wr_cnt == `SFN_1_OFFSET && i_dpc_data_en == 1'b1)
			sfn[15:8] <= i_dpc_data[7:0];
		else
			sfn <= sfn;
	else
		sfn <= 16'h0;


/*		
assign		length_valid = (wr_cnt >= `EO_1_OFFSET + 1);
assign		auth_data_length = enc_offset + `MAC_HDR_LENGTH + `SEC_HDR_LENGTH;
assign		enc_data_length = i_dpc_length - `SEC_HDR_LENGTH - enc_offset[10:0] - `MIC_LENGTH;
*/

assign		length_valid = (wr_cnt >= `EO_1_OFFSET + 1);
assign		auth_data_length = `MAC_HDR_LENGTH + `SEC_HDR_LENGTH + enc_offset; // blk flagb  1 || n  13 || p 
assign		enc_data_length = i_dpc_length - auth_data_length - `MIC_LENGTH;

always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		length_valid_d <= 1'b0;
	else
		length_valid_d <= length_valid;

// wr_cnt
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		wr_cnt <= 16'd0;
	else if (ccm_en)
		if (i_dpc_data_en == 1'b1)
			wr_cnt <= wr_cnt + 1;
		else
			wr_cnt <= wr_cnt;
	else
		wr_cnt <= 16'd0;

// wr_fifo
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		for (i=0; i<16; i=i+1)
			wr_fifo[i] <= 8'h0;
	else if (ccm_en)
		if (i_dpc_data_en == 1'b1)
			wr_fifo[wr_cnt[3:0]] <= i_dpc_data;
		else begin
			for (i=0; i<16; i=i+1)
				wr_fifo[i] <= wr_fifo[i];
		end
	else
		for (i=0; i<16; i=i+1)
			wr_fifo[i] <= 8'h0;

// time_token
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		time_token <= 16'h0;
	else if (ccm_en)
		if (frame_type == `PT_BEACON)
			if (wr_cnt == `BEACON_TOKEN_OFFSET && i_dpc_data_en == 1'b1)
				time_token[7:0] <= i_dpc_data;
			else if (wr_cnt == `BEACON_TOKEN_OFFSET + 1 && i_dpc_data_en == 1'b1)
				time_token[15:8] <= i_dpc_data;
			else
				time_token <= time_token;
		else
			time_token <= time_token;
	else
		time_token <= time_token;

assign		ccm_nonce = { o_kp_tkid[7:0],			// Temporal Key ID
				sfn[15:0],			// Secure Frame Number //
				time_token[15:0],		// Time Token // 시간이면은 보통 밀ㄹ초 단위로 한다고 치면은 nonce 재사용을 
				mac_hdr[63:0] };		// MAC Header


				
// rd_cnt
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		rd_cnt <= 16'd0;
	else if (ccm_en)
		if (temp_data_en == 1'b1)
			rd_cnt <= rd_cnt + 1;
		else
			rd_cnt <= rd_cnt;
	else
		rd_cnt <= 16'd0;

// enc_data_rd_cnt
assign	enc_data_rd_cnt = rd_cnt - auth_data_length;

// last_wr_blk_cnt
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		last_wr_blk_cnt <= 16'd0;
	else if (ccm_en)
		if (ccm_sts == `CCM_AUTH_ONLY)
			if (i_sec_data_out_vld == 1'b1)
				if (auth_blk_cnt == 16'd0 || auth_blk_cnt == 16'd1)
					last_wr_blk_cnt <= `MAC_HDR_LENGTH + `SEC_HDR_LENGTH;
				else if (auth_blk_cnt < auth_blk_cnt_n - 1)
					last_wr_blk_cnt <= last_wr_blk_cnt + 16;
				else if (auth_blk_cnt == auth_blk_cnt_n - 1)
					if (auth_length_1 == 0)
						last_wr_blk_cnt <= last_wr_blk_cnt + 16;
					else
						last_wr_blk_cnt <= last_wr_blk_cnt + auth_length_1;
				else
					last_wr_blk_cnt <= last_wr_blk_cnt;
			else
				last_wr_blk_cnt <= last_wr_blk_cnt;
		else if (ccm_sts == `CCM_ENC)
			if (i_sec_data_out_vld == 1'b1)
				if (enc_blk_cnt < enc_blk_cnt_n - 1)
					last_wr_blk_cnt <= last_wr_blk_cnt + 16;
				else if (enc_blk_cnt == enc_blk_cnt_n - 1)
					if (auth_length_2 == 0)
						last_wr_blk_cnt <= last_wr_blk_cnt + 16;
					else
						last_wr_blk_cnt <= last_wr_blk_cnt + auth_length_2;
				else
					last_wr_blk_cnt <= last_wr_blk_cnt;
			else
				last_wr_blk_cnt <= last_wr_blk_cnt;
		else if (ccm_sts == `CCM_ENC_AUTH)
			last_wr_blk_cnt <= last_wr_blk_cnt;
		else
			last_wr_blk_cnt <= last_wr_blk_cnt;
	else		
		last_wr_blk_cnt <= 16'd0;

// temp_data_en
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		temp_data_en <= 1'b0;
	else if (ccm_en)
		if (ccm_sts == `CCM_START
			|| ccm_sts == `CCM_KEY_FIND_START
			|| ccm_sts == `CCM_KEY_FOUND
			|| ccm_sts == `CCM_ENC_S_0
			|| ccm_sts == `CCM_AUTH_ONLY)
			if (wr_cnt < auth_data_length || length_valid_d == 1'b0)
				temp_data_en <= i_dpc_data_en;
			else
				temp_data_en <= 1'b0;
		else if (ccm_sts == `CCM_NO_SEC)
			if (wr_cnt < i_dpc_length)
				temp_data_en <= i_dpc_data_en;
			else
				temp_data_en <= 1'b0;
		else if (ccm_sts == `CCM_KEY_NOT_FOUND)
			if (wr_cnt < i_dpc_length)
				temp_data_en <= i_dpc_data_en;
			else
				temp_data_en <= 1'b0;
		else if (ccm_sts == `CCM_ENC || ccm_sts == `CCM_ENC_AUTH)
			if (rd_cnt < last_wr_blk_cnt - 1 || (rd_cnt == last_wr_blk_cnt -1 && temp_data_en == 1'b0))
				temp_data_en <= 1'b1;
			else
				temp_data_en <= 1'b0;
		else if (ccm_sts == `CCM_MIC)
			if (wr_cnt > rd_cnt + 1
				|| (wr_cnt == rd_cnt + 1 && temp_data_en == 1'b0))
				temp_data_en <= 1'b1;
			else
				temp_data_en <= 1'b0;
		else if (ccm_sts == `CCM_FINISH)
			temp_data_en <= i_dpc_data_en;
//			temp_data_en <= 1'b0;
		else
			temp_data_en <= 1'b0;
	else
		temp_data_en <= 1'b0;

// o_dpc_data_en
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_dpc_data_en <= 1'b0;
	else
		o_dpc_data_en <= temp_data_en;

// last_blk_ready
assign		last_blk_ready = (wr_cnt >= auth_data_length + enc_data_length) && (length_valid_d == 1'b1);

assign		write_point_1 = last_wr_blk_cnt[3:0] + 1;
assign		write_point_2 = last_wr_blk_cnt[3:0] + 2;
assign		write_point_3 = last_wr_blk_cnt[3:0] + 3;
assign		write_point_4 = last_wr_blk_cnt[3:0] + 4;
assign		write_point_5 = last_wr_blk_cnt[3:0] + 5;
assign		write_point_6 = last_wr_blk_cnt[3:0] + 6;
assign		write_point_7 = last_wr_blk_cnt[3:0] + 7;
assign		write_point_8 = last_wr_blk_cnt[3:0] + 8;
assign		write_point_9 = last_wr_blk_cnt[3:0] + 9;
assign		write_point_10 = last_wr_blk_cnt[3:0] + 10;
assign		write_point_11 = last_wr_blk_cnt[3:0] + 11;
assign		write_point_12 = last_wr_blk_cnt[3:0] + 12;
assign		write_point_13 = last_wr_blk_cnt[3:0] + 13;
assign		write_point_14 = last_wr_blk_cnt[3:0] + 14;
assign		write_point_15 = last_wr_blk_cnt[3:0] + 15;

// enc_blk_data_in
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		enc_blk_data_in <= 128'b0;
	else if (ccm_en)
		if (ccm_sts == `CCM_ENC)
			if ((enc_blk_cnt <= enc_blk_cnt_n - 1)
//				&& (wr_cnt - last_wr_blk_cnt == 16'd16 || wr_cnt == auth_data_length + enc_data_length))  begin
				&& (wr_cnt - last_wr_blk_cnt == 16'd16 || (last_blk_ready == 1'b1 && o_sec_go == 1'b0)))  begin
				enc_blk_data_in[7:0] <= wr_fifo[last_wr_blk_cnt[3:0]];
				enc_blk_data_in[15:8] <= wr_fifo[write_point_1[3:0]];
				enc_blk_data_in[23:16] <= wr_fifo[write_point_2[3:0]];
				enc_blk_data_in[31:24] <= wr_fifo[write_point_3[3:0]];
				enc_blk_data_in[39:32] <= wr_fifo[write_point_4[3:0]];
				enc_blk_data_in[47:40] <= wr_fifo[write_point_5[3:0]];
				enc_blk_data_in[55:48] <= wr_fifo[write_point_6[3:0]];
				enc_blk_data_in[63:56] <= wr_fifo[write_point_7[3:0]];
				enc_blk_data_in[71:64] <= wr_fifo[write_point_8[3:0]];
				enc_blk_data_in[79:72] <= wr_fifo[write_point_9[3:0]];
				enc_blk_data_in[87:80] <= wr_fifo[write_point_10[3:0]];
				enc_blk_data_in[95:88] <= wr_fifo[write_point_11[3:0]];
				enc_blk_data_in[103:96] <= wr_fifo[write_point_12[3:0]];
				enc_blk_data_in[111:104] <= wr_fifo[write_point_13[3:0]];
				enc_blk_data_in[119:112] <= wr_fifo[write_point_14[3:0]];
				enc_blk_data_in[127:120] <= wr_fifo[write_point_15[3:0]];
			end
			else 
				enc_blk_data_in <= enc_blk_data_in;
		else
			enc_blk_data_in <= enc_blk_data_in;
	else
		enc_blk_data_in <= 128'b0;

// auth_blk_data_in
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		auth_blk_data_in <= 128'h0;
	else if (ccm_sts == `CCM_AUTH_ONLY)
		if (auth_blk_cnt == 16'd0)
			auth_blk_data_in <= auth_blk_0;
		else if (auth_blk_cnt == 16'd1)
			auth_blk_data_in <= auth_blk_1;
		else if (auth_blk_cnt < auth_blk_cnt_n - 1)
			if (wr_cnt - last_wr_blk_cnt == 16'd16) begin
				auth_blk_data_in[7:0] <= wr_fifo[last_wr_blk_cnt[3:0]];
				auth_blk_data_in[15:8] <= wr_fifo[write_point_1[3:0]];
				auth_blk_data_in[23:16] <= wr_fifo[write_point_2[3:0]];
				auth_blk_data_in[31:24] <= wr_fifo[write_point_3[3:0]];
				auth_blk_data_in[39:32] <= wr_fifo[write_point_4[3:0]];
				auth_blk_data_in[47:40] <= wr_fifo[write_point_5[3:0]];
				auth_blk_data_in[55:48] <= wr_fifo[write_point_6[3:0]];
				auth_blk_data_in[63:56] <= wr_fifo[write_point_7[3:0]];
				auth_blk_data_in[71:64] <= wr_fifo[write_point_8[3:0]];
				auth_blk_data_in[79:72] <= wr_fifo[write_point_9[3:0]];
				auth_blk_data_in[87:80] <= wr_fifo[write_point_10[3:0]];
				auth_blk_data_in[95:88] <= wr_fifo[write_point_11[3:0]];
				auth_blk_data_in[103:96] <= wr_fifo[write_point_12[3:0]];
				auth_blk_data_in[111:104] <= wr_fifo[write_point_13[3:0]];
				auth_blk_data_in[119:112] <= wr_fifo[write_point_14[3:0]];
				auth_blk_data_in[127:120] <= wr_fifo[write_point_15[3:0]];
			end
			else
				auth_blk_data_in <= auth_blk_data_in;
		else if (auth_blk_cnt == auth_blk_cnt_n - 1)
			if (wr_cnt >= auth_data_length) begin
				auth_blk_data_in[7:0] <= wr_fifo[last_wr_blk_cnt[3:0]];
				auth_blk_data_in[15:8] <= (auth_length_1 <= 4'd1) ? 8'b0 : wr_fifo[write_point_1[3:0]];
				auth_blk_data_in[23:16] <= (auth_length_1 <= 4'd2) ? 8'b0 : wr_fifo[write_point_2[3:0]];
				auth_blk_data_in[31:24] <= (auth_length_1 <= 4'd3) ? 8'b0 : wr_fifo[write_point_3[3:0]];
				auth_blk_data_in[39:32] <= (auth_length_1 <= 4'd4) ? 8'b0 : wr_fifo[write_point_4[3:0]];
				auth_blk_data_in[47:40] <= (auth_length_1 <= 4'd5) ? 8'b0 : wr_fifo[write_point_5[3:0]];
				auth_blk_data_in[55:48] <= (auth_length_1 <= 4'd6) ? 8'b0 : wr_fifo[write_point_6[3:0]];
				auth_blk_data_in[63:56] <= (auth_length_1 <= 4'd7) ? 8'b0 : wr_fifo[write_point_7[3:0]];
				auth_blk_data_in[71:64] <= (auth_length_1 <= 4'd8) ? 8'b0 : wr_fifo[write_point_8[3:0]];
				auth_blk_data_in[79:72] <= (auth_length_1 <= 4'd9) ? 8'b0 : wr_fifo[write_point_9[3:0]];
				auth_blk_data_in[87:80] <= (auth_length_1 <= 4'd10) ? 8'b0 : wr_fifo[write_point_10[3:0]];
				auth_blk_data_in[95:88] <= (auth_length_1 <= 4'd11) ? 8'b0 : wr_fifo[write_point_11[3:0]];
				auth_blk_data_in[103:96] <= (auth_length_1 <= 4'd12) ? 8'b0 : wr_fifo[write_point_12[3:0]];
				auth_blk_data_in[111:104] <= (auth_length_1 <= 4'd13) ? 8'b0 : wr_fifo[write_point_13[3:0]];
				auth_blk_data_in[119:112] <= (auth_length_1 <= 4'd14) ? 8'b0 : wr_fifo[write_point_14[3:0]];
				auth_blk_data_in[127:120] <= (auth_length_1 <= 4'd15) ? 8'b0 : wr_fifo[write_point_15[3:0]];
			end
			else
				auth_blk_data_in <= auth_blk_data_in;
		else
			auth_blk_data_in <= auth_blk_data_in;
	else if (ccm_sts == `CCM_ENC_AUTH)
		if (i_dpc_tx_en == 1'b1)
			if (auth_blk_cnt < auth_blk_cnt_n + enc_blk_cnt_n - 1)
				auth_blk_data_in <= enc_blk_data_in;
			else if (auth_blk_cnt == auth_blk_cnt_n + enc_blk_cnt_n - 1) begin
				auth_blk_data_in[7:0] <= enc_blk_data_in[7:0];
				auth_blk_data_in[15:8] <= (auth_length_2 <= 4'd1) ? 8'b0 : enc_blk_data_in[15:8];
				auth_blk_data_in[23:16] <= (auth_length_2 <= 4'd2) ? 8'b0 : enc_blk_data_in[23:16];
				auth_blk_data_in[31:24] <= (auth_length_2 <= 4'd3) ? 8'b0 : enc_blk_data_in[31:24];
				auth_blk_data_in[39:32] <= (auth_length_2 <= 4'd4) ? 8'b0 : enc_blk_data_in[39:32];
				auth_blk_data_in[47:40] <= (auth_length_2 <= 4'd5) ? 8'b0 : enc_blk_data_in[47:40];
				auth_blk_data_in[55:48] <= (auth_length_2 <= 4'd6) ? 8'b0 : enc_blk_data_in[55:48];
				auth_blk_data_in[63:56] <= (auth_length_2 <= 4'd7) ? 8'b0 : enc_blk_data_in[63:56];
				auth_blk_data_in[71:64] <= (auth_length_2 <= 4'd8) ? 8'b0 : enc_blk_data_in[71:64];
				auth_blk_data_in[79:72] <= (auth_length_2 <= 4'd9) ? 8'b0 : enc_blk_data_in[79:72];
				auth_blk_data_in[87:80] <= (auth_length_2 <= 4'd10) ? 8'b0 : enc_blk_data_in[87:80];
				auth_blk_data_in[95:88] <= (auth_length_2 <= 4'd11) ? 8'b0 : enc_blk_data_in[95:88];
				auth_blk_data_in[103:96] <= (auth_length_2 <= 4'd12) ? 8'b0 : enc_blk_data_in[103:96];
				auth_blk_data_in[111:104] <= (auth_length_2 <= 4'd13) ? 8'b0 : enc_blk_data_in[111:104];
				auth_blk_data_in[119:112] <= (auth_length_2 <= 4'd14) ? 8'b0 : enc_blk_data_in[119:112];
				auth_blk_data_in[127:120] <= (auth_length_2 <= 4'd15) ? 8'b0 : enc_blk_data_in[127:120];
			end
			else
				auth_blk_data_in <= auth_blk_data_in;
		else if (i_dpc_rx_en == 1'b1)
			if (auth_blk_cnt < auth_blk_cnt_n + enc_blk_cnt_n - 1)
				auth_blk_data_in <= temp_data_out;
			else if (auth_blk_cnt == auth_blk_cnt_n + enc_blk_cnt_n - 1) begin
				auth_blk_data_in[7:0] <= temp_data_out[7:0];
				auth_blk_data_in[15:8] <= (auth_length_2 <= 4'd1) ? 8'b0 : temp_data_out[15:8];
				auth_blk_data_in[23:16] <= (auth_length_2 <= 4'd2) ? 8'b0 : temp_data_out[23:16];
				auth_blk_data_in[31:24] <= (auth_length_2 <= 4'd3) ? 8'b0 : temp_data_out[31:24];
				auth_blk_data_in[39:32] <= (auth_length_2 <= 4'd4) ? 8'b0 : temp_data_out[39:32];
				auth_blk_data_in[47:40] <= (auth_length_2 <= 4'd5) ? 8'b0 : temp_data_out[47:40];
				auth_blk_data_in[55:48] <= (auth_length_2 <= 4'd6) ? 8'b0 : temp_data_out[55:48];
				auth_blk_data_in[63:56] <= (auth_length_2 <= 4'd7) ? 8'b0 : temp_data_out[63:56];
				auth_blk_data_in[71:64] <= (auth_length_2 <= 4'd8) ? 8'b0 : temp_data_out[71:64];
				auth_blk_data_in[79:72] <= (auth_length_2 <= 4'd9) ? 8'b0 : temp_data_out[79:72];
				auth_blk_data_in[87:80] <= (auth_length_2 <= 4'd10) ? 8'b0 : temp_data_out[87:80];
				auth_blk_data_in[95:88] <= (auth_length_2 <= 4'd11) ? 8'b0 : temp_data_out[95:88];
				auth_blk_data_in[103:96] <= (auth_length_2 <= 4'd12) ? 8'b0 : temp_data_out[103:96];
				auth_blk_data_in[111:104] <= (auth_length_2 <= 4'd13) ? 8'b0 : temp_data_out[111:104];
				auth_blk_data_in[119:112] <= (auth_length_2 <= 4'd14) ? 8'b0 : temp_data_out[119:112];
				auth_blk_data_in[127:120] <= (auth_length_2 <= 4'd15) ? 8'b0 : temp_data_out[127:120];
			end
			else
				auth_blk_data_in <= auth_blk_data_in;
		else
			auth_blk_data_in <= auth_blk_data_in;
	else if (ccm_sts == `CCM_IDLE)
		auth_blk_data_in <= 128'h0;
	else
		auth_blk_data_in <= auth_blk_data_in;

		
// temp_data_out
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		temp_data_out <= 128'b0;
	else if (ccm_en)
		if (ccm_sts == `CCM_ENC)
			if (i_sec_data_out_vld == 1'b1)
				temp_data_out <= enc_blk_data_in ^ i_sec_data;
			else
				temp_data_out <= temp_data_out;
		else
			temp_data_out <= temp_data_out;
	else
		temp_data_out <= 128'b0;

// o_dpc_data
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_dpc_data <= 8'h0;
	else if (ccm_en)
		if (ccm_sts == `CCM_START
			|| ccm_sts == `CCM_KEY_FIND_START
			|| ccm_sts == `CCM_KEY_FOUND
			|| ccm_sts == `CCM_ENC_S_0
			|| ccm_sts == `CCM_AUTH_ONLY)
			if (temp_data_en == 1'b1)
				o_dpc_data <= wr_fifo[rd_cnt[3:0]];
			else
				o_dpc_data <= o_dpc_data;
		else if (ccm_sts == `CCM_NO_SEC || ccm_sts == `CCM_KEY_NOT_FOUND)
			if (temp_data_en == 1'b1)
				o_dpc_data <= wr_fifo[rd_cnt[3:0]];
			else
				o_dpc_data <= o_dpc_data;
		else if (ccm_sts == `CCM_ENC || ccm_sts == `CCM_ENC_AUTH)
			if (temp_data_en == 1'b1)
				case (enc_data_rd_cnt[3:0])
					4'd0 : o_dpc_data <= temp_data_out[7:0];
					4'd1 : o_dpc_data <= temp_data_out[15:8];
					4'd2 : o_dpc_data <= temp_data_out[23:16];
					4'd3 : o_dpc_data <= temp_data_out[31:24];
					4'd4 : o_dpc_data <= temp_data_out[39:32];
					4'd5 : o_dpc_data <= temp_data_out[47:40];
					4'd6 : o_dpc_data <= temp_data_out[55:48];
					4'd7 : o_dpc_data <= temp_data_out[63:56];
					4'd8 : o_dpc_data <= temp_data_out[71:64];
					4'd9 : o_dpc_data <= temp_data_out[79:72];
					4'd10 : o_dpc_data <= temp_data_out[87:80];
					4'd11 : o_dpc_data <= temp_data_out[95:88];
					4'd12 : o_dpc_data <= temp_data_out[103:96];
					4'd13 : o_dpc_data <= temp_data_out[111:104];
					4'd14 : o_dpc_data <= temp_data_out[119:112];
					4'd15 : o_dpc_data <= temp_data_out[127:120];
					default : o_dpc_data <= 8'h0;
				endcase					
			else
				o_dpc_data <= o_dpc_data;
		else if (ccm_sts == `CCM_MIC)
			if (temp_data_en == 1'b1)
				if (rd_cnt < i_dpc_length - `MIC_LENGTH)
					case (enc_data_rd_cnt[3:0])
						4'd0 : o_dpc_data <= temp_data_out[7:0];
						4'd1 : o_dpc_data <= temp_data_out[15:8];
						4'd2 : o_dpc_data <= temp_data_out[23:16];
						4'd3 : o_dpc_data <= temp_data_out[31:24];
						4'd4 : o_dpc_data <= temp_data_out[39:32];
						4'd5 : o_dpc_data <= temp_data_out[47:40];
						4'd6 : o_dpc_data <= temp_data_out[55:48];
						4'd7 : o_dpc_data <= temp_data_out[63:56];
						4'd8 : o_dpc_data <= temp_data_out[71:64];
						4'd9 : o_dpc_data <= temp_data_out[79:72];
						4'd10 : o_dpc_data <= temp_data_out[87:80];
						4'd11 : o_dpc_data <= temp_data_out[95:88];
						4'd12 : o_dpc_data <= temp_data_out[103:96];
						4'd13 : o_dpc_data <= temp_data_out[111:104];
						4'd14 : o_dpc_data <= temp_data_out[119:112];
						4'd15 : o_dpc_data <= temp_data_out[127:120];
						default : o_dpc_data <= 8'h0;
					endcase
				else
					case (rd_cnt - auth_data_length - enc_data_length)
						11'd0 : o_dpc_data <= mic[7:0];
						11'd1 : o_dpc_data <= mic[15:8];
						11'd2 : o_dpc_data <= mic[23:16];
						11'd3 : o_dpc_data <= mic[31:24];
						11'd4 : o_dpc_data <= mic[39:32];
						11'd5 : o_dpc_data <= mic[47:40];
						11'd6 : o_dpc_data <= mic[55:48];
						11'd7 : o_dpc_data <= mic[63:56];
						default : o_dpc_data <= 8'h0;
					endcase
			else
				o_dpc_data <= o_dpc_data;
		else if (ccm_sts == `CCM_FINISH)
			o_dpc_data <= wr_fifo[rd_cnt[3:0]];
//			o_dpc_data <= 8'h0;
		else
			o_dpc_data <= o_dpc_data;
	else
		o_dpc_data <= 8'h0;

// o_sec_en
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_sec_en <= 1'b0;
	else if (ccm_en)
		if (ccm_sts == `CCM_KEY_FOUND)
			o_sec_en <= 1'b1;
		else if (ccm_sts == `CCM_FINISH)
			o_sec_en <= 1'b0;
		else
			o_sec_en <= o_sec_en;
	else
		o_sec_en <= 1'b0;

// o_sec_ed
assign	o_sec_ed = 1'b0;


// o_sec_go
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_sec_go <= 1'b0;
	else if (ccm_en)
		if (ccm_sts == `CCM_ENC_S_0)		
			if (auth_blk_0_n_1_ready == 1'b1 && o_sec_go == 1'b0)
				o_sec_go <= 1'b1;
			else if (i_sec_data_out_vld == 1'b1)
				o_sec_go <= 1'b0;
			else
				o_sec_go <= o_sec_go;
		else if (ccm_sts == `CCM_ENC)
			if (i_sec_data_out_vld == 1'b1)
				o_sec_go <= 1'b0;
			else if (wr_cnt == last_wr_blk_cnt + 16 || last_blk_ready == 1'b1)
				o_sec_go <= 1'b1;
			else if (i_sec_data_out_vld == 1'b1)
				o_sec_go <= 1'b0;
			else
				o_sec_go <= o_sec_go;
		else if (ccm_sts == `CCM_AUTH_ONLY)
			if (auth_blk_cnt == 16'd0 || auth_blk_cnt == 16'd1)
				if (auth_blk_0_n_1_ready == 1'b1 && o_sec_go == 1'b0)
					o_sec_go <= 1'b1;
				else if (i_sec_data_out_vld == 1'b1)
					o_sec_go <= 1'b0;
				else
					o_sec_go <= o_sec_go;
			else if (auth_blk_cnt < auth_blk_cnt_n)
				if ((wr_cnt == last_wr_blk_cnt + 16 || wr_cnt == auth_data_length || last_blk_ready == 1'b1) && o_sec_go == 1'b0)
					o_sec_go <= 1'b1;
				else if (i_sec_data_out_vld == 1'b1)
					o_sec_go <= 1'b0;
				else
					o_sec_go <= o_sec_go;
			else
				o_sec_go <= 1'b0;
		else if (ccm_sts == `CCM_ENC_AUTH)
			if (i_sec_data_out_vld == 1'b1)
				o_sec_go <= 1'b0;
			else if (auth_blk_cnt < auth_blk_cnt_n + enc_blk_cnt)
				o_sec_go <= 1'b1;
			else
				o_sec_go <= o_sec_go;				
		else
			o_sec_go <= 1'b0;
	else
		o_sec_go <= 1'b0;

// o_sec_data
assign		o_sec_data = (ccm_sts == `CCM_ENC_S_0) ? enc_blk_0 :
				(ccm_sts == `CCM_ENC) ? enc_blk_a :
				(ccm_sts == `CCM_AUTH_ONLY || ccm_sts == `CCM_ENC_AUTH) ? auth_blk_data_in ^ auth_data_tmp : 128'h0;


// enc_flags, enc_blk_a
assign		enc_flags = 8'b0000_0001;	// 8'h01
assign		enc_blk_a = {enc_flags[7:0],		// 1 bytes
				ccm_nonce[103:0],	// 13 bytes
				enc_blk_cnt[15:0] };	// 2 byte

assign		enc_blk_0 = { enc_blk_a[127:8], 8'h0 };

assign		auth_flags = 8'b0101_1001;	//0_1_(t-2)/2_(15-n-1), 0_1_011_001 = 8'h59,  a >0, t = 8, n = 13
				
// auth_blk_0, auth_blk_1
assign		auth_blk_0 = { auth_flags[7:0], //a = 0, t =  FlagB = 00_
				ccm_nonce[103:0], //TK_id와 auth_data_length =  blk flagb=1 || n =13 || enc_offset  
				enc_data_length[15:0] }; //assign		enc_data_length = i_dpc_length - auth_data_length - `MIC_LENGTH 8 

assign		auth_blk_1 = { 	enc_offset, //0_1_(t-2)/2_(15-n-1),
				sfn[15:0],
				o_kp_tkid[15:0],
				mac_hdr[63:0],
				auth_data_length[15:0] };

assign		auth_blk_0_n_1_ready = (frame_type == `PT_BEACON) ? (wr_cnt >= `BEACON_TOKEN_OFFSET + 2) :
					(wr_cnt >= `MAC_HDR_LENGTH + `SEC_HDR_LENGTH);

//assign		mic_tmp = auth_data_tmp ^ enc_blk_0;
assign		mic_tmp = auth_data_tmp ^ enc_s_0;

// mic
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		mic <= 64'h0;
	else if (i_dpc_rx_en)
		if (i_dpc_data_en)
			if (wr_cnt == auth_data_length + enc_data_length)
				mic[7:0] <= i_dpc_data;
			else if (wr_cnt == auth_data_length + enc_data_length + 1)
				mic[15:8] <= i_dpc_data;
			else if (wr_cnt == auth_data_length + enc_data_length + 2)
				mic[23:16] <= i_dpc_data;
			else if (wr_cnt == auth_data_length + enc_data_length + 3)
				mic[31:24] <= i_dpc_data;
			else if (wr_cnt == auth_data_length + enc_data_length + 4)
				mic[39:32] <= i_dpc_data;
			else if (wr_cnt == auth_data_length + enc_data_length + 5)
				mic[47:40] <= i_dpc_data;
			else if (wr_cnt == auth_data_length + enc_data_length + 6)
				mic[55:48] <= i_dpc_data;
			else if (wr_cnt == auth_data_length + enc_data_length + 7)
				mic[63:56] <= i_dpc_data;
			else
				mic <= mic;
		else
			mic <= mic;
	else if (i_dpc_tx_en)
		mic <= mic_tmp[63:0];
	else
		mic <= 64'h0;

// enc_s_0
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		enc_s_0 <= 128'h0;
	else if (ccm_en)
		if (ccm_sts == `CCM_ENC_S_0)
			if (i_sec_data_out_vld == 1'b1)
				enc_s_0 <= i_sec_data;
			else
				enc_s_0 <= enc_s_0;
		else
			enc_s_0 <= enc_s_0;
	else
		enc_s_0 <= 128'h0;

// auth_data_tmp				
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		auth_data_tmp <= 128'h0;
	else if (ccm_en)
		if (ccm_sts == `CCM_AUTH_ONLY)
			if (i_sec_data_out_vld == 1'b1)
				auth_data_tmp <= i_sec_data;
			else
				auth_data_tmp <= auth_data_tmp;
		else if (ccm_sts == `CCM_ENC_AUTH)
			if (i_sec_data_out_vld == 1'b1)
				auth_data_tmp <= i_sec_data;
			else
				auth_data_tmp <= auth_data_tmp;
		else
			auth_data_tmp <= auth_data_tmp;
	else
		auth_data_tmp <= 128'h0;
		
// enc_blk_cnt
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		enc_blk_cnt <= 16'd0;
	else if (ccm_en)
		if (ccm_sts == `CCM_ENC)
			if (i_sec_data_out_vld == 1'b1)
				enc_blk_cnt <= enc_blk_cnt + 1;
			else
				enc_blk_cnt <= enc_blk_cnt;
		else
			enc_blk_cnt <= enc_blk_cnt;
	else
		enc_blk_cnt <= 16'd0;

// auth_blk_cnt
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		auth_blk_cnt <= 16'd0;
	else if (ccm_en)
		if ((ccm_sts == `CCM_AUTH_ONLY || ccm_sts == `CCM_ENC_AUTH)
			&& i_sec_data_out_vld == 1'b1)
			auth_blk_cnt <= auth_blk_cnt + 1;
		else
			auth_blk_cnt <= auth_blk_cnt;
	else
		auth_blk_cnt <= 16'd0;
					
// o_kp_tkid
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_kp_tkid <= 16'h0;
	else if (ccm_en)
		if (wr_cnt == `TKID_0_OFFSET && i_dpc_data_en == 1'b1)
			o_kp_tkid[7:0] <= i_dpc_data;
		else if (wr_cnt == `TKID_1_OFFSET && i_dpc_data_en == 1'b1)
			o_kp_tkid[15:8] <= i_dpc_data;
		else
			o_kp_tkid <= o_kp_tkid;
	else
		o_kp_tkid <= 16'h0;


// o_kp_key_find
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_kp_key_find <= 1'b0;
	else if (ccm_en)
		if (wr_cnt == `TKID_1_OFFSET && i_dpc_data_en == 1'b1)
			o_kp_key_find <= 1'b1;
		else
			o_kp_key_find <= 1'b0;
	else
		o_kp_key_find <= 1'b0;


// o_ks_key
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_ks_key <= 128'b0;
	else if (ccm_en)
		if (ccm_sts == `CCM_KEY_FIND_START)
			if (i_kp_key_sts == 2'b10)
				o_ks_key <= i_kp_key;
			else if (i_kp_key_sts == 2'b11)
				o_ks_key <= o_ks_key;
			else
				o_ks_key <= o_ks_key;
		else
			o_ks_key <= o_ks_key;
	else
		o_ks_key <= 128'b0;

// o_ks_en
assign	o_ks_en = o_sec_en;

// o_mac_encrypt_sts
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_mac_encrypt_sts <= `CCM_TX_STS_IDLE;
	else if (i_dpc_tx_en == 1'b1)
		if (ccm_sts == `CCM_KEY_FIND_START)
			if (i_kp_key_sts == 2'b10)
				o_mac_encrypt_sts <= `CCM_TX_STS_KEY_FOUND;
			else if (i_kp_key_sts == 2'b11)
				o_mac_encrypt_sts <= `CCM_TX_STS_KEY_NOT_FOUND;
			else
				o_mac_encrypt_sts <= o_mac_encrypt_sts;
		else if (ccm_sts == `CCM_FINISH)
			if (rd_cnt == enc_data_length + auth_data_length + `MIC_LENGTH)
				o_mac_encrypt_sts <= `CCM_TX_STS_ENC_OK;
			else
				o_mac_encrypt_sts <= o_mac_encrypt_sts;
		else
			o_mac_encrypt_sts <= o_mac_encrypt_sts;
	else
		o_mac_encrypt_sts <= `CCM_TX_STS_IDLE;

// o_mac_decrypt_sts
always @(negedge rst_n or posedge clk)
	if (rst_n == 1'b0)
		o_mac_decrypt_sts <= `CCM_RX_STS_IDLE;
	else if (i_dpc_rx_en == 1'b1)
		if (ccm_sts == `CCM_KEY_FIND_START)
			if (i_kp_key_sts == 2'b10)
				o_mac_decrypt_sts <= `CCM_RX_STS_KEY_FOUND;
			else if (i_kp_key_sts == 2'b11)
				o_mac_decrypt_sts <= `CCM_RX_STS_KEY_NOT_FOUND;
			else
				o_mac_decrypt_sts <= o_mac_decrypt_sts;
		else if (ccm_sts == `CCM_FINISH)
			if (mic == mic_tmp[63:0])
				o_mac_decrypt_sts <= `CCM_RX_STS_DEC_OK;
			else
				o_mac_decrypt_sts <= `CCM_RX_STS_MIC_ERR;
		else
			o_mac_decrypt_sts <= o_mac_decrypt_sts;
	else
		o_mac_decrypt_sts <= `CCM_RX_STS_IDLE;

// o_dpc_wait
//assign		o_dpc_wait = (ccm_sts == `CCM_KEY_FOUND);
assign		o_dpc_wait = (ccm_sts == `CCM_KEY_NOT_FOUND || ccm_sts == `CCM_NO_SEC) ? 1'b0 :
				(wr_cnt >= last_wr_blk_cnt + 15 | ccm_sts == `CCM_KEY_FOUND);

endmodule
