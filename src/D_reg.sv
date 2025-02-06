
module D_reg
#(
    parameter PARAM_WIDTH = 32 // # bits / data word
)
(
    // GENERAL
    input logic clk,
    input logic rst_n,
    
    // WRITE
    input logic en,
	
	// DATA
    input logic [PARAM_WIDTH-1:0] d,
    
    // OUTPUT
    output logic [PARAM_WIDTH-1:0] q
);
	
	// INTERNAL SIGNAL DECLARATIONS
	logic [PARAM_WIDTH-1:0] d_selected;
	
	always_comb
	begin : MUX
		if (en == 1'b1) 
		begin
			d_selected = d;
		end 
		else 
		begin
			d_selected = q ;
		end
	end
	
    always_ff @(posedge clk, negedge rst_n) 
    begin
        if (rst_n == 1'b0) 
        begin
            q <= '0;
        end 
        else 
        begin
            q <= d_selected;
        end
    end

endmodule
