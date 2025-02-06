
module PRNG_engine_STREAM
#(
    parameter PARAM_WIDTH = 13,
    parameter LSFR_WIDTH = 32, 
    parameter KYBER_Q = 3329,
    parameter N_SHARES = 2,
    parameter N_STAGES = 4,
   
    parameter RND_SHARES = 2 * (N_SHARES - 1) + 2 * N_SHARES + 4 * (N_SHARES * (N_SHARES - 1) / 2),
    parameter RND_SHARES_8bit = 2 * N_STAGES * 3 *(N_SHARES * (N_SHARES - 1) / 2),
    
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
    input logic load_seed,
    input logic dual_mode,
    input logic update_rnd, // start to fill RND array
    output logic prng_done, // done: array filled with required RND shares
    
    // DATA
    input logic  [SEED_WIDTH - 1 : 0]   seed_in,
    output logic [8 - 1 : 0]            rnd_out_8bit    [RND_SHARES_8bit - 1 : 0],
    output logic [PARAM_WIDTH - 1 : 0]  rnd_out         [RND_SHARES - 1 : 0] // should be in reg internally, connected via wire to crypto core, where all shares except used in first cycle are registered
);
    
    generate 
    if (N_SHARES == 2)
    begin
        PRNG_engine_2SHARE
        #(
            .PARAM_WIDTH(PARAM_WIDTH),
            .LSFR_WIDTH(LSFR_WIDTH),
            .SEED_WIDTH(SEED_WIDTH),
            .N_SHARES(N_SHARES),
            .RND_SHARES(RND_SHARES),
            .RND_SHARES_8bit(RND_SHARES_8bit)
        )
        PRNG_2SHARE_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            .mod_type(mod_type),
            .conversion_type(conversion_type),
            .dual_mode(dual_mode),
            .load_seed(load_seed),
            .update_rnd(update_rnd),
            .prng_done(prng_done),
            .seed_in(seed_in),
            .rnd_out_8bit(rnd_out_8bit),
            .rnd_out(rnd_out)
        );
    end
    else if (N_SHARES == 3)
    begin
        PRNG_engine_3SHARE
        #(
            .PARAM_WIDTH(PARAM_WIDTH),
            .LSFR_WIDTH(LSFR_WIDTH),
            .SEED_WIDTH(SEED_WIDTH),
            .N_SHARES(N_SHARES),
            .RND_SHARES(RND_SHARES),
            .RND_SHARES_8bit(RND_SHARES_8bit)
        )
        PRNG_3SHARE_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            .mod_type(mod_type),
            .conversion_type(conversion_type),
            .dual_mode(dual_mode),
            .load_seed(load_seed),
            .update_rnd(update_rnd),
            .prng_done(prng_done),
            .seed_in(seed_in),
            .rnd_out_8bit(rnd_out_8bit),
            .rnd_out(rnd_out)
        );
    end
    else if (N_SHARES == 4)
    begin
        PRNG_engine_4SHARE
        #(
            .PARAM_WIDTH(PARAM_WIDTH),
            .LSFR_WIDTH(LSFR_WIDTH),
            .SEED_WIDTH(SEED_WIDTH),
            .N_SHARES(N_SHARES),
            .RND_SHARES(RND_SHARES),
            .RND_SHARES_8bit(RND_SHARES_8bit)
        )
        PRNG_4SHARE_inst
        (
            .clk(clk),
            .rst_n(rst_n),
            .mod_type(mod_type),
            .conversion_type(conversion_type),
            .dual_mode(dual_mode),
            .load_seed(load_seed),
            .update_rnd(update_rnd),
            .prng_done(prng_done),
            .seed_in(seed_in),
            .rnd_out_8bit(rnd_out_8bit),
            .rnd_out(rnd_out)
        );
    end
    
    endgenerate
    
    

endmodule : PRNG_engine_STREAM

`default_nettype wire
