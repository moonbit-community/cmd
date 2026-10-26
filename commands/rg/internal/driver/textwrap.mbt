// A port of the subset of the `textwrap` crate (0.16, default features
// disabled) used by ripgrep to render `--help` output: first-fit wrapping,
// ASCII space word separation, no hyphenation, `break_words` enabled and
// widths measured in chars.

///|
fn utf8_byte_len(s : String) -> Int32 {
  let mut n = 0
  for c in s {
    let cp = c.to_int()
    n += if cp < 0x80 {
      1
    } else if cp < 0x800 {
      2
    } else if cp < 0x10000 {
      3
    } else {
      4
    }
  }
  n
}

///|
fn char_count(s : String) -> Int32 {
  let mut n = 0
  for _ in s {
    n += 1
  }
  n
}

///|
priv struct TwWord {
  word : String
  whitespace : String
  width : Int32
}

///|
fn TwWord::from_str(s : String) -> TwWord {
  let chars : Array[Char] = s.iter().collect()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == ' ' {
    end -= 1
  }
  let word = String::from_array(chars[0:end])
  {
    word,
    whitespace: String::from_array(chars[end:]),
    width: char_count(word),
  }
}

///|
fn tw_find_words(line : String) -> Array[TwWord] {
  let chars : Array[Char] = line.iter().collect()
  let out = []
  let mut start = 0
  let mut in_whitespace = false
  for idx, ch in chars {
    if in_whitespace && ch != ' ' {
      out.push(TwWord::from_str(String::from_array(chars[start:idx])))
      start = idx
    }
    in_whitespace = ch == ' '
  }
  if start < chars.length() {
    out.push(TwWord::from_str(String::from_array(chars[start:])))
  }
  out
}

///|
fn tw_break_words(words : Array[TwWord], line_width : Int32) -> Array[TwWord] {
  let out = []
  for word in words {
    if word.width > line_width {
      let chars : Array[Char] = word.word.iter().collect()
      let mut offset = 0
      let mut width = 0
      for idx, _ in chars {
        if width > 0 && width + 1 > line_width {
          out.push({
            word: String::from_array(chars[offset:idx]),
            whitespace: "",
            width,
          })
          offset = idx
          width = 1
        } else {
          width += 1
        }
      }
      if offset < chars.length() {
        out.push({
          word: String::from_array(chars[offset:]),
          whitespace: word.whitespace,
          width,
        })
      }
    } else {
      out.push(word)
    }
  }
  out
}

///|
fn tw_wrap_single_line(
  line : String,
  width : Int32,
  initial_indent : String,
  subsequent_indent : String,
  lines : Array[String],
) -> Unit {
  let indent = if lines.is_empty() { initial_indent } else { subsequent_indent }
  if utf8_byte_len(line) < width && indent.is_empty() {
    lines.push(line.trim_end(chars=" ").to_owned())
    return
  }
  let initial_width = width - char_count(initial_indent)
  let subsequent_width = width - char_count(subsequent_indent)
  let initial_width = if initial_width < 0 { 0 } else { initial_width }
  let subsequent_width = if subsequent_width < 0 { 0 } else { subsequent_width }
  let words = tw_break_words(tw_find_words(line), subsequent_width)
  if !initial_indent.is_empty() {
    words.insert(0, { word: "", whitespace: "", width: 0, })
  }
  // First fit.
  let line_widths = [initial_width, subsequent_width]
  let wrapped : Array[ArrayView[TwWord]] = []
  let mut start = 0
  let mut w = 0
  for idx, frag in words {
    let lw = if wrapped.length() < line_widths.length() {
      line_widths[wrapped.length()]
    } else {
      line_widths[line_widths.length() - 1]
    }
    if w + frag.width > lw && idx > start {
      wrapped.push(words[start:idx])
      start = idx
      w = 0
    }
    w += frag.width + char_count(frag.whitespace)
  }
  wrapped.push(words[start:])
  for ws in wrapped {
    if ws.length() == 0 {
      lines.push("")
      continue
    }
    let result = StringBuilder()
    if lines.is_empty() && !initial_indent.is_empty() {
      result.write_string(initial_indent)
    } else if !lines.is_empty() && !subsequent_indent.is_empty() {
      result.write_string(subsequent_indent)
    }
    for i, word in ws {
      result.write_string(word.word)
      if i < ws.length() - 1 {
        result.write_string(word.whitespace)
      }
    }
    lines.push(result.to_string())
  }
}

