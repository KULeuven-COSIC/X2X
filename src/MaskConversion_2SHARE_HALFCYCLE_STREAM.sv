
// FRESH RND SHARES 
// - EXPAND SHARES: N_SHARES
// - B2A RND SHARES: N_SHARES - 1
// - TRIANGLE: 2 * (N_SHARES * (N_SHARES - 1) / 2)

module MaskConversion_2SHARE_HALFCYCLE_STREAM
#(
    parameter HALFCYCLE = 0,
    parameter LOG2_OF_q = 12,               // ceil(LOG2(3329))
    parameter N_STAGES = 4,
    parameter TWO_COMPLEMENT_MINUS_q = 4863, //62207, //(2^16 - q)
    parameter KYBER_q = 3329,
    
    parameter PARAM_WIDTH = LOG2_OF_q + 1,  // # bits / data word
    parameter N_SHARES = 2, // protection order + 1 (# primary arithmetic shares)
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
    //output logic dual_mode_out,     // 0 -> single output, 1 -> dual output
    
    // RND 1 + 2
    input logic [PARAM_WIDTH - 1 : 0]   fresh_rnd_shares        [RND_SHARES - 1 : 0],
    input logic [8 - 1 : 0]             fresh_rnd_shares_8bit   [RND_SHARES_8bit - 1 : 0], // FOR 2 SECADD, either mod q or power-of-two in parallel
    
    // DATA 1 + 2
    input logic  [PARAM_WIDTH - 1 : 0] original_data    [2 - 1 : 0][N_SHARES - 1:0],
    output logic [PARAM_WIDTH - 1 : 0] converted_data   [2 - 1 : 0][N_SHARES - 1:0]
);
	
	
	/////////////////////////////////
	// INTERNAL SIGNAL DECLARATION //
	/////////////////////////////////
	
	genvar idx, idy;
	
	localparam RND_TRIANGLE_SHARES = 2 * (N_SHARES * (N_SHARES - 1) / 2);
	localparam RND_OTHER_SHARES = 2 * N_SHARES + 2 * (N_SHARES - 1);
	localparam RND_BOX_SHARES = (N_STAGES - 1) * 3 *(N_SHARES * (N_SHARES - 1) / 2) + 2 *(N_SHARES * (N_SHARES - 1) / 2);
	
	localparam N_CYCLES = (HALFCYCLE==1) ? (N_STAGES + 1) : ((N_STAGES + 1) * 2) - 1 + 1;
	localparam N_CYCLES_B2Aq = (HALFCYCLE==1) ? N_STAGES + 1 : (N_STAGES + 1) * 2;
	
	localparam CYCLE_Q = (HALFCYCLE==1) ? N_CYCLES : N_CYCLES - 1;
    
    // EXPAND
    logic                       en_expand       [2 - 1 : 0];              
    logic                       en_expand_reg   [2 - 1 : 0];
    logic                       active_expand   [2 - 1 : 0];     
    logic [PARAM_WIDTH - 1 : 0] input_expand    [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] rnd_expand      [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] output_expand   [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] input_expand_INV  [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] output_expand_INV [2 - 1 : 0][N_SHARES - 1 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] expand_reg_in   [2 - 1 : 0][2 * N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] expand_reg      [2 - 1 : 0][2 * N_SHARES - 1 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] active_fresh_rnd        [RND_SHARES - 2 * N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_shares_reg_in [RND_SHARES - 2 * N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_shares_reg    [RND_SHARES - 2 * N_SHARES - 1 : 0];
    logic [8 - 1 : 0]           active_fresh_rnd_8bit       [RND_SHARES_8bit - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_reg       [RND_SHARES_8bit - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_shares_8bit_reg_in    [RND_SHARES_8bit - 1 : 0];
    
    // SECADD 
    logic                       start_SecAdd        [2 - 1 : 0];
    logic                       done_SecAdd         [2 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_triangle  [2 - 1 : 0][RND_TRIANGLE_SHARES - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_box       [2 - 1 : 0][RND_BOX_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] a_SecAdd            [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] b_SecAdd            [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] S_SecAdd            [2 - 1 : 0][N_SHARES - 1 : 0];
    logic                       S_SecAdd_sel        [N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] S_SecAdd_out_reg    [N_SHARES - 1 : 0];
    
    logic                       carry_in            [N_SHARES - 1 : 0];
    logic                       carry_rnd           [N_SHARES - 1 : 0];
    logic                       carry_ref           [N_SHARES - 1 : 0];
    
    logic                       done_SecAdd_reg     [2 - 1 : 0];
    
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq      [N_CYCLES : 0][RND_TRIANGLE_SHARES + 2 * (N_SHARES - 1) - 1 : 0]; // RND_TRIANGLE_SHARES + 1
    logic [PARAM_WIDTH - 1 : 0] fresh_rnd_modq_reg  [RND_TRIANGLE_SHARES - 1 : 0];
    logic [8 - 1 : 0]           fresh_rnd_8bit_modq [N_CYCLES : 0][RND_BOX_SHARES - 1 : 0];
    
    // FullXOR 
    logic [PARAM_WIDTH - 1 : 0] X2B_out             [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] X2B_out_reg         [2 - 1 : 0][N_SHARES - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] xor_result          [2 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] B2Ap_share_reg      [2 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] active_B2Ap_share   [2 - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] B2A_rnd_share       [N_CYCLES_B2Aq : 0];
	
    /////////
	// I/0 //
	/////////
	
	logic  conversion_mode_reg;
	logic  data_type_reg;
	logic  dual_mode_reg;
	
	generate
	
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
   
    endgenerate
	
    always_ff @(posedge clk, negedge rst_n) 
    begin
        if (rst_n == 1'b0) // reset control logic
        begin
            ready_data = 1'b0;
        end 
        else 
        begin
            ready_data = 1'b1;
        end
    end
    
    assign valid_result = conversion_mode_reg ? data_type_reg ? done_SecAdd_reg[1] : done_SecAdd_reg[0] : data_type_reg ? done_SecAdd[1] : done_SecAdd[0];
	    
    /////////////
	// CONTROL //
	/////////////
	
	always_comb
	begin
	
	   en_expand[0] = valid_data; //valid_data;
	   en_expand[1] = dual_mode_reg & valid_data; //valid_data
	   
	   converted_data[0] = conversion_mode_reg ? data_type_reg ? '{xor_result[1], B2A_rnd_share[N_CYCLES_B2Aq]} : '{xor_result[0], active_B2Ap_share[0]} : data_type_reg ? S_SecAdd[1] : S_SecAdd[0]; //active_B2Ap_share[0]
	   converted_data[1] = conversion_mode_reg ? data_type_reg ? '{default: '0} : '{xor_result[1], active_B2Ap_share[1]} : data_type_reg ? '{default: '0} : S_SecAdd[1];
	   
	   rnd_expand[0] = en_expand[0] ? fresh_rnd_shares[N_SHARES - 1 : 0] : '{default: '0}; // HERE
	   for (int i = 0; i < N_SHARES; i=i+1)
	   begin
	       rnd_expand[1][i] = en_expand[1] ? fresh_rnd_shares[N_SHARES + i] : '0; // HERE
	       
	       carry_rnd[i] = data_type_reg ? fresh_rnd_modq[CYCLE_Q][1][0] : '0; //N_CYCLES
	       carry_in[i] = data_type_reg ? S_SecAdd[0][i][PARAM_WIDTH - 1] : '0; 
	   end
	   
	   start_SecAdd[0] = active_expand[0];
	   start_SecAdd[1] = data_type_reg ? done_SecAdd_reg[0] : active_expand[1];
	   
	   for (int i = 0; i < RND_SHARES - 2 * N_SHARES; i=i+1)
	   begin
	       fresh_rnd_shares_reg_in[i] = en_expand[0] ? fresh_rnd_shares[2 * N_SHARES + i] : '0; // HERE
	   end
	   fresh_rnd_shares_8bit_reg_in = en_expand[0] ? fresh_rnd_shares_8bit : '{default: '0}; // HERE
	   
	   fresh_rnd_triangle[0] = active_fresh_rnd[2 * (N_SHARES - 1) + RND_TRIANGLE_SHARES - 1 : 2 * (N_SHARES - 1)];
	   for (int i = 0; i < RND_TRIANGLE_SHARES; i=i+1)
	   begin
	       fresh_rnd_triangle[1][i] = data_type_reg ? fresh_rnd_modq_reg[i] : active_fresh_rnd[2 * (N_SHARES - 1) + RND_TRIANGLE_SHARES + i]; // TODO for fullcycle
           fresh_rnd_modq[0][2 * (N_SHARES - 1) + i] = active_fresh_rnd[2 * (N_SHARES - 1) + RND_TRIANGLE_SHARES + i];
	   end
	   
	   fresh_rnd_modq[0][0] = active_fresh_rnd[0];
	   fresh_rnd_modq[0][1] = active_fresh_rnd[1];
       B2A_rnd_share[0] = conversion_mode_reg & data_type_reg ? fresh_rnd_modq[N_CYCLES][0] : '0;
	   
	   fresh_rnd_box[0] = active_fresh_rnd_8bit[RND_BOX_SHARES - 1 : 0];
	   for (int i = 0; i < RND_BOX_SHARES; i=i+1)
	   begin
	       fresh_rnd_box[1][i] = data_type_reg ? fresh_rnd_8bit_modq[N_CYCLES][i] : active_fresh_rnd_8bit[RND_BOX_SHARES + i];
	       fresh_rnd_8bit_modq[0][i] = active_fresh_rnd_8bit[RND_BOX_SHARES + i];
	   end
	   
	   
	   a_SecAdd[0] = expand_reg[0][N_SHARES - 1 : 0];
	   b_SecAdd[0] = expand_reg[0][2 * N_SHARES - 1 : N_SHARES];
	   a_SecAdd[1] = data_type_reg ? S_SecAdd_out_reg : expand_reg[1][N_SHARES - 1 : 0];
                
	   
	   //B2A
	   if(conversion_mode_reg)
	   begin
	       for (int i = 0; i < N_SHARES; i++) 
           begin
                if (i == 0) 
                begin
                    b_SecAdd[1][i] = data_type_reg ? (S_SecAdd_sel[i]) ? TWO_COMPLEMENT_MINUS_q : '0 : expand_reg[1][N_SHARES + i]; //-q is positive, +0 if negative
                end
                else 
                begin
                    b_SecAdd[1][i] = data_type_reg ? done_SecAdd_reg[0] ? (S_SecAdd_sel[i]) ? '0 : TWO_COMPLEMENT_MINUS_q : '0 : expand_reg[1][N_SHARES + 1]; //-q is positive, +0 if negative
                end
            end       
	       for (int i = 0; i < 2; i=i+1)
	       begin
	           input_expand[i][0] = en_expand[i] ? fresh_rnd_shares[2 * N_SHARES + i] : '0;
	           input_expand[i][1] = '0;
	           
	           input_expand_INV[i] = en_expand[i] ? original_data[i] : '{default: '0};
	           expand_reg_in[i][N_SHARES - 1 : 0] = en_expand[i] ? output_expand_INV[i] : '{default: '0};//original_data[i];
	           expand_reg_in[i][2 * N_SHARES - 1 : N_SHARES] = '{output_expand[i][0],rnd_expand[i][0]};
	       end
	   end
	   
	   // A2B
	   else
	   begin
	       input_expand = en_expand[0] ? original_data : '{default : '0};// original_data_reg
	       
	       input_expand_INV = '{default: '0};
	       
	       for (int i = 0; i < N_SHARES; i++) 
           begin
                b_SecAdd[1][i] = data_type_reg ? (S_SecAdd_sel[i]) ? KYBER_q : '0 : expand_reg[1][N_SHARES + i]; //-q is positive, +0 if negative
           end     
	       
	       for (int i = 0; i < 2; i=i+1)
	       begin
//	           expand_reg_in[i] = '{output_expand[i][1], rnd_expand[i][1], output_expand[i][0], rnd_expand[i][0]};
                expand_reg_in[i][0] = output_expand[i][0];
                expand_reg_in[i][1] = rnd_expand[i][0];
                expand_reg_in[i][2] = output_expand[i][1];
                expand_reg_in[i][3] = rnd_expand[i][1];
	       end
	   end
	end
    
    ///////////
	// LOGIC //
	///////////
	
	generate
	
	if(HALFCYCLE==0)
    begin
        assign active_expand = en_expand_reg;
        assign active_fresh_rnd = fresh_rnd_shares_reg;
        assign active_fresh_rnd_8bit = fresh_rnd_shares_8bit_reg;
        assign active_B2Ap_share = B2Ap_share_reg;
         
        (* keep_hierarchy = "TRUE" *) D_reg 
        #(.PARAM_WIDTH(1)) 
        D_reg_en_expand0
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand[0]), .q(en_expand_reg[0]));
        
        (* keep_hierarchy = "TRUE" *) D_reg 
        #(.PARAM_WIDTH(1)) 
        D_reg_en_expand1
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand[1]), .q(en_expand_reg[1]));
        
        for (idy = 0; idy < RND_SHARES - 2 * N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_reg_in[idy]), .q(fresh_rnd_shares_reg[idy])); 
        end
        
        for (idy = 0; idy < RND_SHARES_8bit; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_8bit
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_8bit_reg_in[idy]), .q(fresh_rnd_shares_8bit_reg[idy]));
        end
        
        for (idy = 0; idy < 2 * (N_SHARES - 1); idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_B2A_rnd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq[N_CYCLES - 1][idy]), .q(B2Ap_share_reg[idy]));
        end
        
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_S1_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(carry_ref[idy]), .q(S_SecAdd_sel[idy])); //data_type_mode & done_SecAdd[0]
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_S_modq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(S_SecAdd[0][idy]), .q(S_SecAdd_out_reg[idy])); 
        end
        
    end
    else
    begin
