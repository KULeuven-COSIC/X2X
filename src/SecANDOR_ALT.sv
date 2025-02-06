
module SecANDOR_ALT
#(
    parameter N_SHARES = 3, // protection order + 1
    parameter PARAM_WIDTH = 32, // # bits / data word
    parameter PIPELINE = 0 // 0 = no_pipeline, 1 = pipeline 
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // CONTROL
    input logic start,
    output logic done,
    
    // RND
    input logic [PARAM_WIDTH - 1 : 0] fresh_rnd [2 * (N_SHARES * (N_SHARES - 1) / 2) - 1 : 0],
    
    // DATA
    input logic [PARAM_WIDTH - 1:0] a [N_SHARES - 1:0],
    input logic [PARAM_WIDTH - 1:0] b [N_SHARES - 1:0],
    
    // OUTPUT
    output logic [PARAM_WIDTH - 1:0] c_and [N_SHARES - 1:0],
    output logic [PARAM_WIDTH - 1:0] c_or [N_SHARES - 1:0]
);
    
    // INTERNAL SIGNAL DECLARATIONS
    logic done2;
	
	// OR
	(* keep_hierarchy = "TRUE" *) SecOR_ALT    
    #(
        .N_SHARES(N_SHARES),
        .PARAM_WIDTH(PARAM_WIDTH),
        .PIPELINE(1)
    ) 
    SecOR_inst
    (
        .clk(clk), 
        .rst_n(rst_n), 
        .start(start),
        .done(done2),
        .fresh_rnd(fresh_rnd[(N_SHARES * (N_SHARES - 1) / 2) - 1 : 0]), 
        .a(a),
        .b(b),
        .c(c_or)
    );
    
	// AND
    (* keep_hierarchy = "TRUE" *) SecAnd
    #(
        .N_SHARES(N_SHARES),
        .WIDTH(PARAM_WIDTH),
        .PIPELINE(1)
    ) 
    SecAND_inst
    (
        .clk(clk), 
        .rst_n(rst_n), 
        .start(start),
        .done(done),
        .a(a), 
        .b(b),
        .fresh_rnd(fresh_rnd[2 * (N_SHARES * (N_SHARES - 1) / 2) - 1 : (N_SHARES * (N_SHARES - 1) / 2)]),
        .c(c_and)
    );
    
endmodule
