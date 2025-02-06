//inspired by Masked Accelerators and Instruction Set Extensions for Post-Quantum Cryptography
//(https://tches.iacr.org/index.php/TCHES/article/view/9303)

module SecAnd_NEG_EDGE
#(
    parameter N_SHARES = 3, // protection order + 1
    parameter WIDTH = 32, // # bits / data word
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
    input logic [WIDTH - 1 : 0] fresh_rnd [(N_SHARES * (N_SHARES - 1) / 2) - 1 : 0],
    
    // DATA
    input logic [WIDTH - 1:0] a [N_SHARES - 1:0],
    input logic [WIDTH - 1:0] b [N_SHARES - 1:0],
    
    // OUTPUT
    output logic [WIDTH - 1:0] c [N_SHARES - 1:0]
);

    // INTERNAL SIGNAL DECLARATIONS
    logic [WIDTH - 1:0] and_res [N_SHARES * N_SHARES - 1:0];
    logic [WIDTH - 1:0] rnd_res [N_SHARES * N_SHARES - 1:0];
    logic [WIDTH - 1:0] reg_res [N_SHARES * N_SHARES - 1:0];
    logic [WIDTH - 1:0] xor_res [N_SHARES - 1:0];

    // STAGE 1: CALCULATION (AND operation) 
    always_comb
    begin
        for (int i=0; i<N_SHARES; i++) begin
            for (int j=0; j<N_SHARES; j++) begin
                and_res[N_SHARES*i + j] = a[i] & b[j];
            end
        end
    end

    // STAGE 2A: RESHARING (ADD RND to cross domain terms)
    always_comb
    begin
        for (int i=0; i<N_SHARES; i++) begin
            for (int j=0; j<N_SHARES; j++) begin
                unique if (i == j) 
                    rnd_res[N_SHARES*i + j] = and_res[N_SHARES*i + j];
                else if (i > j)
                    rnd_res[N_SHARES*i + j] = and_res[N_SHARES*i +j] ^ fresh_rnd[j+i*(i-1)/2];
                else
                    rnd_res[N_SHARES*i + j] = and_res[N_SHARES*i +j] ^ fresh_rnd[i+j*(j-1)/2];
            end
        end
    end

    // STAGE 2B: RESHARING (Register ALL terms)
    genvar i,j;
    generate
        for (i=0; i<N_SHARES; i++) begin
            for (j=0; j<N_SHARES; j++) begin
                (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE #(.PARAM_WIDTH(WIDTH)) D_reg_inst(.clk(clk), .rst_n(rst_n), .en(start), .d(rnd_res[N_SHARES*i +j]), .q(reg_res[N_SHARES*i + j]));
            end
        end
    endgenerate

    // STAGE 3: INTEGRATION (XOR shares in each domain)
    // If PIPELINE == 0, registered inner-domain terms will be unused and removed during synthesis
    always_comb
    begin
        xor_res = '{default:'0};
        for (int i=0; i<N_SHARES; i++) begin
            for (int j=0; j<N_SHARES; j++) begin
                unique if (PIPELINE)    xor_res[i] ^= reg_res[N_SHARES*i + j];  // Sum up all register values
                else if (i == j)        xor_res[i] ^= rnd_res[N_SHARES*i + j];  // Sum up unregistered inner-domain terms
                else                    xor_res[i] ^= reg_res[N_SHARES*i + j];  // Sum up registered cross-domain terms
            end
        end
    end

    
    (* keep_hierarchy = "TRUE" *) D_reg_NEG_EDGE #(.PARAM_WIDTH(1)) D_reg_done_inst(.clk(clk), .rst_n(rst_n), .en(1'b1), .d(start), .q(done));
   
    assign c = xor_res;
	
endmodule
