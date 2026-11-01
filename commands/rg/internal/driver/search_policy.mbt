///|
// Profitability thresholds, not syntax or correctness limits. Density only
// selects a verifier; necessary-literal rejection remains active afterwards.
let boolean_min_block_bytes : Int32 = 4096

///|
let boolean_ordinary_block_bytes : Int32 = 262144

///|
let boolean_density_samples : Int32 = 8

///|
let boolean_density_window_bytes : Int32 = 4096

///|
// The bounded literal cursor retains at most length - 1 bytes across chunks.
let literal_stream_max_bytes : Int32 = 4096
