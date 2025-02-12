# X2X
This repository contains SystemVerilog code of the masked X2X (A2B\B2A) accelerator for lattice-based cryptography.\
Our implementation is based on the techniques described in our paper 'X2X: Low-Randomness and High-Throughput A2B and B2A Conversions for d+1 shares in Hardware' [[ePrint]](https://eprint.iacr.org/2024/114).

## Contents

* [X2X Systemverilog Sources](src)
* [X2X Testbench + PRNG example](src_tb)

## Running, Testing and Benchmarking
Choose and set the following parameters when instantiation the module `MaskConversion_HALFCYCLE_STREAM` ([top file](src/MaskConversion_HALFCYCLE_STREAM.sv)):
* `HALFCYLE`
    + `0`: halfcycle-paths disabled
    + `1`: halfcycle-paths enabled
* `PARAM_WIDTH`
    + `13` : for ML-KEM support (q = 3329)
* `N_SHARES`
    + `2` : first-order masking
    + `3` : second-order masking
* `RND_SHARES`
    + see [MaskConv_HALF_STREAM_tb](src_tb/MaskConv_HALF_STREAM_tb.sv) for details of 2- and 3-share variants
* `RND_SHARES_8bit`
    + see [MaskConv_HALF_STREAM_tb](src_tb/MaskConv_HALF_STREAM_tb.sv) for details of 2- and 3-share variants

The top-level module has a simple AXI-type interface with ready/valid handshaking:
* `valid_data`, `ready_data`, `valid_result`, `ready_result`
The fresh randomness, required during the computation, should be supplied with the input data (same handshake):
* `fresh_rnd_shares` and `fresh_rnd_shares_8bit`
We include a [PRNG](src_tb/PRNG_engine_STREAM.sv) example, which should be seeded, and supplies correctly formatted randomness for the design.

Additionally, the following wires can be set to change the mode of operation (at runtime):
* `conversion_mode`
    + `0` : A2B
    + `1` : B2A
* `data_type_mode`
    + `0` : mod power-of-two (2^k)
    + `1` : mod prime (q)
* `dual_mode` (ONLY for power-of-two mode)
    + `0` : disabled
    + `1` : enabled, supply 2 coefficients at `original_data` and `fresh_rnd_shares`/`fresh_rnd_shares_8bit` ports

## Bibliography
If you use or build upon the code in this repository, please cite our paper using our [citation key](CITATION).
