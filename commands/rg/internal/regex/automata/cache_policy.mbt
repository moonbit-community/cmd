///|
// Strategy: rg-lazy-cache
// Cache profitability is separate from syntax support. A Unicode quit never
// counts as cache pressure. Three failed fills must also amortize fewer than
// ten searched bytes per constructed row before this engine is retired.
const DFA_PRESSURE_CLEAR_LIMIT : Int32 = 3

///|
const DFA_MINIMUM_BYTES_PER_STATE : Int64 = 10L

///|
priv struct DfaWork {
  mut clears : Int32
  mut constructed : Int64
  mut searched : Int64
}

///|
priv enum DfaCacheHealth {
  Measuring(DfaWork)
  Retired
}

///|
fn LazyDfa::record_search(self : LazyDfa, bytes : Int32) -> Unit {
  if self.health is Measuring(work) {
    // Offset progress includes prefilter jumps: this deliberately overestimates
    // useful scanning and makes retirement conservative for sparse candidates.
    work.searched += bytes.to_int64()
    if work.clears >= DFA_PRESSURE_CLEAR_LIMIT {
      if work.searched < work.constructed * DFA_MINIMUM_BYTES_PER_STATE {
        self.health = Retired
      } else {
        // A productive window does not subsidize later repeatedly failed fills.
        work.clears = 0
        work.constructed = 0L
        work.searched = 0L
      }
    }
  }
}

///|
fn LazyDfa::clear_under_pressure(self : LazyDfa) -> Unit {
  if self.health is Measuring(work) {
    work.clears += 1
  }
  self.reset()
}

///|
// Keep the scan cursor local to the loop. Capturing it in a deferred closure
// makes every cursor update observable through a mutable cell on default Wasm.
#inline
fn LazyDfa::finish_search(
  self : LazyDfa,
  result : Int32,
  bytes : Int32,
) -> Int32 {
  self.record_search(bytes)
  result
}
