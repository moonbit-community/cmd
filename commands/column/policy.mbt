///|
// Metadata budgets, independent of disk pages and retained record payloads.
let field_plan_byte_limit : Int32 = 65536

///|
let field_plan_row_limit : Int32 = 128

///|
let field_plan_data_divisor : Int32 = 8

///|
// Profitability threshold: shorter rows keep ordinary field traversal.
let field_plan_min_row_bytes : Int32 = 1024

///|
let field_plan_initial_bytes : Int32 = 1024

///|
// Three little-endian Int32 values: start, end, display width.
let field_plan_entry_bytes : Int32 = 12
