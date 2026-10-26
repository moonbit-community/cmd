///|
fn generate_man_flag(flag : FlagDef, out : StringBuilder) -> Unit {
  if flag.name_short is Some(c) {
    out.write_string("\\fB\\-\{c}\\fP")
    if flag.doc_variable is Some(dv) {
      out.write_string(" \\fI\{dv}\\fP")
    }
    out.write_string(", ")
  }
  let name = flag.name_long.replace_all(old="-", new="\\-")
  out.write_string("\\fB\\-\\-\{name}\\fP")
  if flag.doc_variable is Some(dv) {
    out.write_string("=\\fI\{dv}\\fP")
  }
  out.write_string("\n")
  out.write_string(".RS 4\n")
  let doc = flag.doc_long.trim().to_owned()
  let doc = render_custom_markup(doc, "flag", (name, out) => {
    guard lookup_flag(name) is Some(f) else {
      abort("found unrecognized \\flag{\{name}} in roff docs")
    }
    out.write_string("\\fB")
    if f.name_short is Some(c) {
      out.write_string("\\-\{c}/")
    }
    out.write_string("\\-\\-\{f.name_long.replace_all(old="-", new="\\-")}")
    out.write_string("\\fP")
  })
  let doc = render_custom_markup(doc, "flag-negate", (name, out) => {
    guard lookup_flag(name) is Some(f) else {
      abort("found unrecognized \\flag-negate{\{name}} in roff docs")
    }
    guard f.name_negated is Some(n) else {
      abort("found \\flag-negate{\{name}} but it has no negation")
    }
    out.write_string("\\fB\\-\\-\{n}\\fP")
  })
  out.write_string(doc)
  out.write_string("\n")
  if flag.name_negated is Some(negated) && flag.is_switch {
    out.write_string(".sp\n")
    out.write_string(
      "This flag can be disabled with \\fB\\-\\-\{negated}\\fP.\n",
    )
  }
  out.write_string(".RE\n")
}

///|
/// Generates ripgrep's man page in roff format.
pub fn generate_man_page() -> String {
  let cats : Map[String, StringBuilder] = Map([])
  for flag in flag_defs {
    let key = flag.doc_category.as_str()
    if !cats.contains(key) {
      cats[key] = StringBuilder()
    }
    let cat = cats[key]
    if cat.to_string() != "" {
      cat.write_string(".sp\n")
    }
    generate_man_flag(flag, cat)
  }
  let mut out = template_rg_man.replace_all(
    old="!!VERSION!!",
    new=generate_version_digits(),
  )
  for cat in all_categories {
    guard cats.get(cat.as_str()) is Some(value) else { continue }
    let key = "!!\{cat.as_str()}!!"
    if cat is Indexing {
      out = out.replace_all(old=key, new=INDEXING_NOT_SUPPORTED)
    } else {
      out = out.replace_all(old=key, new=value.to_string())
    }
  }
  out
}
