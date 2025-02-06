
// FRESH RND SHARES 
// L0
// - 2 * EXPAND SHARES: N_SHARES_L0
// - 2 * EXPAND SHARES L1: N_SHARES
// - 2 * B2A RND SHARES: (N_SHARES - 1) 
// - 2 * TRIANGLE: (N_SHARES_L0 * (N_SHARES_L0 - 1) / 2)
// L1 
// - 2 * EXPAND SHARES: N_SHARES
// - 2 * TRIANGLE: (N_SHARES * (N_SHARES - 1) / 2) 


module MaskConversion_3SHARE_HALFCYCLE_STREAM
#(
    parameter HALFCYCLE = 0,
    parameter LOG2_OF_q = 12,               // ceil(LOG2(3329))
    parameter N_STAGES = 4,
    parameter TWO_COMPLEMENT_MINUS_q = 4863, //62207, //(2^16 - q)
    parameter KYBER_q = 3329,
    
    parameter PARAM_WIDTH = LOG2_OF_q + 1,  // # bits / data word
    parameter N_SHARES = 3, // protection order + 1 (# primary arithmetic shares)
    parameter N_SHARES_L0 = 2,
    parameter RND_SHARES,
    parameter RND_SHARES_8bit
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
    input logic dual_mode,          // 0 -> single input, 1 -> dual input
//    output logic dual_mode_out,     // 0 -> single output, 1 -> dual output
    
    // RND 1 + 2
    input logic [PARAM_WIDTH - 1 : 0]   fresh_rnd_shares        [RND_SHARES - 1 : 0],
    input logic [8 - 1 : 0]             fresh_rnd_shares_8bit   [RND_SHARES_8bit - 1 : 0], // FOR 2 SECADD, either mod q or power-of-two in parallel
    
    // DATA 1 + 2
    input logic  [PARAM_WIDTH - 1 : 0] original_data    [2 - 1 : 0][N_SHARES - 1 : 0],
    output logic [PARAM_WIDTH - 1 : 0] converted_data   [2 - 1 : 0][N_SHARES - 1 : 0]
);
	
	
	/////////////////////////////////
	// INTERNAL SIGNAL DECLARATION //
	/////////////////////////////////
	
	genvar idx, idy, idz;
	localparam N_CYCLES = (HALFCYCLE==1) ? (N_STAGES + 1) : ((N_STAGES + 1) * 2) - 1 + 1;
	localparam CYCLE_Q = (HALFCYCLE==1) ? N_CYCLES : N_CYCLES - 1;
	localparam N_CYCLES_SINGLE = (HALFCYCLE==1) ? N_CYCLES : N_CYCLES + 1;
	
	// LAYER 0
	localparam RND_TRIANGLE_SHARES_L0 = 2 * (N_SHARES_L0 * (N_SHARES_L0 - 1) / 2);
	localparam RND_BOX_SHARES_L0 = (N_STAGES - 1) * 3 *(N_SHARES_L0 * (N_SHARES_L0 - 1) / 2) + 2 *(N_SHARES_L0 * (N_SHARES_L0 - 1) / 2);
