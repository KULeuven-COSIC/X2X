

class ARITHMETIC_2SHARE_Corrected
#(
    parameter PARAM_WIDTH = 16,
    parameter N_SHARES = 2,
    parameter q = 3329
);

    rand logic signed [PARAM_WIDTH - 1 : 0] shared_data [N_SHARES - 1 : 0];

    constraint a_val
    {
       shared_data[0] inside {[0 : q - 1]};
    }
    constraint b_val
    {
       shared_data[1] inside {[-q : - 1]};
    }

endclass



class BOOLEAN_XSHARE
#(
    parameter PARAM_WIDTH = 16,
    parameter N_SHARES = 2,
    parameter q = 3329
);

    rand logic [PARAM_WIDTH - 1 : 0] shared_data [N_SHARES - 1 : 0];

    constraint a_val
    {
//       unshare(shared_data) inside {[0 : q - 1]};
        (shared_data[0] ^ shared_data[1] ) inside {[0 : q - 1]};
    }

    typedef logic [PARAM_WIDTH - 1 : 0] unshared;

    function unshared unshare (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES - 1 : 0]);
        unshare = x.xor();

        return unshare;
    endfunction

endclass

class SEED_PRNG_XSHARE
#(
    parameter NB_SEEDS = 3
);

    rand logic [128*NB_SEEDS - 1 : 0] seed;

endclass


