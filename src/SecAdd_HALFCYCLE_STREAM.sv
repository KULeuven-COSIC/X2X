//  inspired by https://github.com/sarthak7gupta/VerilogAdder

module SecAdd_HALFCYCLE_STREAM
#(
    parameter HALFCYCLE = 0,
    parameter N_STAGES = 4,
    parameter N_SHARES = 2, // protection order + 1
    parameter PARAM_WIDTH = 16, // # bits / data word
    
    parameter RND_TRIANGLE_SHARES = 2 * (N_SHARES * (N_SHARES - 1) / 2),
    parameter RND_BOX_SHARES = (N_STAGES - 1) * 3 *(N_SHARES * (N_SHARES - 1) / 2) + 2 *(N_SHARES * (N_SHARES - 1) / 2)
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // CONTROL
    input logic start,
    output logic done,
    
    // RND
    input logic [PARAM_WIDTH - 1 : 0]   fresh_rnd_triangle  [RND_TRIANGLE_SHARES - 1 : 0],
    input logic [8 - 1 : 0]             fresh_rnd_box       [RND_BOX_SHARES - 1 : 0],
    
    // DATA
    input logic [PARAM_WIDTH - 1 : 0] a [N_SHARES - 1:0], 
    input logic [PARAM_WIDTH - 1 : 0] b [N_SHARES - 1:0], 
    
    // OUTPUT 
    output logic [PARAM_WIDTH - 1 : 0] S [N_SHARES - 1:0]
);

    /////////////////////////////////
	// INTERNAL SIGNAL DECLARATION //
	/////////////////////////////////
	
	genvar idx, idy;
	localparam RND_BOX_LAYER_SHARES = 3 * (N_SHARES * (N_SHARES - 1) / 2);
	localparam RND_BOX_LAYER_FINAL_SHARES = 2 *(N_SHARES * (N_SHARES - 1) / 2);
	localparam N_CYCLES = (HALFCYCLE==1) ? N_STAGES - 1 : (N_STAGES * 2) - 1;
	localparam N_CYCLES_BOX = (HALFCYCLE==1) ? 1 : 2;
	
	// TRIANGLE
	logic done_triangle;
	logic [PARAM_WIDTH - 1 : 0]    output_p_triangle   [N_SHARES - 1 : 0]; // propagation signal
	logic [PARAM_WIDTH - 1 : 0]    output_g_triangle   [N_SHARES - 1 : 0]; // generation signal
	
	logic [PARAM_WIDTH - 1 : 0]    ab_triangle         [N_SHARES - 1 : 0];
