///|
struct Word {
  value : String
  space : Int32
  period : Bool
  sentence_end : Bool
}

///|
fn words(line : String, indent : Int32, uniform : Bool) -> Array[Word] {
  let result : Array[Word] = []
  let mut i = 0
  let mut col = 0
  while i < line.length() && line[i] is (' ' | '\t') {
    col = if line[i] == '\t' { (col / 8 + 1) * 8 } else { col + 1 }
    i += 1
  }
  col = indent
  while i < line.length() {
    let start = i
    i += 1
    while i < line.length() &&
          !(line[i] is (' ' | '\t' | '\u000b' | '\u000c' | '\r')) {
      i += 1
    }
    let value = line[start:i].to_owned()
    col += value.length()
    let before_space = col
    while i < line.length() && line[i] is (' ' | '\t') {
      col = if line[i] == '\t' { (col / 8 + 1) * 8 } else { col + 1 }
      i += 1
    }
    let mut end = value.length() - 1
    while end > 0 && value[end] is (')' | ']' | '\'' | '"') {
      end -= 1
    }
    let period = value[end] is ('.' | '?' | '!')
    let sentence_end = period && (i == line.length() || col - before_space > 1)
    let space = if i == line.length() || uniform {
      if sentence_end {
        2
      } else {
        1
      }
    } else {
      col - before_space
    }
    result.push({ value, space, period, sentence_end, })
  }
  result
}

///|
fn punctuation(c : UInt16) -> Bool {
  c is ('!'..<='/' | ':'..<='@' | '['..<='`' | '{'..<='~')
}

///|
fn square(value : Int32) -> Int64 {
  value.to_int64() * value.to_int64()
}

///|
fn paragraph(
  items : Array[Word],
  indent : Int32,
  width : Int32,
  goal : Int32,
  tabs : Bool,
) -> String {
  if items.is_empty() {
    return ""
  }
  let n = items.length()
  items[n - 1] = { ..items[n - 1], period: true, sentence_end: true, }
  let costs : Array[Int64] = Array::make(n + 1, 0L)
  let breaks = Array::make(n, n)
  let lengths = Array::make(n, 0)
  for i = n - 1; i >= 0; i = i - 1 {
    let mut end = i + 1
    let mut len = indent + items[i].value.length()
    let mut best = 9223372036854775807L
    while end <= n {
      let mut cost = costs[end]
      if end < n {
        cost += 100L * square(goal - len)
        if breaks[end] != n {
          cost += 50L * square(len - lengths[end])
        }
      }
      if cost < best {
        best = cost
        breaks[i] = end
        lengths[i] = len
      }
      if end == n {
        break
      }
      len += items[end - 1].space + items[end].value.length()
      if len > width {
        break
      }
      end += 1
    }
    let mut penalty = 4900L
    if i > 0 {
      let previous = items[i - 1]
      if previous.period {
        penalty += if previous.sentence_end { -2500L } else { 360000L }
      } else if punctuation(previous.value[previous.value.length() - 1]) {
        penalty -= 1600L
      } else if i > 1 && items[i - 2].sentence_end {
        penalty += 40000L / (previous.value.length() + 2).to_int64()
      }
    }
    if items[i].value[0] is ('(' | '[' | '\'' | '`' | '"') {
      penalty -= 1600L
    } else if items[i].sentence_end {
      penalty += 22500L / (items[i].value.length() + 2).to_int64()
    }
    costs[i] = best + penalty
  }
  let output = StringBuilder()
  let mut i = 0
  while i < n {
    let mut column = 0
    let mut spaces = indent
    for j in i..<breaks[i] {
      if tabs {
        let target = (column + spaces) / 8 * 8
        if target > column + 1 {
          while column < target {
            let next = (column / 8 + 1) * 8
            spaces -= next - column
            column = next
            output.write_char('\t')
          }
        }
      }
      output.write_string(" ".repeat(spaces))
      column += spaces + items[j].value.length()
      output.write_string(items[j].value)
      spaces = items[j].space
    }
    output.write_char('\n')
    i = breaks[i]
  }
  output.to_string()
}

///|
fn format(
  data : Bytes,
  width : Int32,
  goal : Int32,
  split : Bool,
  uniform : Bool,
) -> Bytes {
  let text = @bytere.text(data)
  let lines = text.split("\n").map(v => v.to_owned()).collect()
  if text.has_suffix("\n") || text == "" {
    ignore(lines.pop())
  }
  let output = StringBuilder()
  let mut pending : Array[Word] = []
  let mut indent = 0
  let mut tabs = false
  for line in lines {
    let mut leading = 0
    for c in line {
      if c == ' ' {
        leading += 1
      } else if c == '\t' {
        leading = (leading / 8 + 1) * 8
        tabs = true
      } else {
        break
      }
    }
    if line.contains("\t") {
      tabs = true
    }
    let next = words(line, leading, uniform)
    if next.is_empty() || split || leading != indent {
      output.write_string(paragraph(pending, indent, width, goal, tabs))
      pending = []
    }
    indent = leading
    if next.is_empty() {
      output.write_char('\n')
    } else {
      pending.append(next)
    }
  }
  output.write_string(paragraph(pending, indent, width, goal, tabs))
  @bytere.bytes(output.to_string())
}
