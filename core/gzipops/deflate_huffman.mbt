///|
priv struct DeflateCode {
  bits : UInt32
  length : Int32
}

///|
priv struct DeflateHuffmanItem {
  weight : Int64
  symbol : Int32
  left : Int32
  right : Int32
}

///|
// Binary package-merge, with at most 286 symbols and 15 levels. Each selected
// occurrence of a leaf contributes one code bit. The final list has width 1/2,
// so selecting 2*n-2 items gives the required total width n-1.
// Larmore and Hirschberg, JACM 37 (1990), sections 2-3:
// https://web.cs.unlv.edu/larmore/Research/larHir90.pdf
fn deflate_code_lengths(
  frequencies : Array[Int32],
  max_bits : Int32,
) -> Array[Int32] {
  let items : Array[DeflateHuffmanItem] = []
  let leaves : Array[Int32] = []
  for symbol, frequency in frequencies {
    if frequency > 0 {
      leaves.push(items.length())
      items.push({ weight: frequency.to_int64(), symbol, left: -1, right: -1, })
    }
  }
  // Complete two-leaf trees also cover empty and singleton alphabets. The
  // smallest unused symbols are dummies and never enter payload frequencies.
  let mut symbol = 0
  while leaves.length() < 2 {
    if frequencies[symbol] == 0 {
      leaves.push(items.length())
      items.push({ weight: 1L, symbol, left: -1, right: -1, })
    }
    symbol += 1
  }
  leaves.sort_by((left, right) => {
    let a = items[left]
    let b = items[right]
    if a.weight < b.weight {
      -1
    } else if a.weight > b.weight {
      1
    } else {
      a.symbol - b.symbol
    }
  })
  let mut list = leaves.copy()
  for _ in 1..<max_bits {
    let packages : Array[Int32] = []
    for pair in 0..<(list.length() / 2) {
      let left = list[pair * 2]
      let right = list[pair * 2 + 1]
      packages.push(items.length())
      items.push({
        weight: items[left].weight + items[right].weight,
        symbol: -1,
        left,
        right,
      })
    }
    let merged : Array[Int32] = []
    let mut leaf = 0
    let mut package_index = 0
    while leaf < leaves.length() && package_index < packages.length() {
      if items[leaves[leaf]].weight <= items[packages[package_index]].weight {
        merged.push(leaves[leaf])
        leaf += 1
      } else {
        merged.push(packages[package_index])
        package_index += 1
      }
    }
    merged.append(leaves[leaf:])
    merged.append(packages[package_index:])
    list = merged
  }
  let lengths = Array::make(frequencies.length(), 0)
  let pending = list[:leaves.length() * 2 - 2].to_owned()
  while pending.pop() is Some(index) {
    let item = items[index]
    if item.symbol >= 0 {
      lengths[item.symbol] += 1
    } else {
      pending.push(item.left)
      pending.push(item.right)
    }
  }
  lengths
}

///|
fn deflate_reverse_bits(value : UInt32, width : Int32) -> UInt32 {
  let mut value = value
  let mut result = 0U
  for _ in 0..<width {
    result = (result << 1) | (value & 1U)
    value = value >> 1
  }
  result
}

///|
fn deflate_codes(lengths : Array[Int32]) -> Array[DeflateCode] {
  let counts = Array::make(16, 0U)
  for length in lengths {
    if length > 0 {
      counts[length] += 1U
    }
  }
  let next = Array::make(16, 0U)
  let mut code = 0U
  for width in 1..<=15 {
    code = (code + counts[width - 1]) << 1
    next[width] = code
  }
  lengths.map(length => {
    let bits = deflate_reverse_bits(next[length], length)
    if length > 0 {
      next[length] += 1U
    }
    { bits, length, }
  })
}
