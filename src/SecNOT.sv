
module SecNOT
#(
    parameter N_SHARES = 3, // protection order + 1
    parameter PARAM_WIDTH = 32 // # bits / data word
)
(
    // DATA
    input logic [PARAM_WIDTH - 1:0] in [N_SHARES - 1:0],
    
    // OUTPUT
    output logic [PARAM_WIDTH - 1:0] out [N_SHARES - 1:0]
);

    assign out[0] = ~ in[0]; 
    
    genvar idx;
    generate
        for (idx = 1; idx < N_SHARES; idx++)
        begin
            assign out[idx] = in[idx];
        end
    endgenerate
    
endmodule
