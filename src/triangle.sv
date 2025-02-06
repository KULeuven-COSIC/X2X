
module triangle 
#(
    parameter N_SHARES = 2, // protection order + 1
    parameter PARAM_WIDTH = 16 // # bits / data word 
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // CONTROL
    input logic start,
    output logic done_combined,
    
    // RND
    input logic [PARAM_WIDTH - 1 : 0] fresh_rnd [2 * (N_SHARES * (N_SHARES - 1) / 2) - 1 : 0],
    
    // DATA
    input logic [PARAM_WIDTH - 1 : 0] a [N_SHARES - 1:0], 
    input logic [PARAM_WIDTH - 1 : 0] b [N_SHARES - 1:0],
    
    // OUTPUT
    output logic [PARAM_WIDTH - 1 : 0] p [N_SHARES - 1:0],
    output logic [PARAM_WIDTH - 1 : 0] g [N_SHARES - 1:0]
);
	
	//p <- a OR b
	//g <- a AND b
	(* keep_hierarchy = "TRUE" *) SecANDOR_ALT    // HALF CYCLE
	#(
	   .N_SHARES(N_SHARES),
	   .PARAM_WIDTH(PARAM_WIDTH),
	   .PIPELINE(1)
	)
	SecAndOr_inst
	(
	   .clk(clk), 
       .rst_n(rst_n), 
       .start(start),
       .done(done_combined),
       .a(a), 
       .b(b),
       .fresh_rnd(fresh_rnd),
       .c_and(g),
       .c_or(p)
	);
	
endmodule