//	logic [PARAM_WIDTH - 1 : 0]    a_triangle          [N_SHARES - 1 : 0];
//	logic [PARAM_WIDTH - 1 : 0]    b_triangle          [N_SHARES - 1 : 0];
	logic [PARAM_WIDTH - 1 : 0]    ab_reg_triangle     [N_SHARES - 1 : 0]; // registered input a XOR b 
	
	
	// BOX
	logic              start_done_box              [N_STAGES : 0];
	
	logic [8 - 1 : 0]  fresh_rnd_box_reg           [RND_BOX_SHARES - 1 : 0]; 
	logic [8 - 1 : 0]  fresh_rnd_box0_reg          [N_CYCLES_BOX : 0][RND_BOX_SHARES - RND_BOX_LAYER_SHARES - 1 : 0];
	logic [8 - 1 : 0]  fresh_rnd_box1_reg          [N_CYCLES_BOX : 0][RND_BOX_SHARES - 2 * RND_BOX_LAYER_SHARES - 1 : 0];
	logic [8 - 1 : 0]  fresh_rnd_box2_reg          [N_CYCLES_BOX : 0][RND_BOX_LAYER_FINAL_SHARES - 1 : 0];
	
    logic [8 - 1 : 0]   box_pi              [N_STAGES - 1 : 0][N_SHARES - 1 : 0];
    logic [8 - 1 : 0]   box_pj              [N_STAGES - 1 : 0][N_SHARES - 1 : 0];
    logic [8 - 1 : 0]   box_gi              [N_STAGES - 1 : 0][N_SHARES - 1 : 0];
    logic [8 - 1 : 0]   box_gj              [N_STAGES - 1 : 0][N_SHARES - 1 : 0];
    logic [8 - 1 : 0]   box_P               [N_STAGES - 1 : 0][N_SHARES - 1 : 0];
    logic [8 - 1 : 0]   box_G               [N_STAGES - 1 : 0][N_SHARES - 1 : 0];
	logic [8 - 1 : 0]   fresh_rnd_box_layer [N_STAGES - 1 : 0][RND_BOX_LAYER_SHARES - 1 : 0];
	
    logic [3 - 1 : 0]   p_reg0              [N_CYCLES_BOX : 0][N_SHARES - 1 : 0]; // 1,5,9
	logic [2 - 1 : 0]   p_reg1              [N_CYCLES_BOX * 2 : 0][N_SHARES - 1 : 0]; // 3,11 
	logic [1 - 1 : 0]   p_reg2              [N_CYCLES_BOX * 3 : 0][N_SHARES - 1 : 0]; // 7
	logic [3 - 1 : 0]   g_reg0              [N_CYCLES_BOX : 0][N_SHARES - 1 : 0]; // 
	logic [2 - 1 : 0]   g_reg1              [N_CYCLES_BOX * 2 : 0][N_SHARES - 1 : 0]; // 
	logic [1 - 1 : 0]   g_reg2              [N_CYCLES_BOX * 3 : 0][N_SHARES - 1 : 0]; //
	
    logic [2 - 1 : 0]   box_P1_result0      [N_CYCLES_BOX : 0][N_SHARES - 1 : 0]; // 2, 6
    logic [1 - 1 : 0]   box_P1_result1      [N_CYCLES_BOX * 2 : 0][N_SHARES - 1 : 0]; // 4
    logic [2 - 1 : 0]   box_G1_result0      [N_CYCLES_BOX : 0][N_SHARES - 1 : 0]; // 2,6
    logic [1 - 1 : 0]   box_G1_result1      [N_CYCLES_BOX * 2 : 0][N_SHARES - 1 : 0]; // 4
    logic [1 - 1 : 0]   box_G1_result2      [N_CYCLES_BOX * 3 : 0][N_SHARES - 1 : 0]; // 0
    
    logic [2 - 1 : 0]   box_P2_result0      [N_CYCLES_BOX : 0][N_SHARES - 1 : 0]; // 4,5
    logic [2 - 1 : 0]   box_G2_result0      [N_CYCLES_BOX : 0][N_SHARES - 1 : 0]; // 4,5
    logic [2 - 1 : 0]   box_G2_result1      [N_CYCLES_BOX * 2 : 0][N_SHARES - 1 : 0]; // 0,1
    
    logic [4 - 1 : 0]   box_G3_result0      [N_CYCLES_BOX : 0][N_SHARES - 1 : 0]; // 0,1,2,3
	
	logic [PARAM_WIDTH - 1 : 0]    ab_reg_box   [N_CYCLES : 0][N_SHARES - 1 : 0];  
	
    logic [PARAM_WIDTH - 1 : 0]    final_gi     [N_SHARES - 1 : 0];
	
	/////////////
	// CONTROL //
	/////////////
	
	// BOX
	assign start_done_box[0] = done_triangle;
	assign done = start_done_box[N_STAGES];
	
