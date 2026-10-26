///|
/// The version of ripgrep this port is based on.
pub let rg_version : String = "15.2.0"

///|
pub fn generate_version_digits() -> String {
  rg_version
}

///|
pub fn generate_version_short() -> String {
  "ripgrep \{generate_version_digits()}"
}

///|
pub fn generate_version_long() -> String {
  let out = StringBuilder()
  out.write_string(generate_version_short())
  out.write_string("\n\n")
  out.write_string("features:-pcre2\n")
  let (pcre2, _) = generate_version_pcre2()
  out.write_string("\n\{pcre2}")
  out.to_string()
}

///|
pub fn generate_version_pcre2() -> (String, Bool) {
  ("PCRE2 is not available in this build of ripgrep.\n", false)
}

///|
let all_categories : Array[Category] = [
  Input,
  Search,
  Filter,
  Output,
  OutputModes,
  Indexing,
  Logging,
  OtherBehaviors,
]

///|
fn generate_short_flag(flag : FlagDef) -> (String, String) {
  let col1 = StringBuilder()
  let docvar = flag.doc_variable.map(s => {
    s
    .replace_all(old="SEPARATOR", new="SEP")
    .replace_all(old="REPLACEMENT", new="TEXT")
    .replace_all(old="NUM+SUFFIX?", new="NUM")
  })
  if flag.name_short is Some(c) {
    col1.write_string("-\{c}, ")
  }
  col1.write_string("--\{flag.name_long}")
  if docvar is Some(v) {
    col1.write_string("=\{v}")
  }
  (col1.to_string(), flag.doc_short)
}

///|
/// Generates the `-h` output.
pub fn generate_help_short() -> String {
  let cats : Map[String, (Array[String], Array[String])] = Map([])
  let mut maxcol1 = 0
  for flag in flag_defs {
    let key = flag.doc_category.as_str()
    if !cats.contains(key) {
      cats[key] = ([], [])
    }
    let (col1, col2) = generate_short_flag(flag)
    if utf8_byte_len(col1) > maxcol1 {
      maxcol1 = utf8_byte_len(col1)
    }
    cats[key].0.push(col1)
    cats[key].1.push(col2)
  }
  let mut out = template_short_help.replace_all(
    old="!!VERSION!!",
    new=generate_version_digits(),
  )
  for cat in all_categories {
    guard cats.get(cat.as_str()) is Some((col1, col2)) else { continue }
    let key = "!!\{cat.as_str()}!!"
    if cat is Indexing {
      out = out.replace_all(old=key, new="  \{INDEXING_NOT_SUPPORTED}")
    } else {
      let val = StringBuilder()
      for i, c1 in col1 {
        if i > 0 {
          val.write_char('\n')
        }
        let pad = maxcol1 - utf8_byte_len(c1) + 2
        val.write_string("  ")
        val.write_string(c1)
        for _ in 0..<pad {
          val.write_char(' ')
        }
        val.write_string(col2[i])
      }
      out = out.replace_all(old=key, new=val.to_string())
    }
  }
  out
}

///|
/// Replaces occurrences of `\tag{name}` using `replacement`.
fn render_custom_markup(
  doc : String,
  tag : String,
  replacement : (String, StringBuilder) -> Unit,
) -> String {
  let out = StringBuilder()
  let prefix = "\\" + tag + "{"
  let mut rest = doc
  while rest.find(prefix) is Some(offset) {
    out.write_string(rest.view(end_offset=offset).to_owned())
    let start = offset + prefix.length()
    let after = rest.view(start_offset=start).to_owned()
    guard after.find("}") is Some(i) else {
      abort("found \{prefix} without closing }")
    }
    let name = after.view(end_offset=i).to_owned()
    replacement(name, out)
    rest = after.view(start_offset=i + 1).to_owned()
  }
  out.write_string(rest)
  out.to_string()
}

