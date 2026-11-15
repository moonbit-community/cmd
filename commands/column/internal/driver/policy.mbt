///|
// Metadata budgets, independent of disk pages and retained record payloads.
const FIELD_PLAN_BYTE_LIMIT : Int32 = 65536

///|
const FIELD_PLAN_ROW_LIMIT : Int32 = 128

///|
const FIELD_PLAN_DATA_DIVISOR : Int32 = 8

///|
// Profitability threshold: shorter rows keep ordinary field traversal.
const FIELD_PLAN_MIN_ROW_BYTES : Int32 = 1024