//	assign a_triangle = start ? a : '{default: '0};
//	assign b_triangle = start ? b : '{default: '0};
	
	assign fresh_rnd_box_layer[0] = fresh_rnd_box_reg[RND_BOX_LAYER_SHARES - 1 : 0];
	assign fresh_rnd_box0_reg[0]  = fresh_rnd_box_reg[RND_BOX_SHARES - 1 : RND_BOX_LAYER_SHARES];
	assign fresh_rnd_box_layer[1] = fresh_rnd_box0_reg[N_CYCLES_BOX][RND_BOX_LAYER_SHARES - 1 : 0];
	assign fresh_rnd_box1_reg[0]  = fresh_rnd_box0_reg[N_CYCLES_BOX][RND_BOX_SHARES - RND_BOX_LAYER_SHARES - 1 : RND_BOX_LAYER_SHARES];
	assign fresh_rnd_box_layer[2] = fresh_rnd_box1_reg[N_CYCLES_BOX][RND_BOX_LAYER_SHARES - 1 : 0];
	assign fresh_rnd_box2_reg[0]  = fresh_rnd_box1_reg[N_CYCLES_BOX][RND_BOX_SHARES - 2 * RND_BOX_LAYER_SHARES - 1 : RND_BOX_LAYER_SHARES]; 
	assign fresh_rnd_box_layer[3][RND_BOX_LAYER_SHARES - 1 : (N_SHARES * (N_SHARES - 1) / 2)] = fresh_rnd_box2_reg[N_CYCLES_BOX][RND_BOX_LAYER_FINAL_SHARES - 1 : 0];
	assign fresh_rnd_box_layer[3][(N_SHARES * (N_SHARES - 1) / 2) - 1 : 0] = '{default: '0};
	
	always_comb
	begin
        for (int j = 0; j < N_SHARES; j=j+1)
        begin
            p_reg0[N_CYCLES_BOX][j] = {output_p_triangle[j][9],  output_p_triangle[j][5],  output_p_triangle[j][1]}; 
            p_reg1[N_CYCLES_BOX * 2][j] = {output_p_triangle[j][11], output_p_triangle[j][3]};
            p_reg2[N_CYCLES_BOX * 3][j] = {output_p_triangle[j][7]};
            
            g_reg0[N_CYCLES_BOX][j] = {output_g_triangle[j][9],  output_g_triangle[j][5],  output_g_triangle[j][1]};
            g_reg1[N_CYCLES_BOX * 2][j] = {output_g_triangle[j][11], output_g_triangle[j][3]};
            g_reg2[N_CYCLES_BOX * 3][j] = {output_g_triangle[j][7]};
            
            // BOX 0 
            box_pi[0][j] = {1'b0, output_p_triangle[j][12],   output_p_triangle[j][10],   output_p_triangle[j][8],    output_p_triangle[j][6],    output_p_triangle[j][4],    output_p_triangle[j][2],    output_p_triangle[j][0]};
            box_gi[0][j] = {1'b0, output_g_triangle[j][12],   output_g_triangle[j][10],   output_g_triangle[j][8],    output_g_triangle[j][6],    output_g_triangle[j][4],    output_g_triangle[j][2],    output_g_triangle[j][0]};
            box_pj[0][j] = {1'b0, output_p_triangle[j][11],   output_p_triangle[j][9],    output_p_triangle[j][7],    output_p_triangle[j][5],    output_p_triangle[j][3],    output_p_triangle[j][1],    1'b0};
            box_gj[0][j] = {1'b0, output_g_triangle[j][11],   output_g_triangle[j][9],    output_g_triangle[j][7],    output_g_triangle[j][5],    output_g_triangle[j][3],    output_g_triangle[j][1],    1'b0};
            
            box_P1_result0[N_CYCLES_BOX][j] = {box_P[0][j][6], box_P[0][j][2]};
            box_P1_result1[N_CYCLES_BOX * 2][j] = {box_P[0][j][4]};
            
            box_G1_result0[N_CYCLES_BOX][j] = {box_G[0][j][6], box_G[0][j][2]};
            box_G1_result1[N_CYCLES_BOX * 2][j] = {box_G[0][j][4]};
            box_G1_result2[N_CYCLES_BOX * 3][j] = {box_G[0][j][0]};
            
            // BOX 1
            box_pi[1][j] = {box_P[0][j][7], 1'b0,           box_P[0][j][5],   p_reg0[0][j][2],   box_P[0][j][3],   p_reg0[0][j][1],   box_P[0][j][1],   p_reg0[0][j][0]};
            box_gi[1][j] = {box_G[0][j][7], 1'b0,           box_G[0][j][5],   g_reg0[0][j][2],   box_G[0][j][3],   g_reg0[0][j][1],   box_G[0][j][1],   g_reg0[0][j][0]};
            box_pj[1][j] = {box_P[0][j][6], box_P[0][j][6], box_P[0][j][4],   box_P[0][j][4],   box_P[0][j][2],   box_P[0][j][2],   box_P[0][j][0],   box_P[0][j][0]};
            box_gj[1][j] = {box_G[0][j][6], box_G[0][j][6], box_G[0][j][4],   box_G[0][j][4],   box_G[0][j][2],   box_G[0][j][2],   box_G[0][j][0],   box_G[0][j][0]};
            
            box_P2_result0[N_CYCLES_BOX][j] = {box_P[1][j][5], box_P[1][j][4]};
            box_G2_result0[N_CYCLES_BOX][j] = {box_G[1][j][5], box_G[1][j][4]};
            box_G2_result1[N_CYCLES_BOX * 2][j] = {box_G[1][j][1], box_G[1][j][0]};

            // BOX 2
            box_pi[2][j] = {box_P[1][j][7], box_P[1][j][6],   box_P1_result0[0][j][1],  p_reg1[0][j][1],    box_P[1][j][3],   box_P[1][j][2],   box_P1_result0[0][j][0],p_reg1[0][j][0]};
            box_gi[2][j] = {box_G[1][j][7], box_G[1][j][6],   box_G1_result0[0][j][1],  g_reg1[0][j][1],    box_G[1][j][3],   box_G[1][j][2],   box_G1_result0[0][j][0],g_reg1[0][j][0]};
            box_pj[2][j] = {box_P[1][j][5], box_P[1][j][5],   box_P[1][j][5],       box_P[1][j][5],     box_P[1][j][1],   box_P[1][j][1],   box_P[1][j][1],     box_P[1][j][1]};
            box_gj[2][j] = {box_G[1][j][5], box_G[1][j][5],   box_G[1][j][5],       box_G[1][j][5],     box_G[1][j][1],   box_G[1][j][1],   box_G[1][j][1],     box_G[1][j][1]};
           
            box_G3_result0[N_CYCLES_BOX][j] = box_G[2][j][3:0];
           
            // BOX 3
            box_pi[3][j] = {box_P[2][j][7], box_P[2][j][6],   box_P[2][j][5],   box_P[2][j][4],   box_P2_result0[0][j][1],  box_P2_result0[0][j][0],box_P1_result1[0][j][0],p_reg2[0][j][0]};
            box_gi[3][j] = {box_G[2][j][7], box_G[2][j][6],   box_G[2][j][5],   box_G[2][j][4],   box_G2_result0[0][j][1],  box_G2_result0[0][j][0],box_G1_result1[0][j][0],g_reg2[0][j][0]};
//            box_pj[3][j] = {box_P[2][j][3], box_P[2][j][3],   box_P[2][j][3],   box_P[2][j][3],   box_P[2][j][3],       box_P[2][j][3],     box_P[2][j][3],     box_P[2][j][3]};
            box_pj[3][j] = '0;
            box_gj[3][j] = {box_G[2][j][3], box_G[2][j][3],   box_G[2][j][3],   box_G[2][j][3],   box_G[2][j][3],       box_G[2][j][3],     box_G[2][j][3],     box_G[2][j][3]};
            
            final_gi[j] = {box_G[3][j][4],box_G[3][j][3],box_G[3][j][2],box_G[3][j][1],box_G[3][j][0],box_G3_result0[0][j][3],box_G3_result0[0][j][2],box_G3_result0[0][j][1],box_G3_result0[0][j][0],box_G2_result1[0][j][1],box_G2_result1[0][j][0],box_G1_result2[0][j][0],   1'b0};
        end
	end
	
	///////////
	// LOGIC //
	///////////
	
	// TRIANGLE
	(* keep_hierarchy = "TRUE" *) triangle
    #(
        .N_SHARES       (N_SHARES           ),
        .PARAM_WIDTH    (PARAM_WIDTH        )
    )
    triangle_inst
    (
        .clk            (clk                ),
        .rst_n          (rst_n              ),
        .start          (start              ), 
        .done_combined  (done_triangle      ),
        .a              (a                  ),
        .b              (b                  ),
        .fresh_rnd      (fresh_rnd_triangle ),
        .p              (output_p_triangle  ),
        .g              (output_g_triangle  )
    );
    
    (* keep_hierarchy = "TRUE" *) SecXOR
    #(
        .N_SHARES   (N_SHARES   ),
        .PARAM_WIDTH(PARAM_WIDTH)
    )
    XOR_inst
    (
        .a(a            ),
        .b(b            ),
        .c(ab_triangle  )
    );
    
    // 3-XOR
     (* keep_hierarchy = "TRUE" *) SecXOR
     #(
         .N_SHARES   (N_SHARES   ),
         .PARAM_WIDTH(PARAM_WIDTH)
     )
     XOR_final_inst
     (
         .a(ab_reg_box[N_CYCLES] ),
         .b(final_gi             ),
         .c(S                    )
     );
    
    generate
    for (idx = 0; idx < N_SHARES; idx++)
    begin
        (* keep_hierarchy = "TRUE" *) D_reg 
        #(.PARAM_WIDTH(PARAM_WIDTH)) 
        D_reg_input_ab_triangle
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(ab_triangle[idx]), .q(ab_reg_triangle[idx]));
        
        (* keep_hierarchy = "TRUE" *) D_reg 
        #(.PARAM_WIDTH(PARAM_WIDTH)) 
        D_reg_input_ab_box0
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(ab_reg_triangle[idx]), .q(ab_reg_box[0][idx]));   
    end
    
    for (idx = 0; idx < RND_BOX_SHARES; idx++)
    begin
        (* keep_hierarchy = "TRUE" *) D_reg 
        #(.PARAM_WIDTH(8)) 
        D_reg_box_rnd
        (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_box[idx]), .q(fresh_rnd_box_reg[idx]));
    end
    
    // BOX 1-3
    for (idx = 0; idx < N_STAGES - 1; idx++)
    begin
        
        (* keep_hierarchy = "TRUE" *) box_HALFCYCLE
        #(
            .HALFCYCLE  (HALFCYCLE  ),
            .FINAL_BOX  (0          ),
            .N_SHARES   (N_SHARES   ),
            .PARAM_WIDTH(8          )
        )
        box13_inst
        (
            .clk        (clk                        ),
            .rst_n      (rst_n                      ),
            .start      (start_done_box[idx]        ),
            .done       (start_done_box[idx + 1]    ),
            .fresh_rnd  (fresh_rnd_box_layer[idx]   ), 
            .pi         (box_pi[idx]                ), 
            .pj         (box_pj[idx]                ), 
            .gi         (box_gi[idx]                ), 
            .gj         (box_gj[idx]                ), 
            .P          (box_P[idx]                 ), 
            .G          (box_G[idx]                 )  
        );
     end
    
    // BOX 4 
    for (idx = N_STAGES - 1; idx < N_STAGES; idx++)
    begin
        
        (* keep_hierarchy = "TRUE" *) box_HALFCYCLE
        #(
            .HALFCYCLE  (HALFCYCLE  ),
            .FINAL_BOX  (1          ),
            .N_SHARES   (N_SHARES   ),
            .PARAM_WIDTH(8          )
        )
        box4_inst
        (
            .clk        (clk                        ),
            .rst_n      (rst_n                      ),
            .start      (start_done_box[idx]        ),
            .done       (start_done_box[idx + 1]    ),
            .fresh_rnd  (fresh_rnd_box_layer[idx]   ), 
            .pi         (box_pi[idx]                ), 
            .pj         (box_pj[idx]                ), 
            .gi         (box_gi[idx]                ), 
            .gj         (box_gj[idx]                ), 
            .P          (box_P[idx]                 ), 
            .G          (box_G[idx]                 )  
        );
     end
     
     for (idx = 0; idx < N_CYCLES; idx++)
     begin
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(PARAM_WIDTH)) 
            D_reg_output_ab_box
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(ab_reg_box[idx][idy]), .q(ab_reg_box[idx + 1][idy]));
        end
     end
     
     for (idx = 0; idx < N_CYCLES_BOX; idx++)
     begin 
        for (idy = 0; idy < RND_BOX_SHARES - RND_BOX_LAYER_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_box0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_box0_reg[idx][idy]), .q(fresh_rnd_box0_reg[idx + 1][idy]));
        end
        
        for (idy = 0; idy < RND_BOX_SHARES - 2 * RND_BOX_LAYER_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_box1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_box1_reg[idx][idy]), .q(fresh_rnd_box1_reg[idx + 1][idy]));
        end
        
        for (idy = 0; idy < RND_BOX_LAYER_FINAL_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(8)) 
            D_reg_fresh_rnd_box2
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(fresh_rnd_box2_reg[idx][idy]), .q(fresh_rnd_box2_reg[idx + 1][idy]));
        end
     end
     
     for (idx = N_CYCLES_BOX; idx > 0; idx--)
     begin
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(3)) 
            D_reg_p0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(p_reg0[idx][idy]), .q(p_reg0[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(3)) 
            D_reg_g0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(g_reg0[idx][idy]), .q(g_reg0[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(2)) 
            D_reg_box_P1r0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_P1_result0[idx][idy]), .q(box_P1_result0[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(2)) 
            D_reg_box_G1r0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_G1_result0[idx][idy]), .q(box_G1_result0[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(2)) 
            D_reg_box_P2r0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_P2_result0[idx][idy]), .q(box_P2_result0[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(2)) 
            D_reg_box_G2r0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_G2_result0[idx][idy]), .q(box_G2_result0[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(4)) 
            D_reg_box_G3r0
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_G3_result0[idx][idy]), .q(box_G3_result0[idx - 1][idy]));
        end
     end
     
     for (idx = 2 * N_CYCLES_BOX; idx > 0; idx--)
     begin
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(2)) 
            D_reg_p1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(p_reg1[idx][idy]), .q(p_reg1[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(2)) 
            D_reg_g1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(g_reg1[idx][idy]), .q(g_reg1[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_box_P1r1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_P1_result1[idx][idy]), .q(box_P1_result1[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_box_G1r1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_G1_result1[idx][idy]), .q(box_G1_result1[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(2)) 
            D_reg_box_G2r1
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_G2_result1[idx][idy]), .q(box_G2_result1[idx - 1][idy]));
        end
     end
     
     for (idx = 3 * N_CYCLES_BOX; idx > 0; idx--)
     begin
        for (idy = 0; idy < N_SHARES; idy++)
        begin
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_p2
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(p_reg2[idx][idy]), .q(p_reg2[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_g2
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(g_reg2[idx][idy]), .q(g_reg2[idx - 1][idy]));
            
            (* keep_hierarchy = "TRUE" *) D_reg 
            #(.PARAM_WIDTH(1)) 
            D_reg_box_G1r2
            (.clk(clk), .rst_n(rst_n), .en(1'b1), .d(box_G1_result2[idx][idy]), .q(box_G1_result2[idx - 1][idy]));
        end
     end
     
     endgenerate
     
	
endmodule
	
