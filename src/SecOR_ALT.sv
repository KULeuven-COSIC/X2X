
// NOT A
//          AND     NOT
// NOT B

module SecOR_ALT
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
    input logic [PARAM_WIDTH - 1 : 0] fresh_rnd [(N_SHARES * (N_SHARES - 1) / 2) - 1 : 0],
    
    // DATA
    input logic [PARAM_WIDTH - 1:0] a [N_SHARES - 1:0],
    input logic [PARAM_WIDTH - 1:0] b [N_SHARES - 1:0],
    
    // OUTPUT
    output logic [PARAM_WIDTH - 1:0] c [N_SHARES - 1:0]
);
    
    // INTERNAL SIGNAL DECLARATIONS
    logic [PARAM_WIDTH - 1:0] NOT_a_result [N_SHARES - 1:0];
    logic [PARAM_WIDTH - 1:0] NOT_b_result [N_SHARES - 1:0];
    logic [PARAM_WIDTH - 1:0] AND_result [N_SHARES - 1:0];
	
	// NOT A
    (* keep_hierarchy = "TRUE" *) SecNOT
    #(
        .N_SHARES(N_SHARES),
        .PARAM_WIDTH(PARAM_WIDTH)
    ) 
    NOT_a_inst
    (
        .in(a), 
        .out(NOT_a_result)
    );
    
    // NOT B
    (* keep_hierarchy = "TRUE" *) SecNOT
    #(
        .N_SHARES(N_SHARES),
        .PARAM_WIDTH(PARAM_WIDTH)
    ) 
    NOT_b_inst
    (
        .in(b), 
        .out(NOT_b_result)
    );
    
	// 1st AND
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
        .fresh_rnd(fresh_rnd),
        .a(NOT_a_result), 
        .b(NOT_b_result),
        .c(AND_result)
    );
    
	//	NOT result
    (* keep_hierarchy = "TRUE" *) SecNOT
    #(
        .N_SHARES(N_SHARES),
        .PARAM_WIDTH(PARAM_WIDTH)
    ) 
    NOT_and_inst
    (
        .in(AND_result), 
        .out(c)
    );
    
endmodule
