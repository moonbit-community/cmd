///|
// Strategy: grep-execution
// Output policy is selected once. Binary detection remains a dynamic input gate.
priv enum GrepExecution {
  Summary(Bool)
  Records
  BatchedRecords
  MatchSpans
}

///|
fn GrepOptions::execution(
  self : GrepOptions,
  prefix_filename : Bool,
) -> GrepExecution {
  if self.count ||
    self.files_with_matches ||
    self.files_without_match ||
    self.quiet {
    return Summary(!self.quiet && !self.files_with_matches)
  }
  if self.only_matching && !self.invert {
    return MatchSpans
  }
  if !self.only_matching &&
    !self.context_enabled &&
    !self.line_number &&
    !self.byte_offset &&
    !prefix_filename {
    return BatchedRecords
  }
  Records
}

///|
// Complete buffered records share one accounting boundary. Cross-chunk next()
// accounts bytes as they arrive and deliberately keeps its separate error path.
#inline
fn GrepInput::consume_records(
  self : GrepInput,
  end : Int32,
  records : Int64,
) -> Unit {
  self.offset += (end - self.position).to_int64()
  self.position = end
  self.number += records
}
