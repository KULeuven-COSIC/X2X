
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

class ARITHMETIC_3SHARE_Corrected
#(
    parameter PARAM_WIDTH = 16,
    parameter N_SHARES = 3,
    parameter q = 3329
);

    rand logic signed [PARAM_WIDTH - 1 : 0] shared_data [N_SHARES - 1 : 0];

    constraint a_val
    {
       shared_data[0] inside {[0 : q - 1]};
       shared_data[2] inside {[0 : q - 1]};
    }
    constraint b_val
    {
       shared_data[1] inside {[-q : - 1]};
    }

endclass

class ARITHMETIC_4SHARE_Corrected
#(
    parameter PARAM_WIDTH = 16,
    parameter N_SHARES = 4,
    parameter q = 3329
);

    rand logic signed [PARAM_WIDTH - 1 : 0] shared_data [N_SHARES - 1 : 0];

    constraint a_val
    {
       shared_data[0] inside {[0 : q - 1]};
       shared_data[1] inside {[-q : -1]}; //x1 - q
       shared_data[2] inside {[0 : q - 1]};
       shared_data[3] inside {[-q : -1]}; //x3 - q
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
       unshare(shared_data) inside {[0 : q - 1]};
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


module MaskConv_HALF_STREAM_tb;

    /////////////////////////////////
	// INTERNAL SIGNAL DECLARATION //
	/////////////////////////////////

    ////// DISPLAY/SIMULATION SETTINGS //////
    localparam print_data = 1;
    localparam N_SIMULATIONS = 1;
    localparam DUAL_MODE = 0;       // 2 simulataneous mod power-of-two calculations
    localparam HALFCYCLE = 1;       // simulate halfcycle implementation
    localparam LAB_MODE = 1;        // 1 data operand calculates at a time
    localparam TEST_3SHARE = 1;     // simulate 3 share implementation
    localparam TEST_4SHARE = 0;     // simulate 4 share implementation
    /////////////////////////////////////////
    
    localparam log2_of_q = 12;
    localparam PARAM_WIDTH = log2_of_q + 1;
    localparam LSFR_WIDTH = 32;
    localparam NB_SEEDS = 6;
    localparam N_STAGES = 4;
    localparam prime_q = 3329; // Kyber Q
    localparam power_of_two_q = 8192; //65536; //2^16

    localparam N_SHARES_2SHARE = 2;
    localparam N_SHARES_3SHARE = 3;
    
    localparam B2A_RND_SHARES_2SHARE = N_SHARES_2SHARE - 1;
    localparam B2A_RND_SHARES_3SHARE = N_SHARES_3SHARE - 1;
    localparam EXPAND_SHARES_2SHARE = N_SHARES_2SHARE;
    localparam EXPAND_SHARES_3SHARE = 2 * N_SHARES_3SHARE;
    localparam TRIANGLE_SHARES_2SHARE = 2 * (N_SHARES_2SHARE * (N_SHARES_2SHARE - 1) / 2);
    localparam TRIANGLE_SHARES_3SHARE = 2 * (N_SHARES_3SHARE * (N_SHARES_3SHARE - 1) / 2);
    localparam BOX_SHARES_2SHARE = (N_STAGES - 1) * 3 * (N_SHARES_2SHARE * (N_SHARES_2SHARE - 1) / 2) + 2 * (N_SHARES_2SHARE * (N_SHARES_2SHARE - 1) / 2);
    localparam BOX_SHARES_3SHARE = (N_STAGES - 1) * 3 * (N_SHARES_3SHARE * (N_SHARES_3SHARE - 1) / 2) + 2 * (N_SHARES_3SHARE * (N_SHARES_3SHARE - 1) / 2);
   
    localparam RND_SHARES_2SHARE = 2 * B2A_RND_SHARES_2SHARE + 2 * EXPAND_SHARES_2SHARE + 2 * TRIANGLE_SHARES_2SHARE;
    localparam RND_SHARES_3SHARE = 2 * B2A_RND_SHARES_3SHARE + 2 * (EXPAND_SHARES_3SHARE + EXPAND_SHARES_2SHARE) + 2 * (TRIANGLE_SHARES_3SHARE + TRIANGLE_SHARES_2SHARE);
    localparam RND_SHARES_2SHARE_8bit = 2 * BOX_SHARES_2SHARE;
    localparam RND_SHARES_3SHARE_8bit = 2 * (BOX_SHARES_3SHARE + BOX_SHARES_2SHARE);

    // MASK CONV
    logic [PARAM_WIDTH - 1 : 0] in_2SHARE   [2 - 1 : 0][N_SHARES_2SHARE - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] out_2SHARE  [2 - 1 : 0][N_SHARES_2SHARE - 1 : 0];
    logic valid_data_2SHARE, ready_data_2SHARE, valid_result_2SHARE, ready_result_2SHARE;
    logic [PARAM_WIDTH - 1 : 0] in_3SHARE   [2 - 1 : 0][N_SHARES_3SHARE - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0] out_3SHARE  [2 - 1 : 0][N_SHARES_3SHARE - 1 : 0];
    logic valid_data_3SHARE, ready_data_3SHARE, valid_result_3SHARE, ready_result_3SHARE;

    logic conversion_mode;
    logic data_modq;
    logic dual_mode;
    
    // PRNG ENGINE
    logic seed_prng;
    logic request_rnd_2SHARE;
    logic request_rnd_3SHARE;
    logic prng_done_2SHARE;
    logic prng_done_3SHARE;
    logic [NB_SEEDS * 128 - 1 : 0]  seed_2SHARE;
    logic [NB_SEEDS * 128 - 1 : 0]  seed_3SHARE;
    logic [8 - 1 : 0]               rnd_8bit_2SHARE [RND_SHARES_2SHARE_8bit - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0]     rnd_2SHARE      [RND_SHARES_2SHARE - 1 : 0];
    logic [8 - 1 : 0]               rnd_8bit_2SHARE_reg [RND_SHARES_2SHARE_8bit - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0]     rnd_2SHARE_reg      [RND_SHARES_2SHARE - 1 : 0];

    logic [8 - 1 : 0]               rnd_8bit_3SHARE [RND_SHARES_3SHARE_8bit - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0]     rnd_3SHARE      [RND_SHARES_3SHARE - 1 : 0];
    logic [8 - 1 : 0]               rnd_8bit_3SHARE_reg [RND_SHARES_3SHARE_8bit - 1 : 0];
    logic [PARAM_WIDTH - 1 : 0]     rnd_3SHARE_reg      [RND_SHARES_3SHARE - 1 : 0];


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
        request_rnd_3SHARE = 0;
        conversion_mode = 0;
        ready_result_2SHARE = 0;
        ready_result_3SHARE = 0;
        valid_data_2SHARE = 0;
        valid_data_3SHARE = 0;
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
    SEED_ENGINE_2SHARE, SEED_ENGINE_3SHARE;

    MaskConversion_HALFCYCLE_STREAM
    #(
        .HALFCYCLE(HALFCYCLE),
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_2SHARE),
        .RND_SHARES(RND_SHARES_2SHARE),
        .RND_SHARES_8bit(RND_SHARES_2SHARE_8bit)
    )
    MaskConv_2SHARE_inst
    (
        .clk(clk),
        .rst_n(arst_n),
        .conversion_mode(conversion_mode),
        .data_type_mode(data_modq),
        .dual_mode(dual_mode),
        .valid_data(valid_data_2SHARE),
        .ready_data(ready_data_2SHARE),
        .original_data(in_2SHARE),
        .converted_data(out_2SHARE),
        .valid_result(valid_result_2SHARE),
        .ready_result(ready_result_2SHARE),
        .fresh_rnd_shares(rnd_2SHARE_reg),
        .fresh_rnd_shares_8bit(rnd_8bit_2SHARE_reg)
    );

    PRNG_engine_STREAM
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .LSFR_WIDTH(LSFR_WIDTH),
        .SEED_WIDTH(NB_SEEDS*128),
        .N_SHARES(N_SHARES_2SHARE),
        .RND_SHARES(RND_SHARES_2SHARE),
        .RND_SHARES_8bit(RND_SHARES_2SHARE_8bit)
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
        .rnd_out_8bit(rnd_8bit_2SHARE),
        .rnd_out(rnd_2SHARE)
    );

   MaskConversion_HALFCYCLE_STREAM
   #(
       .HALFCYCLE(HALFCYCLE),
       .PARAM_WIDTH(PARAM_WIDTH),
       .N_SHARES(N_SHARES_3SHARE),
       .RND_SHARES(RND_SHARES_3SHARE),
       .RND_SHARES_8bit(RND_SHARES_3SHARE_8bit)
   )
   MaskConv_3SHARE_inst
   (
       .clk(clk),
       .rst_n(arst_n),
       .conversion_mode(conversion_mode),
       .data_type_mode(data_modq),
       .dual_mode(dual_mode),
       .valid_data(valid_data_3SHARE),
       .ready_data(ready_data_3SHARE),
       .original_data(in_3SHARE),
       .converted_data(out_3SHARE),
       .valid_result(valid_result_3SHARE),
       .ready_result(ready_result_3SHARE),
       .fresh_rnd_shares(rnd_3SHARE),
       .fresh_rnd_shares_8bit(rnd_8bit_3SHARE)
   );

   PRNG_engine_STREAM
   #(
       .PARAM_WIDTH(PARAM_WIDTH),
       .LSFR_WIDTH(LSFR_WIDTH),
       .SEED_WIDTH(NB_SEEDS*128),
       .N_SHARES(N_SHARES_3SHARE),
       .RND_SHARES(RND_SHARES_3SHARE),
       .RND_SHARES_8bit(RND_SHARES_3SHARE_8bit)
   )
   PRNG_3SHARE_inst
   (
       .clk(clk),
       .rst_n(arst_n),
       .mod_type(data_modq),
       .conversion_type(conversion_mode),
       .dual_mode(dual_mode),
       .load_seed(seed_prng),
       .update_rnd(request_rnd_3SHARE),
       .prng_done(prng_done_3SHARE),
       .seed_in(seed_3SHARE),
       .rnd_out_8bit(rnd_8bit_3SHARE),
       .rnd_out(rnd_3SHARE)
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
    
    ARITHMETIC_3SHARE_Corrected
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_3SHARE),
        .q(power_of_two_q)
    )
    A_3SHARES_POWEROFTWO_1, A_3SHARES_POWEROFTWO_2;

    ARITHMETIC_3SHARE_Corrected
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_3SHARE),
        .q(prime_q)
    )
    A_3SHARES_PRIME_1, A_3SHARES_PRIME_2;

