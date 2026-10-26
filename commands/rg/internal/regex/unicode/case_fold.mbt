///|
priv struct FoldTable {
  keys : Array[Int32]
  // Offsets into `values`: entry i maps to values[starts[i]:starts[i + 1]].
  starts : Array[Int32]
  values : Array[Int32]
}

///|
let fold_table_cache : Ref[FoldTable?] = Ref(None)

///|
fn fold_table() -> FoldTable {
  match fold_table_cache.val {
    Some(t) => t
    None => {
      let nums = decode_nums(case_folding_data)
      let keys = []
      let starts = []
      let values = []
      let mut prev = 0
      let mut i = 0
      while i < nums.length() {
        let k = prev + nums[i]
        let n = nums[i + 1]
        keys.push(k)
        starts.push(values.length())
        for j in 0..<n {
          values.push(nums[i + 2 + j])
        }
        prev = k
        i += 2 + n
      }
      starts.push(values.length())
      let t = { keys, starts, values, }
      fold_table_cache.val = Some(t)
      t
    }
  }
}

///|
fn fold_index(t : FoldTable, c : Int32) -> Int32? {
  let mut lo = 0
  let mut hi = t.keys.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let k = t.keys[mid]
    if k == c {
      return Some(mid)
    } else if k < c {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  None
}

///|
/// Returns all scalar values that are simple case equivalents of `c`
/// (excluding `c` itself).
pub fn simple_fold(c : Int32) -> Array[Int32] {
  let t = fold_table()
  match fold_index(t, c) {
    None => []
    Some(i) => t.values[t.starts[i]:t.starts[i + 1]].to_owned()
  }
}

///|
/// Returns true if any scalar value in `start..=end` has a simple case
/// folding mapping.
pub fn fold_overlaps(start : Int32, end : Int32) -> Bool {
  let t = fold_table()
  let mut lo = 0
  let mut hi = t.keys.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let k = t.keys[mid]
    if k >= start && k <= end {
      return true
    } else if k > end {
      hi = mid
    } else {
      lo = mid + 1
    }
  }
  false
}

///|
/// Calls `f` with each key in the table within `start..=end` and its
/// mappings. Used to apply case folding to large ranges efficiently.
pub fn each_fold_in_range(
  start : Int32,
  end : Int32,
  f : (Int32, ArrayView[Int32]) -> Unit,
) -> Unit {
  let t = fold_table()
  // find first key >= start
  let mut lo = 0
  let mut hi = t.keys.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if t.keys[mid] < start {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  for i = lo; i < t.keys.length() && t.keys[i] <= end; i = i + 1 {
    f(t.keys[i], t.values[t.starts[i]:t.starts[i + 1]])
  }
}
