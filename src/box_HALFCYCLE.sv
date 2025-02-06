
module box_HALFCYCLE 
#(
    parameter FINAL_BOX = 0,
    parameter HALFCYCLE = 0,
    parameter N_SHARES = 3, // protection order + 1
    parameter PARAM_WIDTH = 16 // # bits / data word 
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // CONTROL
    input logic start,
    output logic done,
    
    // RND
    input logic [PARAM_WIDTH - 1 : 0] fresh_rnd [3*(N_SHARES * (N_SHARES - 1) / 2) - 1 : 0], //3 SecAND
    
    // DATA
    input logic [PARAM_WIDTH - 1 : 0] pi [N_SHARES - 1:0], 
    input logic [PARAM_WIDTH - 1 : 0] gi [N_SHARES - 1:0],
    input logic [PARAM_WIDTH - 1 : 0] pj [N_SHARES - 1:0],
    input logic [PARAM_WIDTH - 1 : 0] gj [N_SHARES - 1:0], 
    
    // OUTPUT
    output logic [PARAM_WIDTH - 1 : 0] P [N_SHARES - 1:0], 
    output logic [PARAM_WIDTH - 1 : 0] G [N_SHARES - 1:0]
);

	// INTERNAL SIGNALS DECLARATION
	genvar idx;
	
	logic [PARAM_WIDTH - 1 : 0] P_temp [N_SHARES - 1:0];
	logic [PARAM_WIDTH - 1 : 0] P_reg  [N_SHARES - 1:0];
//	logic [PARAM_WIDTH - 1 : 0] G_out [N_SHARES - 1:0];
	logic [PARAM_WIDTH - 1 : 0] temp   [N_SHARES - 1:0];
	
	logic [PARAM_WIDTH - 1 : 0] gi_reg     [N_SHARES - 1:0];
	logic [PARAM_WIDTH - 1 : 0] g_rnd_reg  [(N_SHARES * (N_SHARES - 1) / 2) - 1:0];
	logic done1, done2;
	
	// LOGIC
	generate
	
	if (FINAL_BOX==0)
	begin
        //P <- pi AND pj 
        (* keep_hierarchy = "TRUE" *) SecAnd   
        #(
            .N_SHARES(N_SHARES),
            .WIDTH(PARAM_WIDTH),
            .PIPELINE(1)
        ) 
        and_1
        (
            .clk(clk), 
            .rst_n(rst_n), 
            .start(start),
            .done(done1),
            .fresh_rnd(fresh_rnd[(N_SHARES * (N_SHARES - 1) / 2) - 1 : 0]), 
            .a(pi), 
            .b(pj),
            .c(P_temp)
        );
        
        if (HALFCYCLE==1)
        begin
            assign P = P_temp;
        end
        else
        begin
            for (idx = 0; idx < N_SHARES; idx++)
            begin
                (* keep_hierarchy = "TRUE" *) D_reg 
                #(.PARAM_WIDTH(PARAM_WIDTH)) 
                D_reg_P
                (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(P_temp[idx]), .q(P_reg[idx]));
                
//                (* keep_hierarchy = "TRUE" *) D_reg 
//                #(.PARAM_WIDTH(PARAM_WIDTH)) 
//                D_reg_input_gi
//                (.clk(clk), .rst_n(rst_n), .en(start), .d(gi[idx]), .q(gi_reg[idx]));
            end
            assign P = P_reg;
//            for (idx = 0; idx < (N_SHARES * (N_SHARES - 1) / 2); idx++)
//            begin
//                (* keep_hierarchy = "TRUE" *) D_reg 
//                #(.PARAM_WIDTH(PARAM_WIDTH)) 
//                D_reg_g_rnd
//                (.clk(clk), .rst_n(rst_n), .en(start), .d(fresh_rnd[2*(N_SHARES * (N_SHARES - 1) / 2) + idx]), .q(g_rnd_reg[idx]));
//            end
        end
    end
    else
    begin
        for (idx = 0; idx < N_SHARES;idx++)
        begin
            assign P[idx]='0;
        end
    
    end
    
	if (HALFCYCLE==1)
	begin
        //temp <- pi AND gj
        (* keep_hierarchy = "TRUE" *) SecAnd_NEG_EDGE
        #(
            .N_SHARES(N_SHARES),
            .WIDTH(PARAM_WIDTH),
            .PIPELINE(1)
        ) 
        and_2
        (
            .clk(clk), 
            .rst_n(rst_n), 
            .start(start),
            .done(done2),
            .fresh_rnd(fresh_rnd[2*(N_SHARES * (N_SHARES - 1) / 2) - 1 : (N_SHARES * (N_SHARES - 1) / 2)]), 
            .a(pi), 
            .b(gj),
            .c(temp)
        );
        
        for (idx = 0; idx < N_SHARES; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_input_gi
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(gi[idx]), .q(gi_reg[idx]));
        end
        
        for (idx = 0; idx < (N_SHARES * (N_SHARES - 1) / 2); idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_g_rnd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd[2*(N_SHARES * (N_SHARES - 1) / 2) + idx]), .q(g_rnd_reg[idx]));
        end
          
        //G <- gi OR temp 
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
            .start(done2),
            .done(done),
//            .fresh_rnd(fresh_rnd[3*(N_SHARES * (N_SHARES - 1) / 2) - 1 : 2*(N_SHARES * (N_SHARES - 1) / 2)]), 
            .fresh_rnd(g_rnd_reg),
            .a(gi_reg), 
//            .a(gi),
            .b(temp),
            .c(G)
        );
//        assign G = done ? G_out : '{default: '0};
    end
    else
    begin
    
        for (idx = 0; idx < N_SHARES; idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_input_gi
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(gi[idx]), .q(gi_reg[idx]));
        end
        //temp <- pi AND gj
        (* keep_hierarchy = "TRUE" *) SecAnd
        #(
            .N_SHARES(N_SHARES),
            .WIDTH(PARAM_WIDTH),
            .PIPELINE(1)
        ) 
        and_2
        (
            .clk(clk), 
            .rst_n(rst_n), 
            .start(start),
            .done(done2),
            .fresh_rnd(fresh_rnd[2*(N_SHARES * (N_SHARES - 1) / 2) - 1 : (N_SHARES * (N_SHARES - 1) / 2)]), 
            .a(pi), 
            .b(gj),
            .c(temp)
        );
        for (idx = 0; idx < (N_SHARES * (N_SHARES - 1) / 2); idx++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_g_rnd
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd[2*(N_SHARES * (N_SHARES - 1) / 2) + idx]), .q(g_rnd_reg[idx]));
        end
          
        //G <- gi OR temp 
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
            .start(done2),
            .done(done),
            .fresh_rnd(g_rnd_reg[(N_SHARES * (N_SHARES - 1) / 2) - 1 : 0]), 
            .a(gi_reg), 
            .b(temp),
            .c(G)
        );
        
//        assign G = done ? G_out : '{default: '0};
    end
    
    
    endgenerate
	
endmodule
