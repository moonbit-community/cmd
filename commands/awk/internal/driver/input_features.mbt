///|
fn identifier_unit(unit : UInt16) -> Bool {
  (unit >= 0x41 && unit <= 0x5a) ||
  (unit >= 0x61 && unit <= 0x7a) ||
  (unit >= 0x30 && unit <= 0x39) ||
  unit == 0x5f
}

///|
// The evaluator offers both record-at-a-time and synchronous pull interfaces.
// Prefer streaming unless an identifier can observe a record separator or read
// main input. A possible identifier inside a literal can conservatively select pull.
fn input_features(program : String) -> (Bool, Bool, Bool) {
  let mut record_separator = false
  let mut main_getline = false
  let mut redirect_stdin = false
  let mut i = 0
  while i < program.length() {
    if !identifier_unit(program[i]) {
      i += 1
      continue
    }
    let start = i
    while i < program.length() && identifier_unit(program[i]) {
      i += 1
    }
    match program[start:i] {
      "RS" | "RT" | "INPUTMODE" => record_separator = true
      "getline" => {
        let mut at = i
        while at < program.length() &&
              (program[at] == 0x20 || program[at] == 0x09) {
          at += 1
        }
        while at < program.length() && identifier_unit(program[at]) {
          at += 1
        }
        while at < program.length() &&
              (program[at] == 0x20 || program[at] == 0x09) {
          at += 1
        }
        if at >= program.length() || program[at] != 0x3c {
          main_getline = true
        } else {
          at += 1
          while at < program.length() &&
                (program[at] == 0x20 || program[at] == 0x09) {
            at += 1
          }
          let source = program[at:]
          if !source.has_prefix("\"") ||
            source.has_prefix("\"-\"") ||
            source.has_prefix("\"/dev/stdin\"") {
            redirect_stdin = true
          }
        }
      }
      _ => ()
    }
  }
  (record_separator, main_getline, redirect_stdin)
}
