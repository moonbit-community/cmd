///|
// Construction budgets count states or table entries, not process memory.
const BOOLEAN_NFA_STATE_LIMIT : Int32 = 512

///|
const BOOLEAN_DFA_STATE_LIMIT : Int32 = 256

///|
const BOOLEAN_TABLE_ENTRY_LIMIT : Int32 = 65536

///|
const BOOLEAN_REFINEMENT_WORK_LIMIT : Int32 = 65536

///|
const BOOLEAN_REFINEMENT_ROUND_LIMIT : Int32 = 32

///|
// Measured profitability guards; neither establishes a match nor skips exits.
const BOOLEAN_PROBE_WINDOW_BYTES : Int32 = 64

///|
const BOOLEAN_SPARSE_EXIT_BYTES : Int32 = 32