//    ARITHMETIC4_Corrected
//    #(
//        .PARAM_WIDTH(PARAM_WIDTH),
//        .N_SHARES(N_SHARES1),
//        .q(power_of_two_q)
//    )
//    A_4SHARES_POWEROFTWO_1, A_4SHARES_POWEROFTWO_2;

//    ARITHMETIC4_Corrected
//    #(
//        .PARAM_WIDTH(PARAM_WIDTH),
//        .N_SHARES(N_SHARES1),
//        .q(prime_q)
//    )
//    A_4SHARES_PRIME_1, A_4SHARES_PRIME_2;

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
    
    BOOLEAN_XSHARE
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_3SHARE),
        .q(power_of_two_q)
    )
    B_3SHARES_POWEROFTWO_1, B_3SHARES_POWEROFTWO_2;

    BOOLEAN_XSHARE
    #(
        .PARAM_WIDTH(PARAM_WIDTH),
        .N_SHARES(N_SHARES_3SHARE),
        .q(prime_q)
    )
    B_3SHARES_PRIME_1, B_3SHARES_PRIME_2;

//    BOOLEAN
//    #(
//        .PARAM_WIDTH(PARAM_WIDTH),
//        .N_SHARES(N_SHARES1),
//        .q(power_of_two_q)
//    )
//    B_4SHARES_POWEROFTWO_1, B_4SHARES_POWEROFTWO_2;

