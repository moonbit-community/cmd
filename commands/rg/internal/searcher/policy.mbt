///|
// Strategy: rg-record-policy
// Configuration proofs are independent of record contents and buffer allocation.
// Keep reader policy separate from sink delivery: conversion/CRLF/heap limits
// can permit buffered counting while preventing irreversible streaming discard.
fn SearcherConfig::full_record_scan(self : SearcherConfig) -> Bool {
  !self.multi_line &&
  !self.invert_match &&
  self.max_matches is None &&
  self.max_context() == 0 &&
  !self.passthru &&
  !self.stop_on_nonmatch
}

///|
fn SearcherConfig::stream_count_term(self : SearcherConfig) -> Byte? {
  guard self.full_record_scan() &&
    self.heap_limit is None &&
    self.binary is BinaryNone &&
    self.line_term is Byte(term) else {
    return None
  }
  Some(term)
}

///|
let bulk_read_bytes : Int32 = 262144

///|
// Profitability probe only: matches in this bounded prefix decline streaming
// and are replayed, never reported as complete record results.
let stream_probe_prefix_bytes : Int32 = 65536

///|
let maximum_record_read_bytes : Int32 = 1048576

///|
fn Searcher::reader_capacity(self : Searcher, sink : &Sink) -> Int32 {
  let config = self.config
  let capacity = if config.full_record_scan() &&
    config.binary.quit_byte() is None &&
    (
      sink.bulk_scan() ||
      (sink.coalesce_matches() && config.binary is BinaryNone)
    ) {
    bulk_read_bytes
  } else {
    DEFAULT_BUFFER_CAPACITY
  }
  match config.heap_limit {
    Some(limit) => capacity.min(limit)
    None => capacity
  }
}

///|
priv enum LineExecution {
  Count((Int64) -> Unit)
  Coalesced(((Searcher, SinkMatch) -> Bool)?)
  Synchronous((Searcher, SinkMatch) -> Bool)
  Buffered((Searcher, SinkMatch) -> Bool raise)
  Ordinary
}

///|
fn SearcherConfig::line_execution(
  self : SearcherConfig,
  sink : &Sink,
  scan_binary : Bool,
) -> LineExecution {
  guard !scan_binary else { return Ordinary }
  let synchronous = if !self.invert_match &&
    self.max_context() == 0 &&
    !self.stop_on_nonmatch {
    sink.synchronous_matched()
  } else {
    None
  }
  if self.full_record_scan() {
    if self.binary.quit_byte() is None &&
      sink.synchronous_count() is Some(accept) {
      return Count(accept)
    }
    if !self.line_number && sink.coalesce_matches() {
      return Coalesced(synchronous)
    }
  }
  if !self.invert_match &&
    self.max_context() == 0 &&
    !self.stop_on_nonmatch &&
    sink.buffered_matched() is Some(accept) {
    return Buffered(accept)
  }
  match synchronous {
    Some(accept) => Synchronous(accept)
    None => Ordinary
  }
}

///|
fn LineExecution::after_binary(self : LineExecution) -> LineExecution {
  match self {
    Coalesced(Some(accept)) => Synchronous(accept)
    Coalesced(None) => Ordinary
    _ => self
  }
}

///|
fn record_scan_proof(
  matcher : &@matcher.Matcher,
  term : @matcher.LineTerminator,
) -> Bool {
  if matcher.line_terminator() is Some(lt) {
    if lt.as_byte() == b'\x00' {
      return false
    }
    if lt == term {
      return true
    }
  }
  matcher.non_matching_bytes() is Some(bytes) && bytes.contains(term.as_byte())
}
