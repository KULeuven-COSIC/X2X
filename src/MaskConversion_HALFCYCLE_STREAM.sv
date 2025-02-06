
module MaskConversion_HALFCYCLE_STREAM
#(
    parameter HALFCYCLE = 1,
    parameter LOG2_OF_q = 12,               // ceil(LOG2(3329))
    parameter q = 3329,                     // KYBER PRIME
    parameter PARAM_WIDTH = LOG2_OF_q + 1,  // # bits / data word
    parameter N_SHARES = 2, // protection order + 1 (# primary arithmetic shares)
    parameter N_STAGES = 4,
    
   parameter RND_SHARES = 2 * (N_SHARES - 1) + 2 * N_SHARES + 4 * (N_SHARES * (N_SHARES - 1) / 2),
   parameter RND_SHARES_8bit = 2 * N_STAGES * 3 *(N_SHARES * (N_SHARES - 1) / 2)
    // parameter N_SHARES_L0 = 2,
    // parameter RND_SHARES = 2 * (N_SHARES - 1) + N_SHARES_L0 + 3 * N_SHARES + 4 * (N_SHARES_L0 * (N_SHARES_L0 - 1) / 2) + 4 * (N_SHARES * (N_SHARES - 1) / 2),
    // parameter RND_SHARES_8bit = 2 * N_STAGES * 3 *(N_SHARES_L0 * (N_SHARES_L0 - 1) / 2) + 2 * N_STAGES * 3 *(N_SHARES * (N_SHARES - 1) / 2)
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // CONTROL
    input logic valid_data,     // valid A/B shares ready for input
    output logic ready_data,    // ready to accept new A/B shares and start A2B/B2A
    
    input logic ready_result,   // ready to accept new B/A shares and transfer
    output logic valid_result,  // valid B/A shares ready for output
    
    input logic conversion_mode,    // 0 -> A2B, 1 -> B2A
    input logic data_type_mode,     // 0 -> power-of-two, 1 -> prime
    input logic dual_mode,          // 0 -> single input, 2 -> dual input
    //output logic dual_mode_out,     // 0 -> single output, 1 -> dual output
    
    // RND 1 + 2
    input logic [PARAM_WIDTH - 1 : 0]   fresh_rnd_shares        [RND_SHARES - 1 : 0],
    input logic [8 - 1 : 0]             fresh_rnd_shares_8bit   [RND_SHARES_8bit - 1 : 0],
    
    // DATA 1 + 2
    input logic  [PARAM_WIDTH - 1 : 0] original_data    [2 - 1 : 0][N_SHARES - 1:0],
    output logic [PARAM_WIDTH - 1 : 0] converted_data   [2 - 1 : 0][N_SHARES - 1:0]
);
    
    ///////////
	// LOGIC //
	///////////
	
	generate
	if (N_SHARES == 2)
	begin
	   (* keep_hierarchy = "TRUE" *) MaskConversion_2SHARE_HALFCYCLE_STREAM
        #(
            .HALFCYCLE(HALFCYCLE),
            .PARAM_WIDTH(PARAM_WIDTH),
            .N_SHARES(N_SHARES),
            .RND_SHARES(RND_SHARES), 
            .RND_SHARES_8bit(RND_SHARES_8bit)
        )
        MaskConv_2SHARE_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            
            .valid_data(valid_data), 
            .ready_data(ready_data),
            .ready_result(ready_result),
            .valid_result(valid_result),
            
            .data_type_mode(data_type_mode),
            .conversion_mode(conversion_mode),
            .dual_mode(dual_mode),
            //.dual_mode_out(dual_mode_out),
            
            .fresh_rnd_shares(fresh_rnd_shares),
            .fresh_rnd_shares_8bit(fresh_rnd_shares_8bit),
            
            .original_data(original_data),
            .converted_data(converted_data)
        );
	end
	else if (N_SHARES == 3) 
	begin
	   (* keep_hierarchy = "TRUE" *) MaskConversion_3SHARE_HALFCYCLE_STREAM
        #(
            .HALFCYCLE(HALFCYCLE),
            .PARAM_WIDTH(PARAM_WIDTH),
            .N_SHARES(N_SHARES),
            .RND_SHARES(RND_SHARES), 
            .RND_SHARES_8bit(RND_SHARES_8bit)
        )
        MaskConv_3SHARE_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            
            .valid_data(valid_data), 
            .ready_data(ready_data),
            .ready_result(ready_result),
            .valid_result(valid_result),
            
            .data_type_mode(data_type_mode),
            .conversion_mode(conversion_mode),
            .dual_mode(dual_mode),
            
            .fresh_rnd_shares(fresh_rnd_shares),
            .fresh_rnd_shares_8bit(fresh_rnd_shares_8bit),
            
            .original_data(original_data),
            .converted_data(converted_data)
        );
	end
	endgenerate
    
    
       
endmodule