//    BOOLEAN
//    #(
//        .PARAM_WIDTH(PARAM_WIDTH),
//        .N_SHARES(N_SHARES1),
//        .q(prime_q)
//    )
//    B_4SHARES_PRIME_1, B_4SHARES_PRIME_2;


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
    
    function unshared unshare_3arithmetic  (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES_3SHARE - 1 : 0]);
        unshare_3arithmetic = x.sum();
        
        
        return unshare_3arithmetic;
    endfunction
    
    function unshared unsharemod_3arithmetic  (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES_3SHARE - 1 : 0]);
        unsharemod_3arithmetic = x[0] + x[1];
        if (unsharemod_3arithmetic >= 3329)
            unsharemod_3arithmetic -= 3329;
        unsharemod_3arithmetic += x[2];
        
        
        return unsharemod_3arithmetic;
    endfunction

    function unshared unshare_3arithmetic_signed  (input logic signed [PARAM_WIDTH - 1 : 0] x [N_SHARES_3SHARE - 1 : 0]);
        unshare_3arithmetic_signed = $signed(x.sum());

        return $unsigned(unshare_3arithmetic_signed);
    endfunction
    
    function unshared unsharemod_3arithmetic_signed  (input logic signed [PARAM_WIDTH - 1 : 0] x [N_SHARES_3SHARE - 1 : 0]);
        unsharemod_3arithmetic_signed = x[0];
        for (int i = 1; i < N_SHARES_3SHARE; i++)
        begin
            if (x[i] < 3329)
                unsharemod_3arithmetic_signed += x[i];
            else if ($unsigned(x[i]) >= 3329)
            begin
                unsharemod_3arithmetic_signed += $signed(x[i] - 8192);
            end
            while (unsharemod_3arithmetic_signed >= 3329)
                unsharemod_3arithmetic_signed -= 3329;
            while (unsharemod_3arithmetic_signed < 0)
                unsharemod_3arithmetic_signed += 3329;
        end
        return $unsigned(unsharemod_3arithmetic_signed);
    endfunction

    function unshared unshare_3Boolean (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES_3SHARE - 1 : 0]);
        unshare_3Boolean = x.xor();

        return unshare_3Boolean;
    endfunction

