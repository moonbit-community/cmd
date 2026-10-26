///|
/// The grapheme cluster regex used by `bstr` (derived from UAX #29, Table
/// 1c). `bstr` compiles it to a DFA ahead of time; we compile it with our
/// own regex engine on first use.
let grapheme_pattern : String =
  #|(?x)
  #|\p{gcb=CR}\p{gcb=LF}
  #||
  #|\p{gcb=Control}
  #||
  #|\p{gcb=Prepend}*
  #|(
  #|  (
  #|    (\p{gcb=L}*(\p{gcb=V}+|\p{gcb=LV}\p{gcb=V}*|\p{gcb=LVT})\p{gcb=T}*)
  #|    |
  #|    \p{gcb=L}+
  #|    |
  #|    \p{gcb=T}+
  #|  )
  #|  |
  #|  \p{gcb=RI}\p{gcb=RI}
  #|  |
  #|  \p{Extended_Pictographic}(\p{gcb=Extend}*\p{gcb=ZWJ}\p{Extended_Pictographic})*
  #|  |
  #|  [^\p{gcb=Control}\p{gcb=CR}\p{gcb=LF}]
  #|)
  #|[\p{gcb=Extend}\p{gcb=ZWJ}\p{gcb=SpacingMark}]*
  #||
  #|\p{any}

///|
priv struct GraphemeMatcher {
  dfa : @automata.LazyDFA
  pikevm : @automata.PikeVM
}

///|
let grapheme_matcher : Ref[GraphemeMatcher?] = Ref(None)

///|
fn get_grapheme_matcher() -> GraphemeMatcher {
  match grapheme_matcher.val {
    Some(m) => m
    None => {
      let hir = @syntax.parse(grapheme_pattern) catch {
        e => abort("invalid grapheme regex: \{e}")
      }
      let nfa = @automata.compile_nfa(hir) catch {
        _ => abort("failed to compile grapheme regex")
      }
      let m = {
        dfa: @automata.LazyDFA::new(nfa),
        pikevm: @automata.PikeVM::new(nfa),
      }
      grapheme_matcher.val = Some(m)
      m
    }
  }
}

///|
/// Returns the length of the first grapheme cluster in `buf[start:end]`,
/// following `bstr::decode_grapheme`. Invalid UTF-8 is treated as a single
/// replacement codepoint covering the maximal invalid subsequence. Returns
/// `0` only if the input is empty.
fn decode_grapheme_len(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32 {
  if start >= end {
    return 0
  }
  if end - start >= 2 &&
    buf[start] < b'\x80' &&
    buf[start + 1] < b'\x80' &&
    !(buf[start] is (b' ' | b'\t' | b'\n' | b'\x0C' | b'\r')) {
    return 1
  }
  let m = get_grapheme_matcher()
  let e = m.dfa.find_fwd(buf, start, end, start, end, true, false)
  let e = if e == @automata.DFA_FAILED {
    let slots = FixedArray::make(2, -1)
    if m.pikevm.search_slots(buf, start, end, start, end, true, false, slots) {
      slots[1]
    } else {
      -1
    }
  } else {
    e
  }
  if e > start {
    e - start
  } else {
    utf8_decode_lossy_len(buf, start, end)
  }
}

///|
/// Returns the number of bytes consumed by decoding one codepoint (or one
/// maximal invalid subsequence) at `buf[start:end]`, like
/// `bstr::decode_lossy`.
fn utf8_decode_lossy_len(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32 {
  if start >= end {
    return 0
  }
  let b0 = buf[start].to_int()
  if b0 < 0x80 {
    return 1
  }
  let (need, lo, hi) = if b0 >= 0xC2 && b0 <= 0xDF {
    (1, 0x80, 0xBF)
  } else if b0 == 0xE0 {
    (2, 0xA0, 0xBF)
  } else if b0 >= 0xE1 && b0 <= 0xEC {
    (2, 0x80, 0xBF)
  } else if b0 == 0xED {
    (2, 0x80, 0x9F)
  } else if b0 >= 0xEE && b0 <= 0xEF {
    (2, 0x80, 0xBF)
  } else if b0 == 0xF0 {
    (3, 0x90, 0xBF)
  } else if b0 >= 0xF1 && b0 <= 0xF3 {
    (3, 0x80, 0xBF)
  } else if b0 == 0xF4 {
    (3, 0x80, 0x8F)
  } else {
    return 1
  }
  let mut i = 1
  while i <= need {
    if start + i >= end {
      return i
    }
    let b = buf[start + i].to_int()
    let (l, h) = if i == 1 { (lo, hi) } else { (0x80, 0xBF) }
    if b < l || b > h {
      return i
    }
    i += 1
  }
  need + 1
}

///|
/// Returns the end offset (relative to `start`) of the `n`-th grapheme
/// cluster in `buf[start:end]`, or of the last one if there are fewer than
/// `n`. Returns `0` if `n == 0` or the input is empty. This mirrors
/// `bytes.grapheme_indices().map(|(_, end, _)| end).take(n).last()
/// .unwrap_or(0)`.
fn grapheme_end_after(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
  n : Int64,
) -> Int32 {
  let mut pos = start
  let mut count = 0L
  while count < n {
    let len = decode_grapheme_len(buf, pos, end)
    if len == 0 {
      break
    }
    pos += len
    count += 1
  }
  pos - start
}
