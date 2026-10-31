///|
// Refine only the byte classes actually used by the source automaton. Both
// immediate acceptance and EOF acceptance are observations of this machine.
// A bounded construction failure leaves the original rows intact.
fn minimize_boolean_rows(
  table : FixedArray[Int32],
  eof : FixedArray[Bool],
  start : Int32,
  accept : Int32,
  alphabet : Array[Int32],
  budget~ : Int32 = boolean_refinement_work_limit,
) -> (FixedArray[Int32], FixedArray[Bool], Int32, Int32)? {
  let states = eof.length()
  let width = alphabet.length() + 2
  let mut work = 0
  let mut groups = FixedArray::makei(states, state => {
    if state * 256 == accept {
      2
    } else if eof[state] {
      1
    } else {
      0
    }
  })
  let mut count = 0
  let mut stable = false
  for _round in 0..<boolean_refinement_round_limit {
    if budget - work < states * width {
      return None
    }
    work += states * width
    let signatures : Map[Bytes, Int32] = Map([])
    let next = FixedArray::make(states, 0)
    count = 0
    for state in 0..<states {
      let signature = Bytes::makei(2 * width, i => {
        let component = i / 2
        let value = if component == 0 {
          if state * 256 == accept {
            1
          } else {
            0
          }
        } else if component == 1 {
          if eof[state] {
            1
          } else {
            0
          }
        } else {
          groups[table[state * 256 + alphabet[component - 2]] / 256]
        }
        (if i % 2 == 0 { value & 255 } else { value >> 8 }).to_byte()
      })
      next[state] = match signatures.get(signature) {
        Some(group) => group
        None => {
          let group = count
          count += 1
          signatures[signature] = group
          group
        }
      }
    }
    if next == groups {
      stable = true
      break
    }
    groups = next
  }
  if !stable {
    return None
  }
  if count == states {
    return Some((table, eof, start, accept))
  }
  let representatives = FixedArray::make(count, -1)
  for state in 0..<states {
    representatives[groups[state]] = state
  }
  let reduced = FixedArray::makei(count * 256, i => {
    let state = representatives[i / 256]
    groups[table[state * 256 + i % 256] / 256] * 256
  })
  let reduced_eof = FixedArray::makei(count, i => eof[representatives[i]])
  Some(
    (
      reduced,
      reduced_eof,
      groups[start / 256] * 256,
      groups[accept / 256] * 256,
    ),
  )
}
