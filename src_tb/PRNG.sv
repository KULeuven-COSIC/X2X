
// PARAM_WIDTH = # parallel instantiations -> 1bit per instance
// LSFR_WIDTH = # repetitions before states/output will repeat -> depends on use case -> increase if more samples needed for TVLA -> 32 default


module PRNG
#(
    parameter PARAM_WIDTH = 16, // # bits / data word 
    parameter LSFR_WIDTH = 16 // 2^16 DIFFERNT RANDOM VALUES, BEFORE REPEAT -> re-seed before!
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // CONTROL
    input logic seed_prng, // seed is applied
    input logic request_rnd, // feedback is performed
    input logic en_rnd, // (de)activate rnd generation -> turn off/on for side-channel evaluations
    input logic [LSFR_WIDTH - 1 : 0] reset_seed [PARAM_WIDTH - 1:0], // An LFSR cannot have an all 0 state, thus reset to non-zero value
    
    // DATA
    output logic [PARAM_WIDTH - 1:0] rnd
);

    // INTERNAL SIGNALS DECLARATION
    logic feedback [PARAM_WIDTH - 1:0];
	logic [LSFR_WIDTH - 1:0] lfsr [PARAM_WIDTH - 1:0];
    logic [LSFR_WIDTH - 1:0] lfsr_next [PARAM_WIDTH - 1:0];
	
	// LFSR parameters
	localparam integer N_CROSSES_32 = 4; // #crosses for 32 bit data word
    localparam integer N_CROSSES_16 = 4; // #crosses for 16 bit data word
    localparam integer N_CROSSES_8 = 4; // #crosses for 8 bit data word
    localparam integer CROSSOVER_INDEX_32 [0 : N_CROSSES_32 - 1] = {31, 30, 10, 0}; //32 22 2 1
    localparam integer CROSSOVER_INDEX_16 [0 : N_CROSSES_16 - 1] = {12, 3, 1, 0}; //16 15 13 4
    localparam integer CROSSOVER_INDEX_8 [0 : N_CROSSES_8 - 1] = {4, 3, 2, 0}; //8 6 5 4
	// .... can be extended for other data word lengths

    integer i, j, k;
    genvar l, m;
    
    //assign rnd = { << { lfsr[0] }}; 
    
    always_ff @ (posedge clk, negedge rst_n)
    begin
        if (rst_n == 1'b0) 
        begin
            for (i = 0; i < PARAM_WIDTH; i++)
            begin
                lfsr[i] <= '0;
            end
        end
        else if (seed_prng)
        begin
            for (i = 0; i < PARAM_WIDTH; i++)
            begin
                lfsr[i] <= reset_seed[i];
            end
        end
        else if ((request_rnd == 1'b1) && (seed_prng == 1'b0))
        begin
            for (j = 0; j < PARAM_WIDTH; j++)
            begin
                lfsr[j] <= lfsr_next[j]; // next state if rnd used, for next cycle
            end
        end
    end
    
    // EXTEND FOR OTHER DATA WORD LENGTHS
    if (LSFR_WIDTH == 16) 
    begin
        for (l = 0; l < PARAM_WIDTH; l++)
        begin
            assign feedback[l] = lfsr[l][CROSSOVER_INDEX_16[0]] ^ lfsr[l][CROSSOVER_INDEX_16[1]] ^ lfsr[l][CROSSOVER_INDEX_16[2]] ^ lfsr[l][CROSSOVER_INDEX_16[3]];
            assign lfsr_next[l] = {feedback[l], lfsr[l][LSFR_WIDTH - 1:1]};
            assign rnd[l] = (en_rnd == 1'b1) ? lfsr[l][0] : '0;
        end
    end
    else if (LSFR_WIDTH == 8)
    begin
        for (l = 0; l < PARAM_WIDTH; l++)
        begin
            assign feedback[l] = lfsr[l][CROSSOVER_INDEX_8[0]] ^ lfsr[l][CROSSOVER_INDEX_8[1]] ^ lfsr[l][CROSSOVER_INDEX_8[2]] ^ lfsr[l][CROSSOVER_INDEX_8[3]];
            assign lfsr_next[l] = {feedback[l], lfsr[l][LSFR_WIDTH - 1:1]};
            assign rnd[l] = (en_rnd == 1'b1) ? lfsr[l][0] : '0;
        end
    end
    else if (LSFR_WIDTH == 32)
    begin
        for (l = 0; l < PARAM_WIDTH; l++)
        begin
            assign feedback[l] = lfsr[l][CROSSOVER_INDEX_32[0]] ^ lfsr[l][CROSSOVER_INDEX_32[1]] ^ lfsr[l][CROSSOVER_INDEX_32[2]] ^ lfsr[l][CROSSOVER_INDEX_32[3]];
            assign lfsr_next[l] = {feedback[l], lfsr[l][LSFR_WIDTH - 1:1]};
            assign rnd[l] = (en_rnd == 1'b1) ? lfsr[l][0] : '0;
        end
    end
    else
    begin
        for (m = 0; m < PARAM_WIDTH; m++)
        begin
            assign feedback[m] = 0;
            assign lfsr_next[m] = {feedback[m], lfsr[m][LSFR_WIDTH - 1:1]};
            assign rnd[l] = (en_rnd == 1'b1) ? lfsr[l][0] : '0;
        end
    end
    
endmodule