module X2X_32b_HALF_STREAM_tb;

    /////////////////////////////////
	// INTERNAL SIGNAL DECLARATION //
	/////////////////////////////////

    ////// DISPLAY/SIMULATION SETTINGS //////
    localparam print_data = 1;
    localparam N_SIMULATIONS = 10;
    localparam DUAL_MODE = 0;       // 2 simulataneous mod power-of-two calculations
    localparam HALFCYCLE = 1;       // simulate halfcycle implementation
    localparam LAB_MODE = 1;        // 1 data operand calculates at a time
    /////////////////////////////////////////
    
    localparam log2_of_q = 12;
    localparam PARAM_WIDTH = 32;
    localparam BOX_WIDTH = 16;
    localparam LSFR_WIDTH = 32;
    localparam NB_SEEDS = 12;
    localparam N_STAGES = 5;
    localparam prime_q = 8380417; //3329; // Kyber Q
    localparam power_of_two_q = 4294967296; // 2**32
    localparam prime_twoc_q = 4286586879; //4294963967; 

    localparam N_SHARES_2SHARE = 2;
    
    localparam B2A_RND_SHARES_2SHARE = N_SHARES_2SHARE - 1;
    localparam EXPAND_SHARES_2SHARE = N_SHARES_2SHARE;
    localparam TRIANGLE_SHARES_2SHARE = 2 * (N_SHARES_2SHARE * (N_SHARES_2SHARE - 1) / 2);
    localparam BOX_SHARES_2SHARE = (N_STAGES - 1) * 3 * (N_SHARES_2SHARE * (N_SHARES_2SHARE - 1) / 2) + 2 * (N_SHARES_2SHARE * (N_SHARES_2SHARE - 1) / 2);
    
    localparam RND_SHARES_2SHARE = 2 * B2A_RND_SHARES_2SHARE + 2 * EXPAND_SHARES_2SHARE + 2 * TRIANGLE_SHARES_2SHARE;
    localparam RND_SHARES_2SHARE_BOX = 2 * BOX_SHARES_2SHARE;
   
    // MASK CONV
    logic [PARAM_WIDTH - 1 : 0] in_2SHARE   [2 - 1 : 0][N_SHARES_2SHARE - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] out_2SHARE  [2 - 1 : 0][N_SHARES_2SHARE - 1 : 0];
    logic valid_data_2SHARE, ready_data_2SHARE, valid_result_2SHARE, ready_result_2SHARE;

    logic conversion_mode;
    logic data_modq;
    logic dual_mode;
    
    logic [PARAM_WIDTH - 1 : 0] modulus_in;
    logic [PARAM_WIDTH - 1 : 0] modulus_twoc_in;
    
    // PRNG ENGINE
    logic seed_prng;
    logic request_rnd_2SHARE;
    logic prng_done_2SHARE;
    logic [NB_SEEDS * 128 - 1 : 0]  seed_2SHARE;
    logic [BOX_WIDTH - 1 : 0]       rnd_16bit_2SHARE [RND_SHARES_2SHARE_BOX - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0]     rnd_2SHARE      [RND_SHARES_2SHARE - 1 : 0];
    logic [BOX_WIDTH - 1 : 0]       rnd_16bit_2SHARE_reg [RND_SHARES_2SHARE_BOX - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0]     rnd_2SHARE_reg      [RND_SHARES_2SHARE - 1 : 0];


    logic clk = 0;
    always #0.5ns clk = ~clk;
    logic arst_n;
    initial
    begin
        #1ns;
        arst_n = 0;
        data_modq = 0;
        seed_prng = 0;
        dual_mode = (DUAL_MODE == 1) ? 1'b1 : 1'b0;
        request_rnd_2SHARE = 0;
        conversion_mode = 0;
        ready_result_2SHARE = 0;
        valid_data_2SHARE = 0;
        modulus_in = power_of_two_q;
        modulus_twoc_in = 32'd0;
        #1ns;
        @(posedge clk);
        #0.1ns;
        arst_n = 1;
    end

    // LOGIC INSTANCES

    SEED_PRNG_XSHARE
    #(
        .NB_SEEDS(NB_SEEDS)
    )
    SEED_ENGINE_2SHARE;

    X2X_32b_2SHARE_HALFCYCLE_STREAM
    #(
        .HALFCYCLE(HALFCYCLE),
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_2SHARE),
        .RND_SHARES(RND_SHARES_2SHARE),
        .RND_SHARES_BOX(RND_SHARES_2SHARE_BOX)
    )
    MaskConv_2SHARE_inst
    (
        .clk(clk),
        .rst_n(arst_n),
        .conversion_mode(conversion_mode),
        .data_type_mode(data_modq),
        .dual_mode(dual_mode),
        .modulus(modulus_in),
        .modulus_twoc(modulus_twoc_in),
        .valid_data(valid_data_2SHARE),
        .ready_data(ready_data_2SHARE),
        .original_data(in_2SHARE),
        .converted_data(out_2SHARE),
        .valid_result(valid_result_2SHARE),
        .ready_result(ready_result_2SHARE),
        .fresh_rnd_shares(rnd_2SHARE_reg),
        .fresh_rnd_shares_8bit(rnd_16bit_2SHARE_reg)
    );

    PRNG_engine_32b_2SHARE
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .LSFR_WIDTH(LSFR_WIDTH),
        .SEED_WIDTH(NB_SEEDS*128),
        .N_SHARES(N_SHARES_2SHARE),
        .RND_SHARES(RND_SHARES_2SHARE),
        .RND_SHARES_BOX(RND_SHARES_2SHARE_BOX)
    )
    PRNG_2SHARE_inst
    (
        .clk(clk),
        .rst_n(arst_n),
        .mod_type(data_modq),
        .conversion_type(conversion_mode),
        .dual_mode(dual_mode),
        .load_seed(seed_prng),
        .update_rnd(request_rnd_2SHARE),
        .prng_done(prng_done_2SHARE),
        .seed_in(seed_2SHARE),
        .rnd_out_16bit(rnd_16bit_2SHARE),
        .rnd_out(rnd_2SHARE)
    );

    ARITHMETIC_2SHARE_Corrected
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_2SHARE),
        .q(power_of_two_q)
    )
    A_2SHARES_POWEROFTWO_1, A_2SHARES_POWEROFTWO_2;

    ARITHMETIC_2SHARE_Corrected
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_2SHARE),
        .q(prime_q)
    )
    A_2SHARES_PRIME_1, A_2SHARES_PRIME_2;

    BOOLEAN_XSHARE
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_2SHARE),
        .q(power_of_two_q)
    )
    B_2SHARES_POWEROFTWO_1, B_2SHARES_POWEROFTWO_2;

    BOOLEAN_XSHARE
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_2SHARE),
        .q(prime_q)
    )
    B_2SHARES_PRIME_1, B_2SHARES_PRIME_2;


    typedef logic signed [PARAM_WIDTH + 2 - 1 : 0] unshared;

    function unshared unshare_2arithmetic  (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES_2SHARE - 1 : 0]);
        unshare_2arithmetic = x.sum();

        return unshare_2arithmetic;
    endfunction

    function unshared unshare_2arithmetic_signed  (input logic signed [PARAM_WIDTH - 1 : 0] x [N_SHARES_2SHARE - 1 : 0]);
        unshare_2arithmetic_signed = $signed(x.sum());

        return unshare_2arithmetic_signed;
    endfunction

    function unshared unshare_2Boolean (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES_2SHARE - 1 : 0]);
        unshare_2Boolean = x.xor();

        return unshare_2Boolean;
    endfunction
    
    

    initial
    begin

        $display("STARTING TESTBENCH -- %d ITERATIONS", N_SIMULATIONS);
       
        A_2SHARES_POWEROFTWO_1 = new();
        A_2SHARES_POWEROFTWO_2 = new();
        B_2SHARES_POWEROFTWO_1 = new();
        B_2SHARES_POWEROFTWO_2 = new();

        A_2SHARES_PRIME_1 = new();
        A_2SHARES_PRIME_2 = new();
        B_2SHARES_PRIME_1 = new();
        B_2SHARES_PRIME_2 = new();

        SEED_ENGINE_2SHARE = new();

        for(int j = 0; j < N_SIMULATIONS; j++)
        begin
        
            

            logic [PARAM_WIDTH - 1 : 0] long_out [2 - 1 : 0];

            @(posedge clk iff arst_n);
            $display("STARTING ITERATION %d", j);

            A_2SHARES_POWEROFTWO_1.randomize();
            A_2SHARES_POWEROFTWO_2.randomize();
            B_2SHARES_POWEROFTWO_1.randomize();
            B_2SHARES_POWEROFTWO_2.randomize();

            A_2SHARES_PRIME_1.randomize();
            A_2SHARES_PRIME_2.randomize();
            B_2SHARES_PRIME_1.randomize();
            B_2SHARES_PRIME_2.randomize();
            

            SEED_ENGINE_2SHARE.randomize();
            #0.5ns;

            @(posedge clk iff arst_n);

            seed_2SHARE = SEED_ENGINE_2SHARE.seed;
            
            
            #0.5ns;

            @(posedge clk iff arst_n);

            seed_prng = 1'b1;

            #0.5ns;
            @(posedge clk iff arst_n);
            seed_prng = 1'b0;

            #0.5ns;
            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b1;

            #0.5ns;
            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b0;


            

            ///////////////////////////////
            //////PHASE 1: 2 SHARES////////
            ///////////////////////////////

            $display("TEST 1 -- A2B: N_SHARES = %d, MOD Q = %d", N_SHARES_2SHARE, power_of_two_q);

            @(posedge clk iff arst_n);
            //seed_prng = 1'b0;
            for (int k = 0; k < N_SHARES_2SHARE; k++)
            begin
                in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]);
                in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]) : '0;
            end
            if (print_data == 1)
            begin
                $display("INPUT 1: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
            end
            
            
            wait (prng_done_2SHARE);
            rnd_2SHARE_reg <= rnd_2SHARE;
            rnd_16bit_2SHARE_reg <= rnd_16bit_2SHARE;

            ///////////1st DATA
            valid_data_2SHARE <= 1'b1;
            ready_result_2SHARE <= 1'b1;


            if (LAB_MODE == 0)
            begin
                /////////2nd DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 2: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
        
                /////////3rd DATA
                @(posedge clk iff arst_n);
                
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 3: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
        
                ////////4th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 4: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
                
                /////////5th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 5: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
                #1ns;
                //@(posedge clk iff arst_n);
            end
            else
            begin
                #1ns;
                valid_data_2SHARE <= 1'b0;
                wait(valid_result_2SHARE)
                valid_data_2SHARE <= 1'b1;
            end


            /////////6th DATA + 1st OUT
            for (int k = 0; k < N_SHARES_2SHARE; k++)
            begin
                in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]);
                in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]) : '0;
            end
            if (print_data == 1)
            begin
                $display("INPUT 6: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
            end
            #0.5ns;

            @(posedge clk iff arst_n);
            long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
            long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
            if (print_data == 1)
            begin
                $display("OUTPUT 1: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
            end
            assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 1a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
            if (dual_mode)
            begin
                assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 1b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
            end
            
            if (LAB_MODE == 0)
            begin
                /////////7th DATA + 2nd OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 7: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 2: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 2a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 2b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
                
                ////////8th DATA + 3rd OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 8: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 3: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 3a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 3b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
    
                /////////9th DATA + 4th OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 9: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 4: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 4a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 4b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
                
                /////////10th DATA + 5th OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_POWEROFTWO_2.shared_data[k]);
                    in_2SHARE[1][k] = dual_mode ? $unsigned(A_2SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 10: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2arithmetic(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2arithmetic(in_2SHARE[1]));
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 5: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 5a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 5b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
                
                valid_data_2SHARE <= 1'b0;
            end
            else
            begin 
                valid_data_2SHARE <= 1'b0;
                #1ns;
                wait(valid_result_2SHARE); 
            end


            /////////6th OUT
            @(posedge clk iff arst_n);
            long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
            long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
            if (print_data == 1)
            begin
                $display("OUTPUT 6: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
            end
            assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 6a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
            if (dual_mode)
            begin
                assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 6b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
            end
                
            if (LAB_MODE == 0)
            begin
                /////////7th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 7: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 7a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 7b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
                /////////8th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 8: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 8a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 8b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
                /////////9th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 9: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 9a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 9b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
                /////////10th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                long_out[1] = unshare_2arithmetic_signed(A_2SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 10: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2Boolean(out_2SHARE[1]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 10a)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2Boolean(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 1, INPUT 10b)", unshare_2Boolean(out_2SHARE[1]), long_out[1], j); break; end
                end
            end
            $display("---------------------- TEST 1 CONCLUDED --------------------------");
            #3ns;
            data_modq <= 1'b1;
            dual_mode <= 1'b0;
            in_2SHARE[1] = '{default : '0};
            #1ns
            
//           break;

            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b1;

            modulus_in = prime_q;
            modulus_twoc_in = 32'd4294963967;

            #0.5ns;
            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b0;

            
            @(posedge clk iff arst_n);
            $display("TEST 2 -- A2B: N_SHARES = %d, MOD Q = %d", N_SHARES_2SHARE, prime_q);
            for (int k = 0; k < N_SHARES_2SHARE; k++)
            begin
                in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
            end
            if (print_data == 1)
            begin
                $display("INPUT 1: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
            end

            wait (prng_done_2SHARE);
            rnd_2SHARE_reg <= rnd_2SHARE;
            rnd_16bit_2SHARE_reg <= rnd_16bit_2SHARE;
            
            ///////////1st DATA
            valid_data_2SHARE <= 1'b1;
            
            if (LAB_MODE == 0)
            begin
                /////////2nd DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_2.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 2: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
    
                /////////3rd DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 3: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
    
                ////////4th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_2.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 4: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
                
                /////////5th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 5: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
                
                ////////6th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_2.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 6: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
                
                /////////7th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 7: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
                
                ////////8th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_2.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 8: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
                
                /////////9th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 9: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
                
                ////////10th DATA
                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_2.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 10: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
                
                #1ns;
            end
            else
            begin
                #1ns;
                valid_data_2SHARE <= 1'b0;
                wait(valid_result_2SHARE)
                valid_data_2SHARE <= 1'b1;
            end
            
            /////////11th DATA + 1st OUT
            for (int k = 0; k < N_SHARES_2SHARE; k++)
            begin
                in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
            end
            if (print_data == 1)
            begin
                $display("INPUT 11: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
            end
            #0.5ns;
            @(posedge clk iff arst_n);
            long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
            if (print_data == 1)
            begin
                $display("OUTPUT 1: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
            end
            assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 1)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
            
            if (LAB_MODE == 0)
            begin
                /////////12th DATA + 2nd OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_2.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 12: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_2.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 2: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 2)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
    
                ////////13th DATA + 3rd OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 13: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 3: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 3)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
            
                /////////14th DATA + 4th OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_2.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 14: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_2.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 4: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 4)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                ////////15th DATA + 5th OUT
                for (int k = 0; k < N_SHARES_2SHARE; k++)
                begin
                    in_2SHARE[0][k] = $unsigned(A_2SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 15: {(%0d, %0d) = %0d}", $signed(in_2SHARE[0][0]), $signed(in_2SHARE[0][1]), $signed(unshare_2arithmetic(in_2SHARE[0]))); // HAS TO BE NEGATIVE
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 5: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 5)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                valid_data_2SHARE <= 1'b0;
                
                ////////6th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_2.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 6: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 6)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                ////////7th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 7: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 7)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                ////////8th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_2.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 8: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 8)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                ////////9th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 9: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 9)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                ////////10th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_2.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 10: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 10)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
            end
            else
            begin 
                valid_data_2SHARE <= 1'b0;
                #1ns;
                wait(valid_result_2SHARE); 
            end
            
            /////////11th OUT
            @(posedge clk iff arst_n);
            long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
            if (print_data == 1)
            begin
                $display("OUTPUT 11: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
            end
            assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 11)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
            if (LAB_MODE == 0)
            begin
                /////////12th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_2.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 12: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 12)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                /////////13th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 13: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 13)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                /////////14th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_2.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 14: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 14)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
                
                /////////15th OUT
                @(posedge clk iff arst_n);
                long_out[0] = $unsigned(($signed(unshare_2arithmetic_signed(A_2SHARES_PRIME_1.shared_data)) + $signed(prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 15: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2Boolean(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2Boolean(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 2, INPUT 15)", unshare_2Boolean(out_2SHARE[0]), long_out[0], j); break; end
            end
            $display("---------------------- TEST 2 CONCLUDED --------------------------");
            #3ns;
            conversion_mode <= 1'b1;
            
            // break;

            #5ns;
            #0.5ns;
            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b1;

            #0.5ns;
            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b0;

            

            @(posedge clk iff arst_n);
            $display("TEST 3 -- B2A: N_SHARES = %d, MOD Q = %d", N_SHARES_2SHARE, prime_q);
            for (int j = 0; j < N_SHARES_2SHARE; j++)
            begin
                in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
            end
            if (print_data == 1)
            begin
                $display("INPUT 1: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
            end
            
            wait (prng_done_2SHARE);
            rnd_2SHARE_reg <= rnd_2SHARE;
            rnd_16bit_2SHARE_reg <= rnd_16bit_2SHARE;
            
            ///////////1st DATA
            valid_data_2SHARE <= 1'b1;

            if (LAB_MODE == 0)
            begin
                /////////2nd DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_2.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 2: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
    
                /////////3rd DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 3: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
    
                /////////4th DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_2.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 4: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
    
                /////////5th DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 5: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
    
                /////////6th DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_2.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 6: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
    
                /////////7th DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 7: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
    
                /////////8th DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_2.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 8: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
    
                /////////9th DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 9: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
                
                /////////10th DATA
                @(posedge clk iff arst_n);
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_2.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 10: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
                #1ns;
            end
            else
            begin
                #1ns;
                valid_data_2SHARE <= 1'b0;
//                wait(valid_result_2SHARE)
//                //@(posedge clk iff arst_n);
//                @(posedge clk iff arst_n);
            end
            
            /////////11th DATA + 1st OUT
            
            wait(valid_result_2SHARE);
            @(posedge clk iff arst_n);
            //@(posedge clk iff arst_n);
            //#0.5ns;
            //@(posedge clk iff arst_n);
            long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
            if (print_data == 1)
            begin
                $display("OUTPUT 1: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
            end
            assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 1)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
            //#0.5ns;
            //@(posedge clk iff arst_n);
            valid_data_2SHARE <= 1'b1;
            for (int j = 0; j < N_SHARES_2SHARE; j++)
            begin
                in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
            end
            if (print_data == 1)
            begin
                $display("INPUT 11: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
            end
            
            if (LAB_MODE == 0)
            begin
                /////////12th DATA + 2nd OUT
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_2.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 12: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 2: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 2)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
           
                /////////13th DATA + 3nd OUT
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 13: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 3: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 3)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
           
                /////////14th DATA + 4th OUT
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_2.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 14: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 4: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 4)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
           
                /////////15th DATA + 5th OUT
                for (int j = 0; j < N_SHARES_2SHARE; j++)
                begin
                    in_2SHARE[0][j] = B_2SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 15: {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]));
                end
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 5: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 5)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
           
                valid_data_2SHARE <= 1'b0;
                
                /////////6th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 6: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 6)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
                /////////7th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 7: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 7)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
                /////////8th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 8: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 8)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
                /////////9th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 9: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 9)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
                /////////10th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 10: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 10)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
            end
            else
            begin
                @(posedge clk iff arst_n);
                valid_data_2SHARE <= 1'b0;
                #1ns;
                wait(valid_result_2SHARE); 
            end
            
            /////////11th OUT
            @(posedge clk iff arst_n);
            long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
            if (print_data == 1)
            begin
                $display("OUTPUT 11: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
            end
            assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 11)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
            
            if (LAB_MODE == 0)
            begin
                /////////12th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 12: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 12)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
                /////////13th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 13: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 13)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
                /////////14th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 14: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 14)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
                
                /////////15th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 15: {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 3, INPUT 15)", unshare_2arithmetic(out_2SHARE[0]) % prime_q, long_out[0], j); break; end
            
            end
               
            $display("---------------------- TEST 3 CONCLUDED --------------------------");
            #3ns;
            data_modq <= 1'b0;
            dual_mode <= (DUAL_MODE == 1) ? 1'b1 : 1'b0;
            
           // break;

            #5ns;
            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b1;

            modulus_in = power_of_two_q;
            modulus_twoc_in = 32'd0;

            #0.5ns;
            @(posedge clk iff arst_n);
            request_rnd_2SHARE = 1'b0;
            
            @(posedge clk iff arst_n);
            $display("TEST 4 -- B2A: N_SHARES = %d, MOD Q = %d", N_SHARES_2SHARE, power_of_two_q);
            in_2SHARE[0] = B_2SHARES_POWEROFTWO_1.shared_data;
            in_2SHARE[1] = B_2SHARES_POWEROFTWO_2.shared_data;
            if (print_data == 1)
            begin
                $display("INPUT 1: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
            end
            
            wait (prng_done_2SHARE);
            rnd_2SHARE_reg <= rnd_2SHARE;
            rnd_16bit_2SHARE_reg <= rnd_16bit_2SHARE;
            
            ///////////1st DATA
            valid_data_2SHARE <= 1'b1;

            if (LAB_MODE == 0)
            begin
                /////////2nd DATA
                @(posedge clk iff arst_n);
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_2.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_1.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 2: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end

                /////////3rd DATA
                @(posedge clk iff arst_n);
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_1.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_2.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 3: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end

                /////////4th DATA
                @(posedge clk iff arst_n);
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_2.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_1.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 4: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end

                /////////5th DATA
                @(posedge clk iff arst_n);
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_1.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_2.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 5: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end
                #1ns;
            end
            else
            begin
                #1ns;
                valid_data_2SHARE <= 1'b0;
                
                //valid_data_2SHARE <= 1'b1;
            end
            
            /////////6th DATA + 1st OUT
            wait(valid_result_2SHARE);
            @(posedge clk iff arst_n);
            //#0.5ns;
            // HERE SWITCH
//            @(posedge clk iff arst_n);
            long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
            long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
            if (print_data == 1)
            begin
                $display("OUTPUT 1: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
            end
            assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 1a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
            if (dual_mode)
            begin
                assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 1b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
            end
            
            valid_data_2SHARE <= 1'b1;
            in_2SHARE[0] = B_2SHARES_POWEROFTWO_2.shared_data;
            in_2SHARE[1] = B_2SHARES_POWEROFTWO_1.shared_data;
            if (print_data == 1)
            begin
                $display("INPUT 6: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
            end
            
            if (LAB_MODE == 0)
            begin
                /////////7th DATA + 2nd OUT
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_1.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_2.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 7: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 2: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 2a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 2b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end
            
                /////////8th DATA + 3rd OUT
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_2.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_1.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 8: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 3: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 3a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 3b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end
                
                /////////9th DATA + 4th OUT
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_1.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_2.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 9: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 4: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 3a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 3b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end
                
                /////////10th DATA + 5th OUT
                in_2SHARE[0] = B_2SHARES_POWEROFTWO_2.shared_data;
                in_2SHARE[1] = B_2SHARES_POWEROFTWO_1.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 10: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", in_2SHARE[0][0], in_2SHARE[0][1], unshare_2Boolean(in_2SHARE[0]), in_2SHARE[1][0], in_2SHARE[1][1], unshare_2Boolean(in_2SHARE[1]));
                end
    
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 5: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 5a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 5b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end
                valid_data_2SHARE <= 1'b0;
            end
            else
            begin 
                @(posedge clk iff arst_n);
                valid_data_2SHARE <= 1'b0;
                #1ns;
                wait(valid_result_2SHARE); 
            end
            
            /////////6th OUT
            @(posedge clk iff arst_n);
            long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
            long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
            if (print_data == 1)
            begin
                $display("OUTPUT 6: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
            end
            assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 6a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
            if (dual_mode)
            begin
                assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 6b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
            end

            if (LAB_MODE == 0)
            begin
                /////////7th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 7: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 7a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 7b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end

                /////////8th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 8: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 8a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 8b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end
                
                /////////9th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 9: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 9a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 9b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end

                /////////10th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_2Boolean(B_2SHARES_POWEROFTWO_2.shared_data);
                long_out[1] = unshare_2Boolean(B_2SHARES_POWEROFTWO_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 10: {(%0d, %0d) = %0d} && {(%0d, %0d) = %0d}", out_2SHARE[0][0], out_2SHARE[0][1], unshare_2arithmetic(out_2SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], unshare_2arithmetic(out_2SHARE[0]));
                end
                assert(long_out[0] == (unshare_2arithmetic(out_2SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 10a)", unshare_2arithmetic(out_2SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_2arithmetic(out_2SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 4, INPUT 10b)", unshare_2arithmetic(out_2SHARE[1]), long_out[1], j); break; end
                end
            end
            
            #1ns;
            ready_result_2SHARE <= 1'b0;
            conversion_mode <= 1'b0;

            $display("---------------------- TEST 4 CONCLUDED --------------------------");

            
            
            
        end
    $finish();
  end

endmodule
