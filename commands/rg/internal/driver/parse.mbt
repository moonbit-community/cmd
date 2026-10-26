///|

///|
priv struct FlagInfo {
  flag : FlagDef
  /// `Ok(long name)` or `Err(short name)`.
  name : Result[String, Char]
  /// Whether this is the negated form of the flag (e.g. `--no-foo`).
  negated : Bool
}

///|
fn FlagInfo::display(self : FlagInfo) -> String {
  match self.name {
    Ok(long) => "--\{long}"
    Err(short) => "-\{short}"
  }
}

///|
priv struct FlagParser {
  map : Map[String, Int32]
  info : Array[FlagInfo]
}

///|
let flag_parser_cache : Ref[FlagParser?] = Ref(None)

///|
fn FlagParser::get() -> FlagParser {
  match flag_parser_cache.val {
    Some(p) => p
    None => {
      let infos : Array[FlagInfo] = []
      for flag in flag_defs {
        infos.push({ flag, name: Ok(flag.name_long), negated: false, })
        for alias_name in flag.aliases {
          infos.push({ flag, name: Ok(alias_name), negated: false, })
        }
        if flag.name_short is Some(c) {
          infos.push({ flag, name: Err(c), negated: false, })
        }
        if flag.name_negated is Some(name) {
          infos.push({ flag, name: Ok(name), negated: true, })
        }
      }
      let map = Map([])
      for i, info in infos {
        let key = match info.name {
          Ok(name) => name
          Err(c) => "\u{0}" + c.to_string()
        }
        map[key] = i
      }
      let p = { map, info: infos, }
      flag_parser_cache.val = Some(p)
      p
    }
  }
}

///|
fn FlagParser::find_short(self : FlagParser, ch : Char) -> FlagInfo? {
  if ch.to_int() > 0x7F {
    return None
  }
  match self.map.get("\u{0}" + ch.to_string()) {
    Some(i) => Some(self.info[i])
    None => None
  }
}

///|
fn FlagParser::find_long(self : FlagParser, name : String) -> FlagInfo? {
  match self.map.get(name) {
    Some(i) => Some(self.info[i])
    None => None
  }
}

///|
/// Looks up a flag by its long name.
pub fn lookup_flag(name : String) -> FlagDef? {
  match FlagParser::get().find_long(name) {
    Some(info) => Some(info.flag)
    None => None
  }
}

///|
/// Parses the given arguments (excluding the program name) into `args`.
pub fn parse_into(
  rawargs : Array[String],
  args : LowArgs,
) -> Unit raise RgError {
  let parser = FlagParser::get()
  let p = Lexer::new(rawargs)
  while true {
    let arg = with_context("invalid CLI arguments", () => p.next())
    guard arg is Some(arg) else { break }
    let mat = match arg {
      Value(v) => {
        args.positional.push(v)
        continue
      }
      Short('h') => {
        args.special = Some(HelpShort)
        continue
      }
      Short('V') => {
        args.special = Some(VersionShort)
        continue
      }
      Short(ch) =>
        match parser.find_short(ch) {
          Some(m) => m
          None => raise RgError("unrecognized flag -\{ch}")
        }
      Long("help") => {
        args.special = Some(HelpLong)
        continue
      }
      Long("version") => {
        args.special = Some(VersionLong)
        continue
      }
      Long(name) =>
        match parser.find_long(name) {
          Some(m) => m
          None => {
            let mut msg = "unrecognized flag --\{name}"
            if suggest(name) is Some(s) {
              msg = "\{msg}\n\n\{s}"
            }
            raise RgError(msg)
          }
        }
    }
    let value = if mat.negated {
      Switch(false)
    } else if mat.flag.is_switch {
      Switch(true)
    } else {
      Value(
        with_context("missing value for flag \{mat.display()}", () => p.value()),
      )
    }
    with_context("error parsing flag \{mat.display()}", () => {
      update_flag(mat.flag, value, args)
    })
  }
}

///|
/// Parses arguments into a fresh `LowArgs` (used by tests).
pub fn parse_low_raw(rawargs : Array[String]) -> LowArgs raise RgError {
  let args = LowArgs::default()
  parse_into(rawargs, args)
  args
}

///|
fn suggest(unrecognized : String) -> String? {
  let similars = find_similar_names(unrecognized)
  if similars.is_empty() {
    return None
  }
  let list = similars.map(name => "--\{name}").join(", ")
  Some("similar flags that are available: \{list}")
}

///|
fn find_similar_names(unrecognized : String) -> Array[String] {
  let threshold = 0.4
  let similar = []
  let bow_given = ngrams(unrecognized)
  for flag in flag_defs {
    let name = flag.name_long
    if jaccard_index(bow_given, ngrams(name)) >= threshold {
      similar.push(name)
    }
    if flag.name_negated is Some(name) {
      if jaccard_index(bow_given, ngrams(name)) >= threshold {
        similar.push(name)
      }
    }
    for name in flag.aliases {
      if jaccard_index(bow_given, ngrams(name)) >= threshold {
        similar.push(name)
      }
    }
  }
  similar
}

///|
fn jaccard_index(a : Map[String, Unit], b : Map[String, Unit]) -> Double {
  let mut inter = 0
  for k, _ in a {
    if b.contains(k) {
      inter += 1
    }
  }
  let union = a.length() + b.length() - inter
  inter.to_double() / union.to_double()
}

///|
fn ngrams(name : String) -> Map[String, Unit] {
  let bytes = @utf8.encode(name)
  let set : Map[String, Unit] = Map([])
  let key = (b : BytesView) => {
    let buf = StringBuilder()
    for x in b {
      buf.write_string(x.to_int().to_string())
      buf.write_char(',')
    }
    buf.to_string()
  }
  match bytes.length() {
    0 => set[key(b"!!!")] = ()
    1 => set[key([bytes[0], b'!', b'!'])] = ()
    2 => set[key([bytes[0], bytes[1], b'!'])] = ()
    n =>
      for i in 0..<=(n - 3) {
        set[key(bytes[i:i + 3])] = ()
      }
  }
  set
}
