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
  other_indent~ : Int32? = None,
  prefix~ : String = "",
  prefix_indent~ : Int32 = 0,
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
    let mut len = (if i == 0 { indent } else { other_indent.unwrap_or(indent) }) +
      items[i].value.length()
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
    let mut spaces = prefix_indent
    if !prefix.is_empty() {
      put_spaces(output, column, spaces, tabs)
      column = prefix_indent + prefix.length()
      output.write_string(prefix)
      spaces = (if i == 0 { indent } else { other_indent.unwrap_or(indent) }) -
        column
    } else {
      spaces = if i == 0 { indent } else { other_indent.unwrap_or(indent) }
    }
    for j in i..<breaks[i] {
      spaces = @cmp.maximum(0, spaces)
      put_spaces(output, column, spaces, tabs)
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
  crown~ : Bool = false,
  tagged~ : Bool = false,
  prefix~ : String = "",
) -> Bytes {
  let text = @bytere.text(data)
  let lines = text.split("\n").map(v => v.to_owned()).collect()
  if text.has_suffix("\n") || text == "" {
    ignore(lines.pop())
  }
  let output = StringBuilder()
  let mut lead = 0
  while lead < prefix.length() && prefix[lead] == ' ' {
    lead += 1
  }
  let full = prefix.length() - lead
  let mut finish = prefix.length()
  while finish > lead && prefix[finish - 1] == ' ' {
    finish -= 1
  }
  let literal = prefix[lead:finish].to_owned()
  let parsed = Array::makei(lines.length(), index => {
    parse_line(
      lines[index],
      literal,
      lead,
      full,
      index < lines.length() - 1 || text.has_suffix("\n"),
    )
  })
  let mut other_indent = 0
  let mut tabs = false
  let mut index = 0
  while index < parsed.length() {
    let first = parsed[index]
    tabs = tabs || first.prefix_tabs
    if !first.eligible {
      if first.indent > first.prefix_indent || !first.body.is_empty() {
        put_spaces(output, 0, first.prefix_indent, tabs)
        output.write_string(first.copy_prefix)
        if !first.body.is_empty() {
          let column = first.prefix_indent + first.copy_prefix.length()
          put_spaces(output, column, first.indent - column, tabs)
        }
      }
      output.write_string(first.body)
      if first.copy_newline {
        output.write_char('\n')
      }
      index += 1
      continue
    }
    tabs = tabs || first.body.contains("\t")
    let pending = words(first.body, first.indent, uniform)
    index += 1
    let same = if index < parsed.length() {
      let next = parsed[index]
      tabs = tabs || next.prefix_tabs
      next.eligible && next.prefix_indent == first.prefix_indent
    } else {
      false
    }
    if split {
      other_indent = first.indent
    } else if crown {
      other_indent = if same { parsed[index].indent } else { first.indent }
    } else if tagged {
      if same && parsed[index].indent != first.indent {
        other_indent = parsed[index].indent
      } else if other_indent == first.indent {
        other_indent = if first.indent == 0 { 3 } else { 0 }
      }
    } else {
      other_indent = first.indent
    }
    let join = !split &&
      (!tagged || crown || (same && parsed[index].indent != first.indent))
    while join && index < parsed.length() {
      let next = parsed[index]
      tabs = tabs || next.prefix_tabs
      if !next.eligible ||
        next.prefix_indent != first.prefix_indent ||
        next.indent != other_indent {
        break
      }
      tabs = tabs || next.body.contains("\t")
      pending.append(words(next.body, next.indent, uniform))
      index += 1
    }
    output.write_string(
      paragraph(
        pending,
        first.indent,
        width,
        goal,
        tabs,
        other_indent=Some(other_indent),
        prefix=literal,
        prefix_indent=first.prefix_indent,
      ),
    )
  }
  @bytere.bytes(output.to_string())
}

///|
priv struct InputLine {
  body : String
  indent : Int32
  prefix_indent : Int32
  prefix_tabs : Bool
  eligible : Bool
  copy_prefix : String
  copy_newline : Bool
}

///|
fn parse_line(
  line : String,
  prefix : String,
  lead : Int32,
  full : Int32,
  terminated : Bool,
) -> InputLine {
  let mut index = 0
  let mut column = 0
  let mut tabs = false
  while index < line.length() && line[index] is (' ' | '\t') {
    if line[index] == '\t' {
      tabs = true
      column = (column / 8 + 1) * 8
    } else {
      column += 1
    }
    index += 1
  }
  let prefix_indent = if prefix.is_empty() {
    @cmp.minimum(lead, column)
  } else {
    column
  }
  let mut matched = 0
  while matched < prefix.length() &&
        index < line.length() &&
        line[index] == prefix[matched] {
    index += 1
    column += 1
    matched += 1
  }
  let matches = matched == prefix.length()
  if matches && !prefix.is_empty() {
    while index < line.length() && line[index] is (' ' | '\t') {
      if line[index] == '\t' {
        tabs = true
        column = (column / 8 + 1) * 8
      } else {
        column += 1
      }
      index += 1
    }
  }
  let eligible = matches &&
    prefix_indent >= lead &&
    column >= prefix_indent + full &&
    index < line.length()
  {
    body: line[index:].to_owned(),
    indent: column,
    prefix_indent,
    prefix_tabs: tabs,
    eligible,
    copy_prefix: prefix[:matched].to_owned(),
    copy_newline: terminated ||
    (index == line.length() && column >= prefix_indent + prefix.length()),
  }
}

///|
fn put_spaces(
  output : StringBuilder,
  column : Int32,
  spaces : Int32,
  tabs : Bool,
) -> Unit {
  let target = column + @cmp.maximum(0, spaces)
  let mut column = column
  if tabs && column + 1 < target / 8 * 8 {
    while column < target / 8 * 8 {
      output.write_char('\t')
      column = (column / 8 + 1) * 8
    }
  }
  output.write_string(" ".repeat(target - column))
}