//    function unshared unshare_4arithmetic  (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES1 - 1 : 0]);
//        unshare_4arithmetic = x.sum();

//        return unshare_4arithmetic;
//    endfunction

//    function unshared unshare_4arithmetic_signed  (input logic signed [PARAM_WIDTH - 1 : 0] x [N_SHARES1 - 1 : 0]);
//        unshare_4arithmetic_signed = $signed(x.sum());

//        return unshare_4arithmetic_signed;
//    endfunction
    
//    function unshared unsharemod_4arithmetic_signed  (input logic signed [PARAM_WIDTH - 1 : 0] x [N_SHARES1 - 1 : 0]);
//        unsharemod_4arithmetic_signed = x[0];
//        for (int i = 1; i < N_SHARES1; i++)
//        begin
//            unsharemod_4arithmetic_signed += x[i];
//            if (unsharemod_4arithmetic_signed >= 3329)
//                unsharemod_4arithmetic_signed -= 3329;
//        end
//        return $unsigned(unsharemod_4arithmetic_signed);
//    endfunction

//    function unshared unshare_4Boolean (input logic [PARAM_WIDTH - 1 : 0] x [N_SHARES1 - 1 : 0]);
//        unshare_4Boolean = x.xor();

//        return unshare_4Boolean;
//    endfunction



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
        
        A_3SHARES_POWEROFTWO_1 = new();
        A_3SHARES_POWEROFTWO_2 = new();
        B_3SHARES_POWEROFTWO_1 = new();
        B_3SHARES_POWEROFTWO_2 = new();

        A_3SHARES_PRIME_1 = new();
        A_3SHARES_PRIME_2 = new();
        B_3SHARES_PRIME_1 = new();
        B_3SHARES_PRIME_2 = new();

//        A_4SHARES_POWEROFTWO_1 = new();
//        A_4SHARES_POWEROFTWO_2 = new();
//        B_4SHARES_POWEROFTWO_1 = new();
//        B_4SHARES_POWEROFTWO_2 = new();

//        A_4SHARES_PRIME_1 = new();
//        A_4SHARES_PRIME_2 = new();
//        B_4SHARES_PRIME_1 = new();
//        B_4SHARES_PRIME_2 = new();


        SEED_ENGINE_2SHARE = new();
        SEED_ENGINE_3SHARE = new();

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
            
            A_3SHARES_POWEROFTWO_1.randomize();
            A_3SHARES_POWEROFTWO_2.randomize();
            B_3SHARES_POWEROFTWO_1.randomize();
            B_3SHARES_POWEROFTWO_2.randomize();

            A_3SHARES_PRIME_1.randomize();
            A_3SHARES_PRIME_2.randomize();
            B_3SHARES_PRIME_1.randomize();
            B_3SHARES_PRIME_2.randomize();

//            A_4SHARES_POWEROFTWO_1.randomize();
//            A_4SHARES_POWEROFTWO_2.randomize();
//            B_4SHARES_POWEROFTWO_1.randomize();
//            B_4SHARES_POWEROFTWO_2.randomize();

