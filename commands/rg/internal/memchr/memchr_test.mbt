///|
fn naive_find(
  hay : FixedArray[Byte],
  needle : FixedArray[Byte],
  s : Int32,
  e : Int32,
) -> Int32 {
  let n = needle.length()
  for i = s; i + n <= e; i = i + 1 {
    let mut ok = true
    for j in 0..<n {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
  }
  -1
}

///|
fn gen(len : Int32, seed : Int32) -> FixedArray[Byte] {
  let a = FixedArray::make(len, b'\x00')
  let mut x = seed.reinterpret_as_uint() + 12345
  for i in 0..<len {
    x = x * 1103515245 + 12345
    // A small alphabet makes matches and near-matches common.
    a[i] = (b'a'.to_int() + ((x >> 16) % 4).reinterpret_as_int()).to_byte()
  }
  a
}

///|
test "memchr family agrees with scalar search" {
  for len in [0, 1, 15, 16, 17, 31, 32, 33, 100, 257] {
    let hay = gen(len, len)
    for s in [0, 1, 3] {
      for e in [len, len - 1, len - 5] {
        if s > e || e < 0 {
          continue
        }
        for b in [b'a', b'b', b'd', b'z'] {
          let mut first = -1
          let mut last = -1
          let mut cnt = 0
          for i in s..<e {
            if hay[i] == b {
              if first < 0 {
                first = i
              }
              last = i
              cnt += 1
            }
          }
          assert_eq(@memchr.memchr(b, hay, s, e), first)
          assert_eq(@memchr.memrchr(b, hay, s, e), last)
          assert_eq(@memchr.count(b, hay, s, e), cnt)
          let mut f2 = -1
          let mut f3 = -1
          for i in s..<e {
            if f2 < 0 && (hay[i] == b || hay[i] == b'z') {
              f2 = i
            }
            if f3 < 0 && (hay[i] == b || hay[i] == b'z' || hay[i] == b'c') {
              f3 = i
            }
          }
          assert_eq(@memchr.memchr2(b, b'z', hay, s, e), f2)
          assert_eq(@memchr.memchr3(b, b'z', b'c', hay, s, e), f3)
        }
      }
    }
  }
}

///|
test "finder agrees with naive search" {
  for len in [0, 5, 16, 40, 200, 1000] {
    let hay = gen(len, len + 7)
    for nlen in [1, 2, 3, 5, 9, 20] {
      for off in [0, 3, 50] {
        if off + nlen > len {
          continue
        }
        let needle = FixedArray::make(nlen, b'\x00')
        for j in 0..<nlen {
          needle[j] = hay[off + j]
        }
        for (i1, i2) in [(0, nlen - 1), (nlen / 2, 0), (0, 0)] {
          let f = @memchr.Finder::new(needle, i1, i2)
          for s in [0, 2] {
            assert_eq(f.find(hay, s, len), naive_find(hay, needle, s, len))
          }
        }
      }
    }
  }
  // An absent needle.
  let hay = gen(500, 1)
  let f = @memchr.Finder::new([b'x', b'y', b'z'], 0, 2)
  assert_eq(f.find(hay, 0, 500), -1)
}

///|
test "pair set agrees with scalar check" {
  let hay = gen(300, 3)
  let s1 : Array[Byte] = [b'a', b'c']
  let s2 : Array[Byte] = [b'b']
  for (o1, o2) in [(0, 1), (2, 0), (1, 1), (3, 5)] {
    let ps = @memchr.PairSet::new(o1, s1, o2, s2)
    let maxo = if o1 > o2 { o1 } else { o2 }
    for start in [0, 7, 290] {
      let limit = 300 - maxo
      let mut want = -1
      for i in start..<limit {
        if s1.contains(hay[i + o1]) && s2.contains(hay[i + o2]) {
          want = i
          break
        }
      }
      assert_eq(ps.find(hay, start, limit), want)
    }
  }
}

///|
fn naive_multi(
  hay : FixedArray[Byte],
  lits : Array[FixedArray[Byte]],
  s : Int32,
  e : Int32,
) -> (Int32, Int32)? {
  for i in s..<e {
    for l in lits {
      if naive_find(hay, l, i, e) == i {
        return Some((i, i + l.length()))
      }
    }
  }
  None
}

///|
test "teddy agrees with naive multi-literal search" {
  let hay = gen(2000, 9)
  let mut seed = 1
  for nlits in [1, 2, 3, 8, 9, 20, 64] {
    for minl in [1, 2, 3, 5] {
      let lits : Array[FixedArray[Byte]] = []
      for _ in 0..<nlits {
        seed = seed + 1
        let len = minl + seed % 3
        let off = seed * 37 % (2000 - 10)
        // Mostly literals taken from the haystack, sometimes random ones.
        let l = if seed % 4 == 0 {
          gen(len, seed)
        } else {
          FixedArray::makei(len, j => hay[off + j])
        }
        lits.push(l)
      }
      let t = @memchr.Teddy::new(lits).unwrap()
      for s in [0, 5, 1990] {
        for e in [2000, 1500] {
          if s <= e {
            assert_eq(t.find(hay, s, e), naive_multi(hay, lits, s, e))
          }
        }
      }
    }
  }
}