//        assign S_SecAdd_out_reg = S_SecAdd[0];
        assign active_fresh_rnd = fresh_rnd_shares_reg;
        assign active_expand = en_expand_reg;
        assign active_fresh_rnd_8bit = en_expand_reg[0] ? fresh_rnd_shares_8bit : '{default: '0}; // HERE
        assign active_B2Ap_share = fresh_rnd_modq[N_CYCLES][2 * (N_SHARES - 1) - 1 : 0];
        
        (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
        #(.PARAM_WIDTH(1)) 
        D_reg_en_expand0
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand[0]), .q(en_expand_reg[0]));
        
        (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
        #(.PARAM_WIDTH(1)) 
        D_reg_en_expand1
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(en_expand[1]), .q(en_expand_reg[1]));
        
        for (idy = 0; idy < RND_TRIANGLE_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd_modq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(fresh_rnd_modq[N_CYCLES][2 * (N_SHARES - 1) + idy]), .q(fresh_rnd_modq_reg[idy])); 
        end 
        
        for (idy = 0; idy < RND_SHARES - 2 * N_SHARES; idy++)
        begin
//            assign active_fresh_rnd[idy] = en_expand_reg[0] ? fresh_rnd_shares[idy + 2 * N_SHARES] : '0; // HERE
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_shares_reg_in[idy]), .q(fresh_rnd_shares_reg[idy])); 
        end
        
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_S1_modq
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(carry_ref[idy]), .q(S_SecAdd_sel[idy])); //IDEM
            
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_S_modq
            (.clk(clk), .rst_n(rst_n), .en(data_type_reg), .d(S_SecAdd[0][idy]), .q(S_SecAdd_out_reg[idy]));
        end
    end
    
    for (idx = 0; idx < N_CYCLES; idx++)
    begin
        for (idy = 0; idy < RND_TRIANGLE_SHARES + 2 * (N_SHARES - 1); idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_fresh_rnd1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_modq[idx][idy]), .q(fresh_rnd_modq[idx+1][idy]));
        end
        for (idy = 0; idy < RND_BOX_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd8bit1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_8bit_modq[idx][idy]), .q(fresh_rnd_8bit_modq[idx+1][idy]));
        end
        
    end
    
    for (idx = 0; idx < N_CYCLES_B2Aq; idx++)
    begin
        (* keep_hierarchy = "TRUE" *) D_reg 
        #(.PARAM_WIDTH(PARAM_WIDTH)) 
        D_reg_B2A_rnd
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(B2A_rnd_share[idx]), .q(B2A_rnd_share[idx + 1]));
    end
    
    // REFRESH CARRY BIT
    (* keep_hierarchy = "TRUE" *) SecXOR
    #(
        .N_SHARES(N_SHARES),
        .PARAM_WIDTH(1)
    ) 
    carry_refresh_inst
    (
        .a(carry_in), 
        .b(carry_rnd),
        .c(carry_ref)
    );
	
	for (idx = 0; idx < 2; idx++)
	begin
        // EXPAND
        (* keep_hierarchy = "TRUE" *) SecXOR
        #(
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        EXPAND_inst
        (
            .a(input_expand[idx]), 
            .b(rnd_expand[idx]),
            .c(output_expand[idx])
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
        
        for (idy = 0; idy < 2 * N_SHARES; idy++)
        begin
            if(HALFCYCLE)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in[idx][idy]), .q(expand_reg[idx][idy]));
            end
            else
            begin
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_expand
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(expand_reg_in[idx][idy]), .q(expand_reg[idx][idy]));
            end
        end
        
        if(HALFCYCLE==0)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_done_SecAdd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(done_SecAdd[idx]), .q(done_SecAdd_reg[idx]));
        end
        else
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(1)) 
            D_reg_done_SecAdd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(done_SecAdd[idx]), .q(done_SecAdd_reg[idx]));
        end
        
        (* keep_hierarchy = "TRUE" *) SecAdd_HALFCYCLE_STREAM
        #(
            .HALFCYCLE(HALFCYCLE),
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        )
        SecADD_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            .start(start_SecAdd[idx]),
            .done(done_SecAdd[idx]),
            .fresh_rnd_triangle(fresh_rnd_triangle[idx]),
            .fresh_rnd_box(fresh_rnd_box[idx]),
            .a(a_SecAdd[idx]),
            .b(b_SecAdd[idx]),
            .S(S_SecAdd[idx])
        );
        
        (* keep_hierarchy = "TRUE" *) SecNOT
        #(
            .N_SHARES(N_SHARES),
            .PARAM_WIDTH(PARAM_WIDTH)
        ) 
        NOT_B2A_inst
        (
            .in(S_SecAdd[idx]), 
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
    
    