//            A_4SHARES_PRIME_1.randomize();
//            A_4SHARES_PRIME_2.randomize();
//            B_4SHARES_PRIME_1.randomize();
//            B_4SHARES_PRIME_2.randomize();

            SEED_ENGINE_2SHARE.randomize();
            SEED_ENGINE_3SHARE.randomize();

            #0.5ns;

            @(posedge clk iff arst_n);

            seed_2SHARE = SEED_ENGINE_2SHARE.seed;
            seed_3SHARE = SEED_ENGINE_3SHARE.seed;
            
            
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
            rnd_8bit_2SHARE_reg <= rnd_8bit_2SHARE;

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
            rnd_8bit_2SHARE_reg <= rnd_8bit_2SHARE;
            
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
            rnd_8bit_2SHARE_reg <= rnd_8bit_2SHARE;
            
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
            rnd_8bit_2SHARE_reg <= rnd_8bit_2SHARE;
            
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

            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            ///////////////////////////////
            //////PHASE 2: 3 SHARES////////
            ///////////////////////////////
            
            if (TEST_3SHARE == 1)
            begin
                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b1;
    
                #0.5ns;
                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b0;

                $display("TEST 5 -- A2B: N_SHARES = %d, MOD Q = %d", N_SHARES_3SHARE, power_of_two_q);

                @(posedge clk iff arst_n);
                for (int k = 0; k < N_SHARES_3SHARE; k++)
                begin
                    in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                    in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 1: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                end
                
                
                wait (prng_done_3SHARE);
                rnd_3SHARE_reg <= rnd_3SHARE;
                rnd_8bit_3SHARE_reg <= rnd_8bit_3SHARE;

                ///////////1st DATA
                valid_data_3SHARE <= 1'b1;
                ready_result_3SHARE <= 1'b1;


                if (LAB_MODE == 0)
                begin
                    /////////2nd DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 2: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
            
                    /////////3rd DATA
                    @(posedge clk iff arst_n);
                    
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 3: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
            
                    ////////4th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 4: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    
                    /////////5th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 5: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    
                    /////////6th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 6: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    
                    /////////7th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 7: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    
                    /////////8th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 8: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    
                    /////////9th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 9: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    
                    /////////10th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 10: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    #1ns;
                end
                else
                begin
                    #1ns;
                    valid_data_3SHARE <= 1'b0;
                    wait(valid_result_3SHARE)
                    valid_data_3SHARE <= 1'b1;
                end


                /////////11th DATA + 1st OUT
                for (int k = 0; k < N_SHARES_3SHARE; k++)
                begin
                    in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                    in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                end
                if (print_data == 1)
                begin
                    $display("INPUT 11: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                end
                #0.5ns;

                @(posedge clk iff arst_n);
                long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 1: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                end
                assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 1a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 1b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                end
                
                if (LAB_MODE == 0)
                begin
                    /////////12th DATA + 2nd OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 12: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
        
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 2: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 2a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 2b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    ////////13th DATA + 3rd OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 13: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    #0.5ns;

                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 3: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 3a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 3b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
        
                    /////////14th DATA + 4th OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 14: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
        
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 4: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 4a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 4b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////15th DATA + 5th OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_POWEROFTWO_1.shared_data[k]);
                        in_3SHARE[1][k] = dual_mode ? $unsigned(A_3SHARES_POWEROFTWO_2.shared_data[k]) : '0;
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 15: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3arithmetic(in_3SHARE[1]));
                    end
                    #0.5ns;

                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 5: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 5a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 5b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    valid_data_2SHARE <= 1'b0;
                    
                    /////////6th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 6: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 6a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 6b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////7th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 7: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 7a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 7b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////8th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 8: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 8a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 8b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////9th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 9: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 9a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 9b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////10th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 10: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 10a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 10b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                end
                else
                begin
                    valid_data_3SHARE <= 1'b0;
                    #1ns;
                    wait(valid_result_3SHARE);
                end


                /////////11th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                if (print_data == 1)
                begin
                    $display("OUTPUT 11: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                end
                assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 11a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 11b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                end
                    
                if (LAB_MODE == 0)
                begin
                    /////////12th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 12: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 12a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 12b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////13th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 13: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 13a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 13b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////14th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 14: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 14a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 14b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////15th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_1.shared_data); //implicit MOD
                    long_out[1] = unshare_3arithmetic_signed(A_3SHARES_POWEROFTWO_2.shared_data); //implicit MOD
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 15: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]), out_3SHARE[1][0], out_3SHARE[1][1], out_3SHARE[1][2], unshare_3Boolean(out_3SHARE[1]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 15a)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3Boolean(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 5, INPUT 15b)", unshare_3Boolean(out_3SHARE[1]), long_out[1], j); break; end
                    end
                end
                $display("---------------------- TEST 5 CONCLUDED --------------------------");
                #3ns;
                data_modq <= 1'b1;
                dual_mode <= 1'b0;
                in_3SHARE[1] = '{default : '0};
                #1ns
                
               

                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b1;

                #0.5ns;
                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b0;

                
                @(posedge clk iff arst_n);
                $display("TEST 6 -- A2B: N_SHARES = %d, MOD Q = %d", N_SHARES_3SHARE, prime_q);
                for (int k = 0; k < N_SHARES_3SHARE; k++)
                begin
                    in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 1: {(%0d, %0d, %0d) = %0d}", $signed(in_3SHARE[0][0]), $signed(in_3SHARE[0][1]), $signed(in_3SHARE[0][2]), unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                end

                wait (prng_done_3SHARE);
                rnd_3SHARE_reg <= rnd_3SHARE;
                rnd_8bit_3SHARE_reg <= rnd_8bit_3SHARE;
                
                ///////////1st DATA
                valid_data_3SHARE <= 1'b1;
                
                if (LAB_MODE == 0)
                begin
                    /////////2nd DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 2: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
        
                    /////////3rd DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 3: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
        
                    ////////4th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 4: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////5th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 5: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    ////////6th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 6: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////7th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 7: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    ////////8th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 8: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////9th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 9: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    ////////10th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 10: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////11th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 11: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////12th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 12: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
        
                    /////////13th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 13: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
        
                    ////////14th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 14: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////15th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 15: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    ////////16th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 16: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////17th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 17: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    ////////18th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 18: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    /////////19th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 19: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    ////////20th DATA
                    @(posedge clk iff arst_n);
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 20: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    #1ns;
                end
                else
                begin
                    #1ns;
                    valid_data_3SHARE <= 1'b0;
                    wait(valid_result_3SHARE)
                    valid_data_3SHARE <= 1'b1;
                end
                
                /////////21th DATA + 1st OUT
                for (int k = 0; k < N_SHARES_3SHARE; k++)
                begin
                    in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                end
                if (print_data == 1)
                begin
                    $display("INPUT 21: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], $signed(in_3SHARE[0][1]), in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                end
                #0.5ns;
                @(posedge clk iff arst_n);
                //long_out[0] = $unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 1: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                end
                assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 1)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                
                if (LAB_MODE == 0)
                begin
                    /////////22th DATA + 2nd OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 22: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
        
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 2: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 2)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////23th DATA + 3rd OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 23: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 3: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 3)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    /////////24th DATA + 4th OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_2.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 24: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
        
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 4: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 4)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////25th DATA + 5th OUT
                    for (int k = 0; k < N_SHARES_3SHARE; k++)
                    begin
                        in_3SHARE[0][k] = $unsigned(A_3SHARES_PRIME_1.shared_data[k]);
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 25: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3arithmetic(in_3SHARE[0])); // HAS TO BE NEGATIVE
                    end
                    
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 5: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 5)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    valid_data_3SHARE <= 1'b0;
                    
                    ////////6th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 6: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 6)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////7th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 7: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 7)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////8th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 8: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 8)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////9th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 9: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 9)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////10th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 10: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 10)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////11th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 11: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 11)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////12th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 12: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 12)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////13th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 13: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 13)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////14th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 14: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 14)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////15th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 15: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 15)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////16th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 16: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 16)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////17th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 17: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 17)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////18th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 18: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 18)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////19th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 19: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 19)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    ////////20th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 20: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 20)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                end
                else
                begin
                    valid_data_3SHARE <= 1'b0;
                    #1ns;
                    wait(valid_result_3SHARE);
                end
                
                /////////21th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                if (print_data == 1)
                begin
                    $display("OUTPUT 21: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                end
                assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 21)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                if (LAB_MODE == 0)
                begin
                    /////////22th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 22: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 22)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    /////////23th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 23: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 23)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    /////////24th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data);//$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_2.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 24: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 24)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                    
                    /////////25th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unsharemod_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data); //$unsigned(($signed(unshare_3arithmetic_signed(A_3SHARES_PRIME_1.shared_data)) + $signed(2*prime_q)) % prime_q);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 25: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3Boolean(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3Boolean(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 6, INPUT 25)", unshare_3Boolean(out_3SHARE[0]), long_out[0], j); break; end
                end
                $display("---------------------- TEST 6 CONCLUDED --------------------------");
                #3ns;
                conversion_mode <= 1'b1;
                
                #5ns;
                #0.5ns;
                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b1;

                #0.5ns;
                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b0;

                

                @(posedge clk iff arst_n);
                $display("TEST 7 -- B2A: N_SHARES = %d, MOD Q = %d", N_SHARES_3SHARE, prime_q);
                for (int j = 0; j < N_SHARES_3SHARE; j++)
                begin
                    in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 1: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                end
                
                wait (prng_done_3SHARE)
                
                ///////////1st DATA
                valid_data_3SHARE <= 1'b1;

                if (LAB_MODE == 0)
                begin
                    /////////2nd DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 2: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////3rd DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 3: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////4th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 4: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////5th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 5: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////6th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 6: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////7th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 7: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////8th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 8: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////9th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 9: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    
                    /////////10th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 10: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    
                    /////////11th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 11: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    
                    /////////12th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 12: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////13th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 13: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////14th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 14: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////15th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 15: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////16th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 16: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////17th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 17: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////18th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 18: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
        
                    /////////19th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 19: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    
                    /////////20th DATA
                    @(posedge clk iff arst_n);
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 20: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    #1ns;
                end
                else
                begin
                    #1ns;
                    valid_data_3SHARE <= 1'b0;
                    //wait(valid_result_3SHARE)
                    //valid_data_3SHARE <= 1'b1;
                end

                wait(valid_result_3SHARE);
                @(posedge clk iff arst_n);
                long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 1: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 1)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end

                valid_data_3SHARE <= 1'b1;
                
                /////////21th DATA + 1st OUT
                for (int j = 0; j < N_SHARES_3SHARE; j++)
                begin
                    in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                end
                if (print_data == 1)
                begin
                    $display("INPUT 21: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                end
                //#0.5ns;
                //@(posedge clk iff arst_n);

                
                if (LAB_MODE == 0)
                begin
                    /////////22th DATA + 2nd OUT
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 22: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 2: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 2)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////23th DATA + 3nd OUT
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 23: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    #0.5ns;
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 3: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 3)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////24th DATA + 4th OUT
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_2.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 24: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 4: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 4)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////25th DATA + 5th OUT
                    for (int j = 0; j < N_SHARES_3SHARE; j++)
                    begin
                        in_3SHARE[0][j] = B_3SHARES_PRIME_1.shared_data[j];
                    end
                    if (print_data == 1)
                    begin
                        $display("INPUT 25: {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]));
                    end
                    #0.5ns;
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 5: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 5)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    valid_data_3SHARE <= 1'b0;
                    
                    /////////6th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 6: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 6)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////7th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 7: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 7)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////8th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 8: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 8)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////9th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 9: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 9)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////10th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 10: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 10)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////11th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 11: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 11)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////12th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 12: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 12)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////13th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 13: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 13)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////14th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 14: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 14)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////15th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 15: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 15)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////16th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 16: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 16)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////17th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 17: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 17)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////18th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 18: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 18)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////19th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 19: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 19)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////20th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 20: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 20)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                end
                else
                begin
                    @(posedge clk iff arst_n);
                    valid_data_3SHARE <= 1'b0;
                    #1ns;
                    wait(valid_result_3SHARE);
                end
                
                /////////21th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 21: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                end
                assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 21)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                if (LAB_MODE == 0)
                begin
                    /////////22th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 22: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 22)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////23th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 23: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 23)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////24th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 24: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 24)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                    /////////25th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_PRIME_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 25: {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]) % prime_q);
                    end
                    assert(long_out[0] == (unsharemod_3arithmetic(out_3SHARE[0]) % prime_q)) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 7, INPUT 25)", unshare_3arithmetic(out_3SHARE[0]) % prime_q, long_out[0], j); break; end
                
                end
                   
                $display("---------------------- TEST 7 CONCLUDED --------------------------");
                #3ns;
                data_modq <= 1'b0;
                dual_mode <= (DUAL_MODE == 1) ? 1'b1 : 1'b0;

                #5ns;
                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b1;

                #0.5ns;
                @(posedge clk iff arst_n);
                request_rnd_3SHARE = 1'b0;
                
                @(posedge clk iff arst_n);
                $display("TEST 8 -- B2A: N_SHARES = %d, MOD Q = %d", N_SHARES_3SHARE, power_of_two_q);
                in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 1: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                end
                
                wait (prng_done_3SHARE);
                rnd_3SHARE_reg <= rnd_3SHARE;
                rnd_8bit_3SHARE_reg <= rnd_8bit_3SHARE;
                
                ///////////1st DATA
                valid_data_3SHARE <= 1'b1;

                if (LAB_MODE == 0)
                begin
                    /////////2nd DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_2.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_1.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 2: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end

                    /////////3rd DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 3: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end

                    /////////4th DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_2.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_1.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 4: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end

                    /////////5th DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 5: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
                    
                    /////////6th DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_2.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_1.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 6: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
                    
                    /////////7th DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 7: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
                    
                    /////////8th DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_2.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_1.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 8: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end

                    /////////9th DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 9: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
                    
                    /////////10th DATA
                    @(posedge clk iff arst_n);
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_2.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_1.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 10: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
                    
                    #1ns;
                end
                else
                begin
                    //@(posedge clk iff arst_n);
                    //valid_data_3SHARE <= 1'b0;
                    #1ns;
                    wait(valid_result_3SHARE);
                    //#1ns;
                    //valid_data_3SHARE <= 1'b0;
                    //wait(valid_result_3SHARE)
                    //valid_data_3SHARE <= 1'b1;
                end

                wait(valid_result_3SHARE);
                @(posedge clk iff arst_n);
                long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 1: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                end
                assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 1a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 1b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                end
                valid_data_3SHARE <= 1'b1;
                
                /////////11th DATA + 1st OUT
                in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                if (print_data == 1)
                begin
                    $display("INPUT 11: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                end
                //#0.5n/*s;
                //@(posedge clk*/ iff arst_n);

                
                if (LAB_MODE == 0)
                begin
                    /////////12th DATA + 2nd OUT
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_2.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_1.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 12: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 2: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 2a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 2b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                
                    /////////13th DATA + 3rd OUT
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 13: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
        
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 3: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 3a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 3b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////14th DATA + 4th OUT
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_2.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_1.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 14: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 4: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 4a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 4b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                
                    /////////15th DATA + 5th OUT
                    in_3SHARE[0] = B_3SHARES_POWEROFTWO_1.shared_data;
                    in_3SHARE[1] = B_3SHARES_POWEROFTWO_2.shared_data;
                    if (print_data == 1)
                    begin
                        $display("INPUT 15: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", in_3SHARE[0][0], in_3SHARE[0][1], in_3SHARE[0][2], unshare_3Boolean(in_3SHARE[0]), in_3SHARE[1][0], in_3SHARE[1][1], in_3SHARE[1][2], unshare_3Boolean(in_3SHARE[1]));
                    end
        
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 5: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 5a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 5b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    valid_data_3SHARE <= 1'b0;
                    
                    /////////6th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 6: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 6a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 6b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////7th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 7: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 7a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 7b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////8th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 8: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 8a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 8b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////9th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 9: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 9a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 9b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////10th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 10: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 10a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 10b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                end
                else
                begin
                    @(posedge clk iff arst_n);
                    valid_data_3SHARE <= 1'b0;
                    #1ns;
                    wait(valid_result_3SHARE);
                    //#1ns;
                    //valid_data_3SHARE <= 1'b0;
                    //#1ns;
                    //wait(valid_result_3SHARE);
                end
                
                /////////11th OUT
                @(posedge clk iff arst_n);
                long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                if (print_data == 1)
                begin
                    $display("OUTPUT 11: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                end
                assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 11a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                if (dual_mode)
                begin
                    assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 11b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                end

                if (LAB_MODE == 0)
                begin
                    /////////12th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 12: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 12a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 12b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end

                    /////////13th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 13: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 13a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 13b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////14th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 14: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 14a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 14b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                    
                    /////////15th OUT
                    @(posedge clk iff arst_n);
                    long_out[0] = unshare_3Boolean(B_3SHARES_POWEROFTWO_1.shared_data);
                    long_out[1] = unshare_3Boolean(B_3SHARES_POWEROFTWO_2.shared_data);
                    if (print_data == 1)
                    begin
                        $display("OUTPUT 15: {(%0d, %0d, %0d) = %0d} && {(%0d, %0d, %0d) = %0d}", out_3SHARE[0][0], out_3SHARE[0][1], out_3SHARE[0][2], unshare_3arithmetic(out_3SHARE[0]), out_2SHARE[1][0], out_2SHARE[1][1], out_3SHARE[1][2], unshare_3arithmetic(out_3SHARE[0]));
                    end
                    assert(long_out[0] == (unshare_3arithmetic(out_3SHARE[0]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 15a)", unshare_3arithmetic(out_3SHARE[0]), long_out[0], j); break; end
                    if (dual_mode)
                    begin
                        assert(long_out[1] == (unshare_3arithmetic(out_3SHARE[1]))) else begin $display("FIXME WRONG: real %0d != %0d expected (ITERATION %0d, TEST 8, INPUT 15b)", unshare_3arithmetic(out_3SHARE[1]), long_out[1], j); break; end
                    end
                end
                
                #1ns;
                ready_result_3SHARE <= 1'b0;
                conversion_mode <= 1'b0;

                $display("---------------------- TEST 8 CONCLUDED --------------------------");
            
            end
            
        end
    $finish();
  end

endmodule
