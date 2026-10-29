///|
// Strategy: bytere-anchored-linear
// Strategy: grep-general-onepass-rejected
// A bounded, branch-free program with a leading Begin assertion has exactly
// one candidate start. Resolve it directly on bytes for boolean record queries.
fn Pattern::is_anchored_linear(self : Pattern) -> Bool {
  if self.backreferences || self.program.length() > 256 {
    return false
  }
  let mut pc = self.entry
  let mut anchored = false
  let mut consumed = false
  for _ in 0..<self.program.length() {
    match self.program[pc] {
      Accept => return anchored
      Assert(Begin, next) => {
        if !consumed {
          anchored = true
        }
        pc = next
      }
      Assert(End, next) | Save(_, next) | SaveOptional(_, next) => pc = next
      Byte(_, next) | Class(_, next) | Any(next) => {
        consumed = true
        pc = next
      }
      _ => return false
    }
  }
  false
}

///|
fn Pattern::matches_anchored_linear(self : Pattern, value : BytesView) -> Bool {
  let mut pc = self.entry
  let mut at = 0
  for ;; {
    match self.program[pc] {
      Accept => return true
      Byte(byte, next) => {
        if at == value.length() || value[at].to_int() != byte {
          return false
        }
        at += 1
        pc = next
      }
      Class(members, next) => {
        if at == value.length() || !members[value[at].to_int()] {
          return false
        }
        at += 1
        pc = next
      }
      Any(next) => {
        if at == value.length() {
          return false
        }
        at += 1
        pc = next
      }
      Assert(Begin, next) => {
        if at != 0 {
          return false
        }
        pc = next
      }
      Assert(End, next) => {
        if at != value.length() {
          return false
        }
        pc = next
      }
      Save(_, next) | SaveOptional(_, next) => pc = next
      _ => abort("unsupported instruction in anchored linear record plan")
    }
  }
}
