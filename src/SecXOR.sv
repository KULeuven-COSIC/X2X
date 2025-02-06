
module SecXOR
#(
    parameter N_SHARES = 3, // protection order + 1
    parameter PARAM_WIDTH = 32 // # bits / data word
)
(
    // DATA
    input logic [PARAM_WIDTH - 1:0] a [N_SHARES - 1:0],
    input logic [PARAM_WIDTH - 1:0] b [N_SHARES - 1:0],
    
    // OUTPUT
    output logic [PARAM_WIDTH - 1:0] c [N_SHARES - 1:0]
);
    
	// INTERNAL SIGNAL DECLARATIONS
    logic [PARAM_WIDTH - 1:0] XOR_result [N_SHARES - 1:0]; // a XOR b

    always_comb
    begin
        for (int i = 0; i < N_SHARES; i++)
        begin
            XOR_result[i] = a[i] ^ b[i];
        end
    end
    
    assign c = XOR_result;
    
endmodule
