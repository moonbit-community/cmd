///|
/// Persist domain chains in the fixed GNU Wget Linux profile's table order.
/// Resizing replays occupied slots, so sorting final domain hashes is not enough.
struct CookieDomains {
  mut cells : Array[String?]
  mut count : Int32
}

///|
fn CookieDomains::new() -> CookieDomains {
  { cells: Array::make(13, None), count: 0, }
}

///|
fn cookie_domain_hash(domain : String) -> UInt32 {
  let mut hash = 0U
  for character in cookie_ascii_lower(domain) {
    let byte = character.to_int()
    let signed = if byte >= 128 { byte - 256 } else { byte }
    hash = hash * 31U + signed.reinterpret_as_uint()
  }
  hash
}

///|
fn CookieDomains::position(self : CookieDomains, domain : String) -> Int32 {
  let mut position = (cookie_domain_hash(domain) %
  self.cells.length().reinterpret_as_uint()).reinterpret_as_int()
  while self.cells[position] is Some(old) {
    if cookie_ascii_lower(old) == cookie_ascii_lower(domain) {
      break
    }
    position = (position + 1) % self.cells.length()
  }
  position
}

///|
fn CookieDomains::insert(self : CookieDomains, domain : String) -> Unit {
  let mut position = self.position(domain)
  if self.cells[position] is Some(_) {
    return
  }
  if self.count.to_int64() >= self.cells.length().to_int64() * 3L / 4L {
    let sizes = [
      13, 19, 29, 41, 59, 79, 107, 149, 197, 263, 347, 457, 599, 787, 1031, 1361,
      1777, 2333, 3037, 3967, 5167, 6719, 8737, 11369, 14783, 19219, 24989, 32491,
      42257, 54941, 71429, 92861, 120721, 156941, 204047, 265271, 344857, 448321,
      582821, 757693, 985003, 1280519, 1664681, 2164111, 2813353, 3657361, 4754591,
      6180989, 8035301, 10445899, 13579681, 17653589, 22949669, 29834603, 38784989,
      50420551, 65546729, 85210757, 110774011, 144006217, 187208107, 243370577, 316381771,
      411296309, 534685237, 695090819, 903618083, 1174703521, 1527114613, 1837299131,
      2147483647,
    ]
    let minimum = self.cells.length().to_int64() * 2L
    let next = sizes
      .iter()
      .find_first(size => size.to_int64() >= minimum)
      .unwrap()
    let old = self.cells
    self.cells = Array::make(next, None)
    for cell in old {
      if cell is Some(key) {
        self.cells[self.position(key)] = Some(key)
      }
    }
    position = self.position(domain)
  }
  self.cells[position] = Some(domain)
  self.count += 1
}

///|
fn CookieDomains::remove(self : CookieDomains, domain : String) -> Unit {
  let position = self.position(domain)
  if self.cells[position] is None {
    return
  }
  self.cells[position] = None
  self.count -= 1
  let mut current = (position + 1) % self.cells.length()
  while self.cells[current] is Some(key) {
    let destination = self.position(key)
    if destination != current {
      self.cells[destination] = Some(key)
      self.cells[current] = None
    }
    current = (current + 1) % self.cells.length()
  }
}
