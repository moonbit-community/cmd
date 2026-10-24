///|
priv struct DeflateTable {
  literal : Array[DeflateCode]
  distance : Array[DeflateCode]
}

///|
priv struct DeflateRun {
  symbol : Int32
  extra : UInt32
  width : Int32
}

///|
priv struct DeflateDynamic {
  table : DeflateTable
  literal_count : Int32
  distance_count : Int32
  code_count : Int32
  code_lengths : Array[Int32]
  codes : Array[DeflateCode]
  runs : Array[DeflateRun]
  header_bits : Int32
}

///|
let deflate_code_order : ReadOnlyArray[Int32] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
fn deflate_fixed_table() -> DeflateTable {
  {
    literal: deflate_codes(
      Array::makei(288, symbol => {
        if symbol < 144 {
          8
        } else if symbol < 256 {
          9
        } else if symbol < 280 {
          7
        } else {
          8
        }
      }),
    ),
    distance: deflate_codes(Array::make(32, 5)),
  }
}

///|
fn DeflateBits::code(self : DeflateBits, code : DeflateCode) -> Unit {
  self.put(code.bits, code.length)
}

///|
fn deflate_token_bits(
  table : DeflateTable,
  tokens : Array[DeflateToken],
) -> Int32? {
  let mut total = table.literal[256].length
  for token in tokens {
    match token {
      Literal(byte) => {
        let code = table.literal[byte.to_int()]
        if code.length == 0 {
          return None
        }
        total += code.length
      }
      Copy(length, distance) => {
        let literal = deflate_length_symbol(length)
        let dist = deflate_distance_symbol(distance)
        if table.literal[literal].length == 0 ||
          table.distance[dist].length == 0 {
          return None
        }
        total += table.literal[literal].length +
          length_extra[literal - 257] +
          table.distance[dist].length +
          distance_extra[dist]
      }
    }
  }
  Some(total)
}

///|
fn DeflateBits::tokens(
  self : DeflateBits,
  table : DeflateTable,
  tokens : Array[DeflateToken],
) -> Unit {
  for token in tokens {
    match token {
      Literal(byte) => self.code(table.literal[byte.to_int()])
      Copy(length, distance) => {
        let literal = deflate_length_symbol(length)
        let dist = deflate_distance_symbol(distance)
        self.code(table.literal[literal])
        self.put(
          (length - length_base[literal - 257]).reinterpret_as_uint(),
          length_extra[literal - 257],
        )
        self.code(table.distance[dist])
        self.put(
          (distance - distance_base[dist]).reinterpret_as_uint(),
          distance_extra[dist],
        )
      }
    }
  }
}

///|
fn deflate_length_runs(lengths : Array[Int32]) -> Array[DeflateRun] {
  let runs : Array[DeflateRun] = []
  let mut index = 0
  while index < lengths.length() {
    let value = lengths[index]
    let mut end = index + 1
    while end < lengths.length() && lengths[end] == value {
      end += 1
    }
    let mut count = end - index
    if value == 0 {
      while count >= 11 {
        let repeated = count.min(138)
        runs.push({
          symbol: 18,
          extra: (repeated - 11).reinterpret_as_uint(),
          width: 7,
        })
        count -= repeated
      }
      if count >= 3 {
        runs.push({
          symbol: 17,
          extra: (count - 3).reinterpret_as_uint(),
          width: 3,
        })
        count = 0
      }
    } else {
      runs.push({ symbol: value, extra: 0U, width: 0, })
      count -= 1
      while count >= 3 {
        let repeated = count.min(6)
        runs.push({
          symbol: 16,
          extra: (repeated - 3).reinterpret_as_uint(),
          width: 2,
        })
        count -= repeated
      }
    }
    for _ in 0..<count {
      runs.push({ symbol: value, extra: 0U, width: 0, })
    }
    index = end
  }
  runs
}

///|
fn deflate_dynamic(tokens : Array[DeflateToken]) -> DeflateDynamic {
  let literal_frequencies = Array::make(286, 0)
  let distance_frequencies = Array::make(30, 0)
  literal_frequencies[256] = 1
  for token in tokens {
    match token {
      Literal(byte) => literal_frequencies[byte.to_int()] += 1
      Copy(length, distance) => {
        literal_frequencies[deflate_length_symbol(length)] += 1
        distance_frequencies[deflate_distance_symbol(distance)] += 1
      }
    }
  }
  let literal = deflate_code_lengths(literal_frequencies, 15)
  let distance = deflate_code_lengths(distance_frequencies, 15)
  let mut literal_count = literal.length()
  while literal_count > 257 && literal[literal_count - 1] == 0 {
    literal_count -= 1
  }
  let mut distance_count = distance.length()
  while distance_count > 1 && distance[distance_count - 1] == 0 {
    distance_count -= 1
  }
  let sequence = literal[:literal_count].to_owned()
  sequence.append(distance[:distance_count])
  let runs = deflate_length_runs(sequence)
  let frequencies = Array::make(19, 0)
  for run in runs {
    frequencies[run.symbol] += 1
  }
  let code_lengths = deflate_code_lengths(frequencies, 7)
  let codes = deflate_codes(code_lengths)
  let mut code_count = 19
  while code_count > 4 && code_lengths[deflate_code_order[code_count - 1]] == 0 {
    code_count -= 1
  }
  let mut header_bits = 3 + 5 + 5 + 4 + code_count * 3
  for run in runs {
    header_bits += codes[run.symbol].length + run.width
  }
  {
    table: {
      literal: deflate_codes(literal),
      distance: deflate_codes(distance),
    },
    literal_count,
    distance_count,
    code_count,
    code_lengths,
    codes,
    runs,
    header_bits,
  }
}

///|
fn DeflateBits::dynamic_header(
  self : DeflateBits,
  plan : DeflateDynamic,
  finish~ : Bool,
) -> Unit {
  self.put(if finish { 5U } else { 4U }, 3)
  self.put((plan.literal_count - 257).reinterpret_as_uint(), 5)
  self.put((plan.distance_count - 1).reinterpret_as_uint(), 5)
  self.put((plan.code_count - 4).reinterpret_as_uint(), 4)
  for index in 0..<plan.code_count {
    self.put(
      plan.code_lengths[deflate_code_order[index]].reinterpret_as_uint(),
      3,
    )
  }
  for run in plan.runs {
    self.code(plan.codes[run.symbol])
    self.put(run.extra, run.width)
  }
}
