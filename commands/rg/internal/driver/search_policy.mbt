///|
// Profitability thresholds, not syntax or correctness limits. Density only
// selects a verifier; necessary-literal rejection remains active afterwards.
const BOOLEAN_MIN_BLOCK_BYTES : Int32 = 4096

///|
const BOOLEAN_ORDINARY_BLOCK_BYTES : Int32 = 262144

///|
const BOOLEAN_DENSITY_SAMPLES : Int32 = 8

///|
const BOOLEAN_DENSITY_WINDOW_BYTES : Int32 = 4096

///|
// The bounded literal cursor retains at most length - 1 bytes across chunks.
const LITERAL_STREAM_MAX_BYTES : Int32 = 4096
