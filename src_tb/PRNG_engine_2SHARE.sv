
// [(N_SHARES - 1) - 1 : 0] -> B2A (NON-)CORRECTED RND INPUT 
// LAYERS
    // [N_SHARES - 1 : 0]       -> EXPAND
    // [2 * (N_SHARES * (N_SHARES - 1) / 2) - 1 : 0]    -> TRIANGLE
    // [2 * (N_SHARES * (N_SHARES - 1) / 2) - 1 : 0]    -> TRIANGLE mod q
// [(N_SHARES - 1) - 1 : 0] -> B2A RND INPUT


module PRNG_engine_2SHARE
#(
    parameter PARAM_WIDTH = 13,
    parameter LSFR_WIDTH = 32, 
    parameter KYBER_Q = 3329,
    parameter N_SHARES = 2,
    
    // DO NOT CHANGE
    parameter B2A_RND_SHARES = N_SHARES - 1,
    parameter EXPAND_SHARES = N_SHARES,
    parameter TRIANGLE_SHARES = 2 * (N_SHARES * (N_SHARES - 1) / 2),
    parameter BOX_SHARES = 3 * 3 * (N_SHARES * (N_SHARES - 1) / 2) + 2 * (N_SHARES * (N_SHARES - 1) / 2),
    
    
    parameter RND_SHARES = 2 * B2A_RND_SHARES + 2 * EXPAND_SHARES + 2 * TRIANGLE_SHARES,
    parameter RND_SHARES_8bit = 2 * BOX_SHARES,
    
    // MINIMUM = LSFR_WIDTH * (PARAM_WIDTH + 8) = 5.25
    parameter SEED_WIDTH = 6*128 // TODO
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // CONTROL
    input logic mod_type,
    input logic conversion_type,
    input logic dual_mode,
    input logic load_seed,
    input logic update_rnd, // start to fill RND array
    output logic prng_done, // done: array filled with required RND shares
    
    // DATA
    input logic  [SEED_WIDTH - 1 : 0]   seed_in,
    output logic [8 - 1 : 0]            rnd_out_8bit    [RND_SHARES_8bit - 1 : 0],
    output logic [PARAM_WIDTH - 1 : 0]  rnd_out         [RND_SHARES - 1 : 0] // should be in reg internally, connected via wire to crypto core, where all shares except used in first cycle are registered
);
    
    /////////////////////////////////
	// INTERNAL SIGNAL DECLARATION //
	/////////////////////////////////
	
    genvar idx;
    logic [32 - 1 : 0] counter;         // generic counter
    logic [32 - 1 : 0] counter_8bit;
    
    logic [LSFR_WIDTH - 1 : 0] reset_seed_16bit [PARAM_WIDTH - 1 : 0];
    logic [LSFR_WIDTH - 1 : 0] reset_seed_8bit [8 - 1 : 0];
    logic request_rnd_16bit;
    logic request_rnd_8bit;
    
    logic [PARAM_WIDTH - 1 : 0] rnd_share_16bit;
    logic [8 - 1 : 0] rnd_share_8bit;
    
    logic [8 - 1 : 0] rnd_reg_8bit      [RND_SHARES_8bit - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] rnd_reg [RND_SHARES - 1 : 0];
    
    
    // FSM
    localparam STATE_IDLE               = 4'h0;
    localparam STATE_EXPAND             = 4'h1;
    localparam STATE_EXPAND_DUAL        = 4'h2;
    localparam STATE_B2A_RND            = 4'h3;
    localparam STATE_B2A_RND_DUAL       = 4'h4;
    localparam STATE_A2B                = 4'h5; // triangles secadd
    localparam STATE_WAIT               = 4'h6;
    localparam STATE_FINISH             = 4'h7;
    
    logic [4 - 1 : 0] state;
    
    localparam STATE_8BIT_IDLE     = 2'h0;
    localparam STATE_8BIT_A2B      = 2'h1;
    localparam STATE_8BIT_WAIT     = 2'h2;
    localparam STATE_8BIT_FINISH   = 2'h3;
    
    logic [2 - 1 : 0] state_8bit;
    
    
    //////////
	// I/0 //
	//////////
    
    assign prng_done = (state == STATE_FINISH);
    assign rnd_out = (prng_done) ? rnd_reg : '{default : '0};
    assign rnd_out_8bit = (prng_done) ? rnd_reg_8bit : '{default : '0};
    
    generate
    for (idx = 0; idx < PARAM_WIDTH; idx++)
    begin
        assign reset_seed_16bit[idx] = seed_in[idx*LSFR_WIDTH + LSFR_WIDTH - 1 : idx*LSFR_WIDTH];
    end
    
    for (idx = 0; idx < 8; idx++)
    begin
        assign reset_seed_8bit[idx] = seed_in[idx*LSFR_WIDTH + LSFR_WIDTH + LSFR_WIDTH*PARAM_WIDTH - 1 : idx*LSFR_WIDTH + LSFR_WIDTH*PARAM_WIDTH];  
    end
    endgenerate
    
    
    /////////////
	// CONTROL //
	/////////////
    
    always_ff @(posedge clk, negedge rst_n)
    begin
    
        if (rst_n == 1'b0)
        begin
            state <= STATE_IDLE;  
            counter <= 0;   
        end
        else 
        begin
            case(state)
            
                STATE_IDLE :
                begin
                    if (update_rnd)
                    begin
                        state <= STATE_EXPAND;
                        
                        request_rnd_16bit <= 1'b1;
                        counter <= 0;
                    end
                    else
                    begin
                        state <= STATE_IDLE;
                        
                        rnd_reg <= '{default : '0};
                        counter <= 0;
                    end
                end
                
                STATE_EXPAND :
                begin
                    if (conversion_type)
                    begin
                        rnd_reg[counter] <= rnd_share_16bit;
                        
                        counter <= dual_mode ? counter + EXPAND_SHARES : counter + 2 * EXPAND_SHARES;
                        state <= dual_mode ? STATE_EXPAND_DUAL : STATE_B2A_RND;
                    end 
                    else 
                    begin
                        rnd_reg[counter] <= rnd_share_16bit;
                        
                        if (counter == EXPAND_SHARES - 1)
                        begin
                            counter <= dual_mode ? counter + 1 : mod_type ? counter + EXPAND_SHARES + B2A_RND_SHARES + 1 : counter + EXPAND_SHARES + 2 * B2A_RND_SHARES + 1;
                            state <= dual_mode ? STATE_EXPAND_DUAL : mod_type ? STATE_B2A_RND_DUAL : STATE_A2B;
                        end
                        else
                        begin
                            counter <= counter + 1;
                            state <= STATE_EXPAND;
                        end
                    end
                end
                
                STATE_EXPAND_DUAL :
                begin
                    if (conversion_type)
                    begin
                        rnd_reg[counter] <= rnd_share_16bit;
                        
                        counter <= counter + EXPAND_SHARES;
                        state <= STATE_B2A_RND;
                    end 
                    else 
                    begin
                        rnd_reg[counter] <= rnd_share_16bit;
                        
                        if (counter == 2 * EXPAND_SHARES - 1)
                        begin
                            counter <= counter + 2 * B2A_RND_SHARES + 1;
                            state <= STATE_A2B;
                        end
                        else
                        begin
                            counter <= counter + 1;
                            state <= STATE_EXPAND_DUAL;
                        end
                    end
                end
                
                STATE_B2A_RND :
                begin
                    rnd_reg[counter] <= (mod_type) ? (rnd_share_16bit[PARAM_WIDTH - 2 : 0] < KYBER_Q) ? {1'b0,rnd_share_16bit[PARAM_WIDTH - 2 : 0]} : {1'b0, rnd_share_16bit[PARAM_WIDTH - 2 : 0] - 3329} : rnd_share_16bit;
                   
                    counter <= (dual_mode | mod_type) ? counter + 1 : counter + B2A_RND_SHARES + 1;
                    state <= (dual_mode | mod_type) ? STATE_B2A_RND_DUAL : STATE_A2B;
                end
                
                STATE_B2A_RND_DUAL :
                begin
                    rnd_reg[counter] <= rnd_share_16bit;

                    counter <= counter + 1;
                    state <= STATE_A2B;
                end
                
                STATE_A2B :
                begin
                    
                    rnd_reg[counter] <= rnd_share_16bit;
                    counter <= counter + 1;
                    
                    if (counter == 2 * B2A_RND_SHARES + 2 * EXPAND_SHARES + TRIANGLE_SHARES - 1)
                    begin
                        state <= (mod_type | mod_type) ? STATE_A2B : STATE_WAIT;
                    end
                    else if (counter == 2 * B2A_RND_SHARES + 2 * EXPAND_SHARES + 2 * TRIANGLE_SHARES - 1)
                    begin
                        state <= STATE_WAIT;
                    end
                    else 
                    begin
                        state <= STATE_A2B;
                    end
                end
                
                STATE_WAIT : 
                begin 
                    request_rnd_16bit <= 1'b0;
                    
                    if (state_8bit == STATE_8BIT_WAIT)
                    begin
                        state <= STATE_FINISH;
                    end
                    else 
                    begin
                        state <= STATE_WAIT;
                    end
                end
                
                STATE_FINISH :
                begin
                    state <= STATE_IDLE;
                    
                    counter <= 0;
                end
            endcase
        end
    end
    
    always_ff @(posedge clk, negedge rst_n)
    begin
    
        if (rst_n == 1'b0)
        begin
            state_8bit <= STATE_8BIT_IDLE;  
            counter_8bit <= 0;   
        end
        else 
        begin
            case(state_8bit)
            
                STATE_8BIT_IDLE :
                begin
                    if (update_rnd)
                    begin
                        state_8bit <= STATE_8BIT_A2B;
                        
                        request_rnd_8bit <= 1'b1;
                        counter_8bit <= 0;
                    end
                    else
                    begin
                        state_8bit <= STATE_8BIT_IDLE;
                        
                        rnd_reg_8bit <= '{default : '0};
                        counter_8bit <= 0;
                    end
                end
                
                STATE_8BIT_A2B :
                begin 
                    rnd_reg_8bit[counter_8bit] <= rnd_share_8bit;
                    counter_8bit <= counter_8bit + 1;
                    
                    if (counter_8bit == BOX_SHARES - 1)
                    begin
                        if (dual_mode | mod_type)
                        begin
                            state_8bit <= STATE_8BIT_A2B;
                        end 
                        else
                        begin
                            state_8bit <= STATE_8BIT_WAIT;
                        end
                    end
                    else if (counter_8bit == 2 * BOX_SHARES - 1)
                    begin
                        state_8bit <= STATE_8BIT_WAIT;
                    end
                    else 
                    begin
                        state_8bit <= STATE_8BIT_A2B;
                    end
                end
                
                STATE_8BIT_WAIT :
                begin 
                    request_rnd_8bit <= 1'b0;
                    
                    if (state == STATE_WAIT)
                    begin 
                        state_8bit <= STATE_8BIT_WAIT;
                    end 
                    else 
                    begin 
                        state_8bit <= STATE_8BIT_FINISH;
                    end
                end
                
                STATE_8BIT_FINISH :
                begin 
                    counter_8bit <= 0;
                    
                    state_8bit <= STATE_8BIT_IDLE;
                end
            endcase
        end
    end
    
    
    
    ///////////
	// LOGIC //
	///////////
    
    // PRNG instances
    PRNG
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .LSFR_WIDTH(LSFR_WIDTH)
    )
    prng_inst
    (
        .clk(clk),
        .rst_n(rst_n),
        .seed_prng(load_seed),
        .request_rnd(request_rnd_16bit),
        .reset_seed(reset_seed_16bit),
        .en_rnd(1'b1),
        .rnd(rnd_share_16bit)
    );
    
    PRNG
    #(
        .PARAM_WIDTH(8),
        .LSFR_WIDTH(LSFR_WIDTH)
    )
    prng_8bit_inst
    (
        .clk(clk),
        .rst_n(rst_n),
        .seed_prng(load_seed),
        .request_rnd(request_rnd_8bit),
        .reset_seed(reset_seed_8bit),
        .en_rnd(1'b1),
        .rnd(rnd_share_8bit)
    );
    
    

endmodule : PRNG_engine_2SHARE

`default_nettype wire