///|
fn tw_fill(
  text : String,
  width : Int32,
  initial_indent : String,
  subsequent_indent : String,
) -> String {
  if utf8_byte_len(text) < width &&
    !text.contains("\n") &&
    initial_indent.is_empty() {
    return text.trim_end(chars=" ").to_owned()
  }
  let lines = []
  for line in text.split("\n") {
    tw_wrap_single_line(
      line.to_owned(),
      width,
      initial_indent,
      subsequent_indent,
      lines,
    )
  }
  lines.join("\n")
}

///|
fn is_prefix_char(c : Char) -> Bool {
  c == ' ' ||
  c == '-' ||
  c == '+' ||
  c == '*' ||
  c == '>' ||
  c == '#' ||
  c == '/'
}

///|
/// textwrap's `refill(text, width)`.
fn tw_refill(filled_text : String, width : Int32) -> String {
  // unfill
  let mut initial_indent = ""
  let mut subsequent_indent = ""
  let text_lines = filled_text.split("\n").map(s => s.to_owned()).collect()
  if text_lines.length() > 0 && text_lines[text_lines.length() - 1] == "" {
    ignore(text_lines.pop())
  }
  for idx, line in text_lines {
    let chars : Array[Char] = line.iter().collect()
    let mut p = 0
    while p < chars.length() && is_prefix_char(chars[p]) {
      p += 1
    }
    let prefix = String::from_array(chars[0:p])
    if idx == 0 {
      initial_indent = prefix
    } else if idx == 1 {
      subsequent_indent = prefix
    } else {
      let a : Array[Char] = prefix.iter().collect()
      let b : Array[Char] = subsequent_indent.iter().collect()
      let mut k = 0
      while k < a.length() && k < b.length() && a[k] == b[k] {
        k += 1
      }
      if k < a.length() && k < b.length() {
        subsequent_indent = String::from_array(a[0:k])
      }
      if a.length() < char_count(subsequent_indent) {
        subsequent_indent = prefix
      }
    }
  }
  let unfilled = StringBuilder()
  let mut idx = 0
  for line in text_lines {
    if line.is_empty() {
      continue
    }
    let chars : Array[Char] = line.iter().collect()
    if idx == 0 {
      unfilled.write_string(
        String::from_array(chars[char_count(initial_indent):]),
      )
    } else {
      unfilled.write_char(' ')
      unfilled.write_string(
        String::from_array(chars[char_count(subsequent_indent):]),
      )
    }
    idx += 1
  }
  let text = unfilled.to_string()
  let ends_with_newline = filled_text.has_suffix("\n")
  let refilled = tw_fill(text, width, initial_indent, subsequent_indent)
  if ends_with_newline {
    refilled + "\n"
  } else {
    refilled
  }
}

///|
/// textwrap's `indent(s, prefix)`.
fn tw_indent(s : String, prefix : String) -> String {
  let result = StringBuilder()
  let trimmed_prefix = prefix.trim_end().to_owned()
  let parts = s.split("\n").map(x => x.to_owned()).collect()
  if s.has_suffix("\n") {
    ignore(parts.pop())
  }
  for idx, line in parts {
    if idx > 0 {
      result.write_char('\n')
    }
    if line.trim().is_empty() {
      result.write_string(trimmed_prefix)
    } else {
      result.write_string(prefix)
    }
    result.write_string(line)
  }
  if s.has_suffix("\n") {
    result.write_char('\n')
  }
  result.to_string()
}
