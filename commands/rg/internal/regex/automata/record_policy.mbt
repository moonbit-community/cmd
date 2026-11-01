///|
// Construction budgets count states or table entries, not process memory.
let boolean_nfa_state_limit : Int32 = 512

///|
let boolean_dfa_state_limit : Int32 = 256

///|
let boolean_table_entry_limit : Int32 = 65536

///|
let boolean_refinement_work_limit : Int32 = 65536

///|
let boolean_refinement_round_limit : Int32 = 32

///|
// Measured profitability guards; neither establishes a match nor skips exits.
let boolean_probe_window_bytes : Int32 = 64

///|
let boolean_sparse_exit_bytes : Int32 = 32