///|
fn remove_roff(v : String) -> String {
  let lines : Array[String] = []
  for line in v.trim().split("\n") {
    let line = line.to_owned()
    if line.has_prefix(".") {
      if line.has_prefix(".IP ") {
        let label = line.split(" ").collect()[1]
          .to_owned()
          .replace_all(old="\\(bu", new="•")
          .replace_all(old="\\fB", new="")
          .replace_all(old="\\fP", new=":")
        lines.push(label)
      } else if line.has_prefix(".IB ") || line.has_prefix(".BI ") {
        let pieces = line.split(" ").filter(s => !s.is_empty()).collect()
        lines.push(pieces[1:].map(s => s.to_owned()).join(""))
      } else if line.has_prefix(".sp") ||
        line.has_prefix(".PP") ||
        line.has_prefix(".TP") {
        lines.push("")
      }
    } else if line.has_prefix("\\fB") && line.has_suffix("\\fP") {
      let l = line
        .replace_all(old="\\fB", new="")
        .replace_all(old="\\fP", new="")
      lines.push("\{l}:")
    } else {
      lines.push(line)
    }
  }
  // dedup consecutive empty lines
  let deduped : Array[String] = []
  for l in lines {
    if l.is_empty() &&
      deduped.length() > 0 &&
      deduped[deduped.length() - 1].is_empty() {
      continue
    }
    deduped.push(l)
  }
  deduped
  .join("\n")
  .replace_all(old="\\fB", new="")
  .replace_all(old="\\fI", new="")
  .replace_all(old="\\fP", new="")
  .replace_all(old="\\-", new="-")
  .replace_all(old="\\\\", new="\\")
}

///|
fn generate_long_flag(flag : FlagDef, out : StringBuilder) -> Unit {
  match flag.name_short {
    Some(c) => {
      out.write_string("    -\{c}")
      if flag.doc_variable is Some(dv) {
        out.write_string(" \{dv}")
      }
      out.write_string(", ")
    }
    None => out.write_string("    ")
  }
  out.write_string("--\{flag.name_long}")
  if flag.doc_variable is Some(dv) {
    out.write_string("=\{dv}")
  }
  out.write_char('\n')
  let doc = flag.doc_long.trim().to_owned()
  let doc = render_custom_markup(doc, "flag", (name, out) => {
    guard lookup_flag(name) is Some(f) else {
      abort("found unrecognized \\flag{\{name}} in --help docs")
    }
    if f.name_short is Some(c) {
      out.write_string("-\{c}/")
    }
    out.write_string("--\{f.name_long}")
  })
  let doc = render_custom_markup(doc, "flag-negate", (name, out) => {
    guard lookup_flag(name) is Some(f) else {
      abort("found unrecognized \\flag-negate{\{name}} in --help docs")
    }
    guard f.name_negated is Some(n) else {
      abort("found \\flag-negate{\{name}} but it has no negation")
    }
    out.write_string("--\{n}")
  })
  let mut cleaned = remove_roff(doc)
  if flag.name_negated is Some(negated) && flag.is_switch {
    cleaned = cleaned + "\n\nThis flag can be disabled with --\{negated}."
  }
  let indent = "        "
  for i, paragraph in cleaned.split("\n\n").collect() {
    let paragraph = paragraph.to_owned()
    if i > 0 {
      out.write_string("\n\n")
    }
    let mut new = paragraph
    if rust_lines(paragraph).iter().all(l => l.has_prefix("    ")) {
      new = tw_indent(new, indent)
    } else {
      new = new.replace_all(old="\n", new=" ")
      new = tw_refill(new, 71)
      new = tw_indent(new, indent)
    }
    out.write_string(new.trim_end().to_owned())
  }
}

///|
/// Generates the `--help` output.
pub fn generate_help_long() -> String {
  let cats : Map[String, StringBuilder] = Map([])
  for flag in flag_defs {
    let key = flag.doc_category.as_str()
    if !cats.contains(key) {
      cats[key] = StringBuilder()
    }
    let cat = cats[key]
    if cat.to_string() != "" {
      cat.write_string("\n\n")
    }
    generate_long_flag(flag, cat)
  }
  let mut out = template_long_help.replace_all(
    old="!!VERSION!!",
    new=generate_version_digits(),
  )
  for cat in all_categories {
    guard cats.get(cat.as_str()) is Some(value) else { continue }
    let key = "!!\{cat.as_str()}!!"
    if cat is Indexing {
      out = out.replace_all(old=key, new="    \{INDEXING_NOT_SUPPORTED}")
    } else {
      out = out.replace_all(old=key, new=value.to_string())
    }
  }
  out
}

///|
/// Splits a string into lines like Rust's `str::lines`: a trailing newline
/// does not produce a final empty line, and `\r\n` endings are stripped.
fn rust_lines(s : String) -> Array[String] {
  let out = s.split("\n").map(l => l.to_owned()).collect()
  if s.has_suffix("\n") {
    ignore(out.pop())
  }
  out.map(l => {
    if l.has_suffix("\r") {
      l.view(end_offset=l.length() - 1).to_owned()
    } else {
      l
    }
  })
}
