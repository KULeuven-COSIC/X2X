
module fullXOR
#(
    parameter N_SHARES = 3, // protection order + 1
    parameter PARAM_WIDTH = 32 // # bits / data word
)
(
    
    // DATA
    input logic [PARAM_WIDTH - 1 : 0] full [N_SHARES - 1 : 0],
    
    // OUTPUT
    output logic [PARAM_WIDTH - 1 : 0] single
);
    
	// INTERNAL SIGNAL DECLARATIONS
    logic [PARAM_WIDTH - 1:0] XOR_result;

    always_comb
    begin
        XOR_result = '0;
        for (int i = 0; i < N_SHARES; i++)
        begin
            XOR_result ^= full[i];
        end
    end
    
    assign single = XOR_result;
    
endmodule