//	localparam RND_OTHER_SHARES_L0 = 2 * N_SHARES_L0 + 2 * (N_SHARES - 1);
    localparam RND_TRIANGLE_SHARES_L1 = 2 * (N_SHARES * (N_SHARES - 1) / 2);
	localparam RND_BOX_SHARES_L1 = (N_STAGES - 1) * 3 *(N_SHARES * (N_SHARES - 1) / 2) + 2 *(N_SHARES * (N_SHARES - 1) / 2);
	
	// EXPAND
	logic                       en_expand_L0       [2 - 1 : 0];
	logic                       en_expand_L0_reg   [2 - 1 : 0];
	logic [PARAM_WIDTH - 1 : 0] input_expand_L0    [2 - 1 : 0][N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] rnd_expand_L0      [2 - 1 : 0][N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] output_expand_L0   [2 - 1 : 0][N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] input_expand_single [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] rnd_expand_single   [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] output_expand_single[2 - 1 : 0][N_SHARES - 1 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] input_expand_INV    [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] output_expand_INV    [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] single_reg          [2 - 1 : 0][N_CYCLES : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] B2A_orig_L0         [2 - 1 : 0][N_CYCLES : 0][N_SHARES - 2 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] expand_reg_in_L0                [4 - 1 : 0][N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] expand_reg_L0                   [4 - 1 : 0][N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_shares_reg_in_L0                 [RND_SHARES - 2 * N_SHARES_L0 - 2 * (N_SHARES - 1) + 1 - 2 * N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_shares_reg_L0                    [RND_SHARES - 2 * N_SHARES_L0 - 2 * (N_SHARES - 1) + 1 - 2 * N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq_reg_in_L0                   [RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq_reg_L0                      [RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1 - 1 : 0];
    
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_reg_in_L0            [RND_SHARES_8bit - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_reg_L0               [RND_SHARES_8bit - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_modq_reg_in_L0       [RND_SHARES_8bit - RND_BOX_SHARES_L0 - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_modq_reg_L0          [RND_SHARES_8bit - RND_BOX_SHARES_L0 - 1 : 0];
    
    
    // SECADD
    logic                       start_SecAdd_L0                    [2 - 1 : 0];
    logic                       done_SecAdd_L0                     [2 - 1 : 0];
    logic                       done_SecAdd_reg_L0                 [2 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_triangle_L0              [2 - 1 : 0][RND_TRIANGLE_SHARES_L0 - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_box_L0                   [2 - 1 : 0][RND_BOX_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] a_SecAdd_L0                        [2 - 1 : 0][N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] b_SecAdd_L0                        [2 - 1 : 0][N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] S_SecAdd_L0                        [2 - 1 : 0][N_SHARES_L0 - 1 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq_L0      [N_CYCLES : 0][RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1 - 1 : 0]; 
    logic [8 - 1 : 0]           fresh_rnd_8bit_modq_L0 [N_CYCLES : 0][RND_SHARES_8bit - RND_BOX_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_b2aq_L0      [N_CYCLES : 0][2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1 - 1 : 0]; 
    logic [8 - 1 : 0]           fresh_rnd_b2aq_8bit_L0 [N_CYCLES : 0][2 * RND_BOX_SHARES_L1 - 1 : 0];
    
    logic                       S_SecAdd_sel_L0        [N_SHARES_L0 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] S_SecAdd_out_reg_L0    [N_SHARES_L0 - 1 : 0];
    
    logic                       carry_in_L0            [N_SHARES_L0 - 1 : 0];
    logic                       carry_rnd_L0           [N_SHARES_L0 - 1 : 0];
    logic                       carry_ref_L0           [N_SHARES_L0 - 1 : 0];
    
    // LAYER 1
    
    
    // EXPAND 
    logic                       en_expand_L1       [2 - 1 : 0];
	logic                       en_expand_L1_reg   [2 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] input_expand_L1    [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] rnd_expand_L1      [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] output_expand_L1   [2 - 1 : 0][N_SHARES - 1 : 0];
   
    logic [PARAM_WIDTH - 1 : 0] B2A_orig_L1         [2 - 1 : 0][N_CYCLES : 0][N_SHARES - 2 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] expand_reg_in_L1                [4 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] expand_reg_L1                   [4 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_shares_reg_in_L1                 [1 + 2 * RND_TRIANGLE_SHARES_L1 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_shares_reg_L1                    [1 + 2 * RND_TRIANGLE_SHARES_L1 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq_reg_in_L1            [RND_TRIANGLE_SHARES_L1 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq_reg_L1               [RND_TRIANGLE_SHARES_L1 - 1 : 0];
    
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_reg_in_L1            [2 * RND_BOX_SHARES_L1 - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_reg_L1               [2 * RND_BOX_SHARES_L1 - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_modq_reg_in_L1       [RND_BOX_SHARES_L1 - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_modq_reg_L1          [RND_BOX_SHARES_L1 - 1 : 0];
    
    // SECADD 
    logic                       start_SecAdd_L1                    [2 - 1 : 0];
    logic                       done_SecAdd_L1                     [2 - 1 : 0];
    logic                       done_SecAdd_reg_L1                 [2 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_triangle_L1              [2 - 1 : 0][RND_TRIANGLE_SHARES_L1 - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_box_L1                   [2 - 1 : 0][RND_BOX_SHARES_L1 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] a_SecAdd_L1                        [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] b_SecAdd_L1                        [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] S_SecAdd_L1                        [2 - 1 : 0][N_SHARES - 1 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq_L1      [N_CYCLES : 0][1 + RND_TRIANGLE_SHARES_L1 - 1 : 0]; 
    logic [8 - 1 : 0]           fresh_rnd_8bit_modq_L1 [N_CYCLES : 0][RND_BOX_SHARES_L1 - 1 : 0];
    
    logic                       S_SecAdd_sel_L1        [N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] S_SecAdd_out_reg_L1    [N_SHARES - 1 : 0];
    
    logic                       carry_in_L1            [N_SHARES - 1 : 0];
    logic                       carry_rnd_L1           [N_SHARES - 1 : 0];
    logic                       carry_ref_L1           [N_SHARES - 1 : 0];
    
    // FullXOR
    logic [PARAM_WIDTH - 1 : 0] X2B_out             [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] X2B_out_reg         [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] xor_result          [2 - 1 : 0];
    
	
	//////////
	// I/0 //
	//////////
	
	logic  conversion_mode_reg;
	logic  data_type_reg;
	logic  dual_mode_reg;
	
	always_ff @(posedge clk, negedge rst_n) 
    begin
        if (rst_n == 1'b0) // reset control logic
        begin
            ready_data <= 1'b0;
        end 
        else 
        begin
            ready_data <= 1'b1;
        end
    end
    
    (* keep_hierarchy = "TRUE" *) D_reg 
    #(.PARAM_WIDTH(1)) 
    D_reg_conversion_mode
    (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(conversion_mode), .q(conversion_mode_reg));
    
    (* keep_hierarchy = "TRUE" *) D_reg 
    #(.PARAM_WIDTH(1)) 
    D_reg_data_type
    (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(data_type_mode), .q(data_type_reg));
    
    (* keep_hierarchy = "TRUE" *) D_reg 
    #(.PARAM_WIDTH(1)) 
    D_reg_dual_type
    (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(dual_mode), .q(dual_mode_reg));
	
	assign valid_result = conversion_mode_reg ? data_type_reg ? done_SecAdd_reg_L1[1] : done_SecAdd_reg_L1[0] : data_type_reg ? done_SecAdd_L1[1] : done_SecAdd_L1[0];
	
    assign converted_data[0] = conversion_mode_reg ? data_type_reg ? '{xor_result[1], B2A_orig_L1[1][N_CYCLES][0], B2A_orig_L1[1][N_CYCLES][1]} : '{xor_result[0], B2A_orig_L1[0][N_CYCLES][0], B2A_orig_L1[0][N_CYCLES][1]}: data_type_reg ? S_SecAdd_L1[1] : S_SecAdd_L1[0];
    assign converted_data[1] = conversion_mode_reg ? data_type_reg ? '{default: '0} : '{xor_result[1], B2A_orig_L1[1][N_CYCLES][0], B2A_orig_L1[1][N_CYCLES][1]} : data_type_reg ? '{default: '0} : S_SecAdd_L1[1];
    
    
    /////////////
	// CONTROL //
	/////////////
    
    always_comb
    begin
    
        ///////////////
        /// LAYER 0 ///
        ///////////////
        
        // EXPAND 
        en_expand_L0[0] = valid_data;
        en_expand_L0[1] = valid_data & dual_mode_reg;
        
        en_expand_L1[0] = data_type_reg ? done_SecAdd_L0[1] : done_SecAdd_L0[0];
        en_expand_L1[1] = data_type_reg ? '0 : done_SecAdd_L0[1];
        
        input_expand_L1[0][0] = en_expand_L1[0] ? data_type_reg ? '0 : '0 : '0;
        input_expand_L1[0][1] = en_expand_L1[0] ? data_type_reg ? S_SecAdd_L0[1][0] : S_SecAdd_L0[0][0] : '0;//'{'0, S_SecAdd_L0[1]} : '{'0, S_SecAdd_L0[0]} : '{default: '0};
        input_expand_L1[0][2] = en_expand_L1[0] ? data_type_reg ? S_SecAdd_L0[1][1] : S_SecAdd_L0[0][1] : '0;
        input_expand_L1[1][0] = en_expand_L1[1] ? data_type_reg ? '0 : '0 : '0; 
        input_expand_L1[1][1] = en_expand_L1[1] ? data_type_reg ? '0 : S_SecAdd_L0[1][0] : '0;
        input_expand_L1[1][2] = en_expand_L1[1] ? data_type_reg ? '0 : S_SecAdd_L0[1][1] : '0;//'{default: '0} : {'0, S_SecAdd_L0[1]} : '{default: '0};
        
        rnd_expand_L1[0] = en_expand_L1[0] ? data_type_reg ? fresh_rnd_b2aq_L0[N_CYCLES][1 +: N_SHARES] : fresh_rnd_modq_L0[N_CYCLES][1 + RND_TRIANGLE_SHARES_L0 +: N_SHARES] : '{default : '0};
        rnd_expand_L1[1] = en_expand_L1[1] ? data_type_reg ? '{default: '0} : fresh_rnd_modq_L0[N_CYCLES][1 + RND_TRIANGLE_SHARES_L0 + N_SHARES +: N_SHARES] : '{default: '0};
        
        for (int i = 0; i < 2; i=i+1)
        begin
            rnd_expand_L0[i] = en_expand_L0[i] ? fresh_rnd_shares[i * N_SHARES_L0 +: N_SHARES_L0] : '{default: '0};
            
            expand_reg_in_L0[i] = '{output_expand_L0[0][i], rnd_expand_L0[0][i]};
            expand_reg_in_L0[2 + i] = '{output_expand_L0[1][i], rnd_expand_L0[1][i]};
            expand_reg_in_L1[2*i] = output_expand_L1[i];
        end
        expand_reg_in_L1[1] = data_type_reg ? single_reg[1][N_CYCLES] : single_reg[0][N_CYCLES];
        expand_reg_in_L1[3] = data_type_reg ? '{default: '0} : single_reg[1][N_CYCLES];
        
        // SecADD 
        start_SecAdd_L0[0] = en_expand_L0_reg[0];
        start_SecAdd_L0[1] = data_type_reg ? done_SecAdd_reg_L0[0] : en_expand_L0_reg[1];
        
        start_SecAdd_L1[0] = en_expand_L1_reg[0];
        start_SecAdd_L1[1] = data_type_reg ? done_SecAdd_reg_L1[0] : en_expand_L1_reg[1];
        
        for (int i = 0; i < RND_TRIANGLE_SHARES_L0; i=i+1)
        begin
            fresh_rnd_triangle_L0[0][i] = fresh_rnd_shares_reg_L0[1 + i];
            fresh_rnd_triangle_L0[1][i] = data_type_reg ? fresh_rnd_modq_reg_L0[1 + i] : fresh_rnd_shares_reg_L0[1 + RND_TRIANGLE_SHARES_L0 + i];
        end
        
        
        fresh_rnd_triangle_L1[0] = fresh_rnd_shares_reg_L1[1 +: RND_TRIANGLE_SHARES_L1];
        fresh_rnd_triangle_L1[1] = data_type_reg ? fresh_rnd_modq_reg_L1 : fresh_rnd_shares_reg_L1[1 + RND_TRIANGLE_SHARES_L1 +: RND_TRIANGLE_SHARES_L1];
        
        fresh_rnd_box_L0[0] = fresh_rnd_shares_8bit_reg_L0[RND_BOX_SHARES_L0 - 1 : 0];
        for (int i = 0; i < RND_BOX_SHARES_L0; i=i+1)
        begin
            fresh_rnd_box_L0[1][i] = data_type_reg ? fresh_rnd_shares_8bit_modq_reg_L0[i] : fresh_rnd_shares_8bit_reg_L0[RND_BOX_SHARES_L0 + i]; 
        end
                
        fresh_rnd_box_L1[0] = fresh_rnd_shares_8bit_reg_L1[RND_BOX_SHARES_L1 - 1 : 0];
        for (int i = 0; i < RND_BOX_SHARES_L1; i=i+1)
        begin
            fresh_rnd_box_L1[1][i] = data_type_reg ? fresh_rnd_8bit_modq_L1[N_CYCLES][i] : fresh_rnd_shares_8bit_reg_L1[RND_BOX_SHARES_L1 + i];
        end         
        a_SecAdd_L0[0] = expand_reg_L0[0];
        b_SecAdd_L0[0] = expand_reg_L0[1];
        a_SecAdd_L0[1] = data_type_reg ? S_SecAdd_out_reg_L0 : expand_reg_L0[2];
        
        a_SecAdd_L1[0] = expand_reg_L1[0];
        b_SecAdd_L1[0] = expand_reg_L1[1];
        a_SecAdd_L1[1] = data_type_reg ? S_SecAdd_out_reg_L1 : expand_reg_L1[2];
     
        
        for (int i = 0; i < N_SHARES_L0; i=i+1)
        begin
            carry_in_L0[i] = data_type_reg ? S_SecAdd_L0[0][i][PARAM_WIDTH - 1] : 1'b0;
            carry_rnd_L0[i] = data_type_reg ? fresh_rnd_modq_L0[N_CYCLES][0][0] : 1'b0;
            
            B2A_orig_L1[0][0][i] = data_type_reg ? B2A_orig_L0[1][N_CYCLES][i] : B2A_orig_L0[0][N_CYCLES][i];
            B2A_orig_L1[1][0][i] = data_type_reg ? B2A_orig_L1[0][N_CYCLES][i] : B2A_orig_L0[1][N_CYCLES][i];
        end
        
        for (int i = 0; i < N_SHARES; i=i+1)
        begin
            carry_in_L1[i] = data_type_reg ? S_SecAdd_L1[0][i][PARAM_WIDTH - 1] : '0;
            carry_rnd_L1[i] = data_type_reg ? fresh_rnd_modq_L1[N_CYCLES][0][i+1] : '0;
        end
        
        
        
        // B2A
        if (conversion_mode_reg)
        begin
            for (int i = 0; i < 2; i=i+1)
            begin
                input_expand_L0[i][0] = en_expand_L0[i] ? fresh_rnd_shares[2 * N_SHARES_L0 + 2 * N_SHARES + i * N_SHARES_L0] : '0;
                input_expand_L0[i][1] = en_expand_L0[i] ? data_type_reg ? fresh_rnd_shares[2 * N_SHARES_L0 + 2 * N_SHARES + i * N_SHARES_L0 + 2] : fresh_rnd_shares[2 * N_SHARES_L0 + 2 * N_SHARES + i * N_SHARES_L0 + 1] : '0;   
                
                input_expand_single[i] = '{default: '0};
                rnd_expand_single[i] = '{default: '0};
                input_expand_INV[i] = en_expand_L0[i] ? original_data[i] : '{default: '0};
                
                b_SecAdd_L0[1][i] = data_type_reg ? S_SecAdd_sel_L0[i] ? KYBER_q : '0 : expand_reg_L0[3][i];   
            end
            
            b_SecAdd_L1[1][0] = data_type_reg ? S_SecAdd_sel_L1[0] ? TWO_COMPLEMENT_MINUS_q : '0 : expand_reg_L1[3][0];
            b_SecAdd_L1[1][1] = data_type_reg ? S_SecAdd_sel_L1[1] ? TWO_COMPLEMENT_MINUS_q : '0 : expand_reg_L1[3][1];
            b_SecAdd_L1[1][2] = data_type_reg ? S_SecAdd_sel_L1[2] ? '0 : TWO_COMPLEMENT_MINUS_q : expand_reg_L1[3][2]; 
            
            single_reg[0][0] = output_expand_INV[0];
            single_reg[1][0] = data_type_reg ? single_reg[0][N_CYCLES] : output_expand_INV[1];
            for (int i = 0; i < N_SHARES - 1; i=i+1)
            begin
                B2A_orig_L0[0][0][i] = en_expand_L0[0] ? fresh_rnd_shares[2 * N_SHARES_L0 + 2 * N_SHARES + i] : '0;
                B2A_orig_L0[1][0][i] = data_type_reg ? B2A_orig_L0[0][N_CYCLES][i] : en_expand_L0[1] ? fresh_rnd_shares[2 * N_SHARES_L0 + 2 * N_SHARES + N_SHARES - 1 + i] : '0;
            end
        end
        
        // A2B
        else
        begin
            for (int i = 0; i < 2; i=i+1)
            begin
                input_expand_L0[i][0] = en_expand_L0[i] ? original_data[i][0] : '0;
                input_expand_L0[i][1] = en_expand_L0[i] ? original_data[i][1] : '0;
                input_expand_single[i] = en_expand_L0[i] ? '{original_data[i][2], '0, '0} : '{default: '0};
                rnd_expand_single[i] = en_expand_L0[i] ? fresh_rnd_shares[2 * N_SHARES_L0 + i * N_SHARES +: N_SHARES] : '{default: '0};
                B2A_orig_L0[i][0] = '{default: '0};
                input_expand_INV[i] = '{default : '0};
            end
            
            for (int i = 0; i < N_SHARES; i=i+1)
            begin
                b_SecAdd_L1[1][i] = data_type_reg ? S_SecAdd_sel_L1[i] ? KYBER_q : '0 : expand_reg_L1[3][i];
            end
            
            single_reg[0][0] = output_expand_single[0];
            single_reg[1][0] = data_type_reg ? single_reg[0][N_CYCLES] : output_expand_single[1];
            
            
            b_SecAdd_L0[1][0] = data_type_reg ? S_SecAdd_sel_L0[0] ? TWO_COMPLEMENT_MINUS_q : '0 : expand_reg_L0[3][0];
            b_SecAdd_L0[1][1] = data_type_reg ? S_SecAdd_sel_L0[1] ? '0 : TWO_COMPLEMENT_MINUS_q : expand_reg_L0[3][1];
        end
        
        for (int i = 0; i < RND_SHARES - 2 * N_SHARES_L0 - 2 * (N_SHARES - 1) + 1 - 2 * N_SHARES; i=i+1)
        begin
            fresh_rnd_shares_reg_in_L0[i] = en_expand_L0[0] ? fresh_rnd_shares[2 * N_SHARES_L0 + 2 * (N_SHARES - 1) + 2 * N_SHARES - 1 + i] : '0;
        end
        fresh_rnd_shares_8bit_reg_in_L0 = en_expand_L0[0] ? fresh_rnd_shares_8bit : '{default: '0};
        
        fresh_rnd_shares_8bit_reg_in_L1 = data_type_reg ? fresh_rnd_b2aq_8bit_L0[N_CYCLES] : fresh_rnd_8bit_modq_L0[N_CYCLES][RND_BOX_SHARES_L0 +: 2 * RND_BOX_SHARES_L1];
        
        fresh_rnd_shares_reg_in_L1[0] = data_type_reg ? fresh_rnd_b2aq_L0[N_CYCLES][0] : fresh_rnd_modq_L0[N_CYCLES][0];
        fresh_rnd_shares_reg_in_L1[2 * RND_TRIANGLE_SHARES_L1 + 1 - 1 : 1] = data_type_reg ? fresh_rnd_b2aq_L0[N_CYCLES][1 + 2 * N_SHARES +: 2 * RND_TRIANGLE_SHARES_L1] : fresh_rnd_modq_L0[N_CYCLES][1 + 2 * N_SHARES + RND_TRIANGLE_SHARES_L0 +: 2 * RND_TRIANGLE_SHARES_L1];
        
        fresh_rnd_modq_L0[0][0] = fresh_rnd_shares_reg_L0[0];
        fresh_rnd_modq_L0[0][RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1 - 1 : 1] = fresh_rnd_shares_reg_L0[1 + RND_TRIANGLE_SHARES_L0 +: RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES];
        
        fresh_rnd_modq_L1[0][0] = fresh_rnd_shares_reg_L1[0];
        fresh_rnd_modq_L1[0][RND_TRIANGLE_SHARES_L1 + 1 - 1 : 1] = fresh_rnd_shares_reg_L1[1 + RND_TRIANGLE_SHARES_L1 +: RND_TRIANGLE_SHARES_L1];
        
        
        fresh_rnd_8bit_modq_L0[0] = fresh_rnd_shares_8bit_reg_L0[RND_SHARES_8bit - 1 : RND_BOX_SHARES_L0];
        fresh_rnd_8bit_modq_L1[0] = fresh_rnd_shares_8bit_reg_L1[RND_BOX_SHARES_L1 +: RND_BOX_SHARES_L1];
        
        fresh_rnd_shares_8bit_modq_reg_in_L0 = fresh_rnd_8bit_modq_L0[N_CYCLES];
        fresh_rnd_shares_8bit_modq_reg_in_L1 = fresh_rnd_8bit_modq_L1[N_CYCLES];
        
        fresh_rnd_modq_reg_in_L0 = fresh_rnd_modq_L0[N_CYCLES];
        
        fresh_rnd_modq_reg_in_L1 = fresh_rnd_modq_L1[N_CYCLES][RND_TRIANGLE_SHARES_L1 + 1 - 1 : 1];
        
        fresh_rnd_b2aq_L0[0][0] = fresh_rnd_modq_reg_L0[0];
        fresh_rnd_b2aq_L0[0][2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1 - 1 : 1] = fresh_rnd_modq_reg_L0[1 + RND_TRIANGLE_SHARES_L0 +: 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES];
        fresh_rnd_b2aq_8bit_L0[0] = fresh_rnd_shares_8bit_modq_reg_L0[RND_BOX_SHARES_L0 +: 2 * RND_BOX_SHARES_L1];

     end   
    
    ///////////
	// LOGIC //
	///////////
    
    
    generate 
    
    if (HALFCYCLE==0)
    begin
        for (idx = 0; idx < RND_SHARES - 2 * N_SHARES_L0 - 2 * (N_SHARES - 1) + 1 - 2 * N_SHARES; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_reg_in_L0[idx]), .q(fresh_rnd_shares_reg_L0[idx])); 
        end 
        for (idx = 0; idx < 1 + 2 * RND_TRIANGLE_SHARES_L1; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_reg_in_L1[idx]), .q(fresh_rnd_shares_reg_L1[idx])); 
        end
        for (idx = 0; idx < RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq_reg_in_L0[idx]), .q(fresh_rnd_modq_reg_L0[idx])); 
        end
        for (idx = 0; idx < RND_TRIANGLE_SHARES_L1; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_modq_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq_reg_in_L1[idx]), .q(fresh_rnd_modq_reg_L1[idx])); 
        end
        for (idx = 0; idx < RND_SHARES_8bit; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_8bit
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_8bit_reg_in_L0[idx]), .q(fresh_rnd_shares_8bit_reg_L0[idx]));
        end
        for (idx = 0; idx < 2 * RND_BOX_SHARES_L1; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_8bit_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_8bit_reg_in_L1[idx]), .q(fresh_rnd_shares_8bit_reg_L1[idx]));
        end
        for (idx = 0; idx < RND_SHARES_8bit - RND_BOX_SHARES_L0; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_8bit_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_8bit_modq_reg_in_L0[idx]), .q(fresh_rnd_shares_8bit_modq_reg_L0[idx]));
        end
        
        // CARRY REF
        for (idy = 0; idy < N_SHARES_L0; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_S1_L0_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(carry_ref_L0[idy]), .q(S_SecAdd_sel_L0[idy])); //data_type_mode & done_SecAdd[0]
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_S_L0_modq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(S_SecAdd_L0[0][idy]), .q(S_SecAdd_out_reg_L0[idy])); 
        end
        
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_S1_L1_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(carry_ref_L1[idy]), .q(S_SecAdd_sel_L1[idy])); //data_type_mode & done_SecAdd[0]
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_S_L1_modq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(S_SecAdd_L1[0][idy]), .q(S_SecAdd_out_reg_L1[idy])); 
        end
    end
    else
    begin
        for (idx = 1; idx < RND_TRIANGLE_SHARES_L0 + 1; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_reg_in_L0[idx]), .q(fresh_rnd_shares_reg_L0[idx])); 
            
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq_reg_in_L0[idx]), .q(fresh_rnd_modq_reg_L0[idx])); 
        end 
        for (idx = 1; idx < RND_TRIANGLE_SHARES_L1 + 1; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_reg_in_L1[idx]), .q(fresh_rnd_shares_reg_L1[idx])); 
            
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_modq_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq_reg_in_L1[idx - 1]), .q(fresh_rnd_modq_reg_L1[idx - 1])); 
        end
        assign fresh_rnd_shares_reg_L0[0] = fresh_rnd_shares_reg_in_L0[0];
        assign fresh_rnd_shares_reg_L0[RND_TRIANGLE_SHARES_L0 + 1 +: RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES] = fresh_rnd_shares_reg_in_L0[RND_TRIANGLE_SHARES_L0 + 1 +: RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES];
        
        assign fresh_rnd_shares_reg_L1[0] = fresh_rnd_shares_reg_in_L1[0];
        assign fresh_rnd_shares_reg_L1[2 * RND_TRIANGLE_SHARES_L1 + 1 - 1 : 1 + RND_TRIANGLE_SHARES_L1] = fresh_rnd_shares_reg_in_L1[1 + RND_TRIANGLE_SHARES_L1 +: RND_TRIANGLE_SHARES_L1];
        
        assign fresh_rnd_modq_reg_L0[0] = fresh_rnd_modq_L0[N_CYCLES][0];
        assign fresh_rnd_modq_reg_L0[RND_TRIANGLE_SHARES_L0 + 1 +: 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES] = fresh_rnd_modq_L0[N_CYCLES][1 + RND_TRIANGLE_SHARES_L0 +: 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES];
        
        assign fresh_rnd_shares_8bit_reg_L0 = fresh_rnd_shares_8bit_reg_in_L0;
        assign fresh_rnd_shares_8bit_reg_L1 = fresh_rnd_shares_8bit_reg_in_L1;
        assign fresh_rnd_shares_8bit_modq_reg_L0 = fresh_rnd_shares_8bit_modq_reg_in_L0;
        assign fresh_rnd_shares_8bit_modq_reg_L1 = fresh_rnd_shares_8bit_modq_reg_in_L1;
        
        // CARRY REF
        for (idy = 0; idy < N_SHARES_L0; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_S1_L0_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(carry_ref_L0[idy]), .q(S_SecAdd_sel_L0[idy])); //data_type_mode & done_SecAdd[0]
            
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_S_L0_modq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(S_SecAdd_L0[0][idy]), .q(S_SecAdd_out_reg_L0[idy])); 
        end
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_S1_L1_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(carry_ref_L1[idy]), .q(S_SecAdd_sel_L1[idy])); //data_type_mode & done_SecAdd[0]
            
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_S_L1_modq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(S_SecAdd_L1[0][idy]), .q(S_SecAdd_out_reg_L1[idy])); 
        end
    end
    
    for (idx = 0; idx < N_CYCLES; idx++)
    begin
        for (idy = 0; idy < RND_TRIANGLE_SHARES_L0 + 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_L0_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq_L0[idx][idy]), .q(fresh_rnd_modq_L0[idx+1][idy]));
        end
        for (idy = 0; idy < RND_TRIANGLE_SHARES_L1 + 1; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_L1_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq_L1[idx][idy]), .q(fresh_rnd_modq_L1[idx+1][idy]));
        end
        for (idy = 0; idy < RND_SHARES_8bit - RND_BOX_SHARES_L0; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd8bit_L0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_8bit_modq_L0[idx][idy]), .q(fresh_rnd_8bit_modq_L0[idx+1][idy]));
        end
        for (idy = 0; idy < RND_BOX_SHARES_L1; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd8bit_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_8bit_modq_L1[idx][idy]), .q(fresh_rnd_8bit_modq_L1[idx+1][idy]));
        end
        for (idy = 0; idy < 2 * RND_TRIANGLE_SHARES_L1 + 2 * N_SHARES + 1; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_L0_b2aq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(fresh_rnd_b2aq_L0[idx][idy]), .q(fresh_rnd_b2aq_L0[idx+1][idy]));
        end
        for (idy = 0; idy < 2 * RND_BOX_SHARES_L1; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_b2aq_8bit_L0
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(fresh_rnd_b2aq_8bit_L0[idx][idy]), .q(fresh_rnd_b2aq_8bit_L0[idx+1][idy]));
        end
    end
    
    // REFRESH CARRY BIT
    (* keep_hierarchy = "TRUE" *) SecXOR
    #(
        .N_SHARES(N_SHARES_L0),
        .PARAM_WIDTH(1)
    ) 
    carry_refresh_L0_inst
    (
        .a(carry_in_L0), 
        .b(carry_rnd_L0),
        .c(carry_ref_L0)
    );
    
    (* keep_hierarchy = "TRUE" *) SecXOR
    #(
        .N_SHARES(N_SHARES),
        .PARAM_WIDTH(1)
    ) 
    carry_refresh_L1_inst
    (
        .a(carry_in_L1), 
        .b(carry_rnd_L1),
        .c(carry_ref_L1)
    );
    
    for (idx = 0; idx < 2; idx++)
    begin
    
        // EXPAND
        if (HALFCYCLE==0)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_en_expand_L0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand_L0[idx]), .q(en_expand_L0_reg[idx]));
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_en_expand_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand_L1[idx]), .q(en_expand_L1_reg[idx]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_done_SecAdd_L0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(done_SecAdd_L0[idx]), .q(done_SecAdd_reg_L0[idx]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_done_SecAdd_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(done_SecAdd_L1[idx]), .q(done_SecAdd_reg_L1[idx]));
            
            for (idy = 0; idy < N_SHARES_L0; idy++)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L0[idx][idy]), .q(expand_reg_L0[idx][idy]));
                
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand_dual
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L0[2 + idx][idy]), .q(expand_reg_L0[2 + idx][idy]));
            end
            for (idy = 0; idy < N_SHARES; idy++)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand_L1
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L1[idx][idy]), .q(expand_reg_L1[idx][idy]));
                
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand_dual_L1
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L1[2 + idx][idy]), .q(expand_reg_L1[2 + idx][idy]));
            end
        end
        else
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_en_expand_L0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand_L0[idx]), .q(en_expand_L0_reg[idx]));
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_en_expand_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand_L1[idx]), .q(en_expand_L1_reg[idx]));
            
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_done_SecAdd_L0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(done_SecAdd_L0[idx]), .q(done_SecAdd_reg_L0[idx]));
            
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_done_SecAdd_L1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(done_SecAdd_L1[idx]), .q(done_SecAdd_reg_L1[idx]));
            
            for (idy = 0; idy < N_SHARES_L0; idy++)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L0[idx][idy]), .q(expand_reg_L0[idx][idy]));
                
                (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand_dual
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L0[2 + idx][idy]), .q(expand_reg_L0[2 + idx][idy]));
            end
            for (idy = 0; idy < N_SHARES; idy++)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand_L1
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L1[idx][idy]), .q(expand_reg_L1[idx][idy]));
                
                (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand_dual_L1
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in_L1[2 + idx][idy]), .q(expand_reg_L1[2 + idx][idy]));
            end
        end
        
        for (idy = 0; idy < N_CYCLES; idy++)
        begin
            for (idz = 0; idz < N_SHARES; idz++)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_single_share
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(single_reg[idx][idy][idz]), .q(single_reg[idx][idy + 1][idz]));
            end
            for (idz = 0; idz < N_SHARES - 1; idz++)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_B2A_share_L0
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(B2A_orig_L0[idx][idy][idz]), .q(B2A_orig_L0[idx][idy + 1][idz]));
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_B2A_share_L1
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(B2A_orig_L1[idx][idy][idz]), .q(B2A_orig_L1[idx][idy + 1][idz]));
            end
        end
        
        (* keep_hierarchy = "TRUE" *) SecXOR
        #(
            .N_SHARES(N_SHARES_L0),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        EXPAND_L0_inst
        (
            .a(input_expand_L0[idx]), 
            .b(rnd_expand_L0[idx]),
            .c(output_expand_L0[idx])
        );
        
        (* keep_hierarchy = "TRUE" *) SecXOR
        #(
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        EXPAND_single_inst
        (
            .a(input_expand_single[idx]), 
            .b(rnd_expand_single[idx]),
            .c(output_expand_single[idx])
        );
        
        (* keep_hierarchy = "TRUE" *) SecNOT
        #(
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        NOT_expand_inst
        (
            .in(input_expand_INV[idx]), 
            .out(output_expand_INV[idx])
        );
        
        
        
        (* keep_hierarchy = "TRUE" *) SecXOR
        #(
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        EXPAND_L1_inst
        (
            .a(input_expand_L1[idx]), 
            .b(rnd_expand_L1[idx]),
            .c(output_expand_L1[idx])
        );
        
        
        
        (* keep_hierarchy = "TRUE" *) SecAdd_HALFCYCLE_STREAM
        #(
            .HALFCYCLE(HALFCYCLE),
            .N_SHARES(N_SHARES_L0),
            .PARAM_WIDTH(PARAM_WIDTH)
        )
        SecADD_Layer0_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            .start(start_SecAdd_L0[idx]),
            .done(done_SecAdd_L0[idx]),
            .fresh_rnd_triangle(fresh_rnd_triangle_L0[idx]),
            .fresh_rnd_box(fresh_rnd_box_L0[idx]),
            .a(a_SecAdd_L0[idx]),
            .b(b_SecAdd_L0[idx]),
            .S(S_SecAdd_L0[idx])
        );
        
        (* keep_hierarchy = "TRUE" *) SecAdd_HALFCYCLE_STREAM
        #(
            .HALFCYCLE(HALFCYCLE),
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        )
        SecADD_Layer1_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            .start(start_SecAdd_L1[idx]),
            .done(done_SecAdd_L1[idx]),
            .fresh_rnd_triangle(fresh_rnd_triangle_L1[idx]),
            .fresh_rnd_box(fresh_rnd_box_L1[idx]),
            .a(a_SecAdd_L1[idx]),
            .b(b_SecAdd_L1[idx]),
            .S(S_SecAdd_L1[idx])
        );
        
        (* keep_hierarchy = "TRUE" *) SecNOT
        #(
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        NOT_B2A_inst
        (
            .in(S_SecAdd_L1[idx]), 
            .out(X2B_out[idx])
        );
        
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            if(HALFCYCLE)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_X2Bout
                (.clk(clk), .rst_n(rst_n), .en(conversion_mode_reg), .d(X2B_out[idx][idy]), .q(X2B_out_reg[idx][idy]));
            end
            else
            begin
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand
                (.clk(clk), .rst_n(rst_n), .en(conversion_mode_reg), .d(X2B_out[idx][idy]), .q(X2B_out_reg[idx][idy]));
            end
        end
        
        (* keep_hierarchy = "TRUE" *) fullXOR
        #(
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        fullXOR_inst
        (
            .full(X2B_out_reg[idx]), 
            .single(xor_result[idx])
        );
        
    end
    endgenerate
       
endmodule

