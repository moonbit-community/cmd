///|
priv struct RuntimeSizes {
  root : String
  canonical : String
  sizes : Map[String, Int64]
}

///|
fn runtime_template(text : String) -> Bool {
  text.contains("${STAT_") ||
  text.contains("${HUMAN_SIZE:") ||
  text.contains("${SI_SIZE:")
}

///|
pub fn runtime_contract_observers(fixture : Case) -> Array[String] {
  if fixture.expected_stdout_json is Some(_) ||
    runtime_template(fixture.expected_stdout_text.unwrap_or("")) {
    ["dynamic:" + fixture.id]
  } else {
    []
  }
}

///|
fn runtime_directory_size(observed : RunResult) -> Int64 raise {
  guard observed.status == 0 &&
    observed.stderr == b"" &&
    observed.stdout.length() <= 20 else {
    fail("directory-size observer failed or produced a diagnostic")
  }
  let text = @utf8.decode(observed.stdout)
  guard text.strip_suffix("\n") is Some(digits) &&
    !digits.is_empty() &&
    digits.iter().all(c => c >= '0' && c <= '9') else {
    fail("directory-size observer must return one decimal integer and LF")
  }
  let size = @string.parse_int64(digits)
  guard size >= 0L && size <= 9_007_199_254_740_991L else {
    fail("directory-size observation exceeds the exact JSON integer range")
  }
  size
}

///|
async fn RuntimeSizes::get(self : RuntimeSizes, relative : String) -> Int64 {
  guard relative == "." || safe_relative_path(relative) else {
    fail("unsafe runtime size path: " + relative)
  }
  if self.sizes.get(relative) is Some(size) {
    return size
  }
  let path = if relative == "." {
    self.root
  } else {
    self.root + "/" + relative
  }
  let canonical = @fs.realpath(path).replace_all(old="\\", new="/")
  let prefix = if self.canonical.has_suffix("/") {
    self.canonical
  } else {
    self.canonical + "/"
  }
  guard canonical == self.canonical || canonical.has_prefix(prefix) else {
    fail("runtime size path resolves outside fixture")
  }
  let size = if @fs.kind(path, follow_symlink=true) == Directory {
    guard !(@async.platform is Windows) else {
      fail("directory-size observation is unsupported on Windows")
    }
    // A fixed read-only host observer stays outside command implementation.
    // Stat the canonical in-fixture target so symlink traversal is unambiguous.
    let args = if @async.platform is MacOS {
      ["-f", "%z", canonical]
    } else {
      ["-c", "%s", canonical]
    }
    runtime_directory_size(run("/usr/bin/stat", args, inherit_env=false))
  } else {
    @fs.file_size(path)
  }
  guard size >= 0L && size <= 9_007_199_254_740_991L else {
    fail("runtime size exceeds the exact JSON integer range")
  }
  self.sizes[relative] = size
  size
}

///|
fn runtime_pad(text : String, width : Int32) -> String raise {
  guard width >= 1 && width <= 32 else { fail("invalid runtime field width") }
  " ".repeat((width - text.length()).max(0)) + text
}

///|
fn runtime_decimal(value : Double, precision : Int32) -> String {
  let scale = if precision == 1 { 10.0 } else { 1.0 }
  let scaled = value * scale
  let below = scaled.floor()
  let remainder = scaled - below
  let base = below.to_int64()
  let rounded = if remainder > 0.5 || (remainder == 0.5 && base % 2L != 0L) {
    base + 1L
  } else {
    base
  }
  if precision == 0 {
    rounded.to_string()
  } else {
    (rounded / 10L).to_string() + "." + (rounded % 10L).to_string()
  }
}

///|
// Independently follows upstream tree's psize float32 quotient and C printf
// field contract: https://github.com/Old-Man-Programmer/tree/blob/master/tree.c
fn runtime_human(size : Int64, si : Bool) -> String raise {
  guard size >= 0L else { fail("negative runtime human size") }
  let base = if si { 1000L } else { 1024L }
  let mut reduced = size
  let mut unit = 0
  while reduced >= base {
    unit += 1
    if reduced < base * base {
      break
    }
    reduced /= base
  }
  if unit == 0 {
    return runtime_pad(size.to_string(), 4)
  }
  let units = if si { "dkMGTPEZY" } else { "BKMGTPEZY" }
  guard unit < units.length() else { fail("runtime human unit overflow") }
  let quotient = Float::from_int64(reduced) / Float::from_int64(base)
  let precision = if (reduced + 52L) / base >= 10L { 0 } else { 1 }
  runtime_pad(runtime_decimal(quotient.to_double(), precision), 3) +
  units.view(start_offset=unit, end_offset=unit + 1).to_owned()
}

///|
fn runtime_add(left : Int64, right : Int64) -> Int64 raise {
  guard right >= 0L && left >= 0L && right <= 9_007_199_254_740_991L - left else {
    fail("runtime sum exceeds exact nonnegative JSON range")
  }
  left + right
}

///|
fn runtime_integer(value : Json) -> Int64 raise {
  guard value is Number(number, ..) &&
    !number.is_nan() &&
    !number.is_inf() &&
    number >= 0.0 &&
    number <= 9_007_199_254_740_991.0 &&
    number.floor() == number else {
    fail("runtime expected integer must be nonnegative and exact")
  }
  number.to_int64()
}

///|
async fn runtime_token(token : String, sizes : RuntimeSizes) -> String {
  let parts = token.split(":").map(StringView::to_owned).collect()
  match parts {
    ["STAT_SIZE", path, width] =>
      runtime_pad(sizes.get(path).to_string(), @string.parse_int(width))
    ["STAT_SUM", paths, addend, width] => {
      let mut total = @string.parse_int64(addend)
      guard total >= 0L else { fail("negative runtime sum addend") }
      for path in paths.split(",") {
        total = runtime_add(total, sizes.get(path.to_owned()))
      }
      runtime_pad(total.to_string(), @string.parse_int(width))
    }
    ["HUMAN_SIZE", path] => runtime_human(sizes.get(path), false)
    ["SI_SIZE", path] => runtime_human(sizes.get(path), true)
    _ => fail("unknown or malformed runtime size token: " + token)
  }
}

///|
async fn runtime_text(text : String, sizes : RuntimeSizes) -> String {
  if !runtime_template(text) {
    return text
  }
  let output = StringBuilder()
  let mut index = 0
  let mut literal = 0
  while index < text.length() {
    if text[index] == '$' && index + 1 < text.length() && text[index + 1] == '{' {
      let mut end = index + 2
      while end < text.length() && text[end] != '}' {
        end += 1
      }
      let tail = text.view(start_offset=index + 2, end_offset=end).to_owned()
      if tail.has_prefix("STAT_") ||
        tail.has_prefix("HUMAN_SIZE:") ||
        tail.has_prefix("SI_SIZE:") {
        guard end < text.length() else {
          fail("unterminated runtime size token")
        }
        output.write_view(text.view(start_offset=literal, end_offset=index))
        output.write_string(runtime_token(tail, sizes))
        index = end + 1
        literal = index
        continue
      }
    }
    index += 1
  }
  output.write_view(text.view(start_offset=literal))
  output.to_string()
}

///|
async fn runtime_json(
  value : Json,
  sizes : RuntimeSizes,
  http_base : String?,
  depth : Int32,
) -> Json {
  guard depth <= 64 else { fail("runtime expectation nesting exceeds limit") }
  match value {
    Object(fields) => {
      if fields.contains("$stat_size") {
        guard fields.length() == 1 && fields["$stat_size"] is String(path) else {
          fail("invalid runtime stat-size predicate")
        }
        return Json(sizes.get(path).to_double())
      }
      if fields.contains("$sum") {
        guard fields.length() == 1 &&
          fields["$sum"] is Array(items) &&
          !items.is_empty() else {
          fail("invalid runtime sum")
        }
        let mut total = 0L
        for item in items {
          total = runtime_add(
            total,
            runtime_integer(runtime_json(item, sizes, http_base, depth + 1)),
          )
        }
        return Json(total.to_double())
      }
      if fields.contains("$any") {
        guard fields.length() == 1 &&
          fields["$any"] is String("duration" | "nonnegative-number") else {
          fail("unknown runtime variable predicate")
        }
        return value
      }
      let resolved : Map[String, Json] = Map([])
      for key, item in fields {
        guard !key.has_prefix("$") else {
          fail("unknown runtime expected operator")
        }
        resolved[key] = runtime_json(item, sizes, http_base, depth + 1)
      }
      Json(resolved)
    }
    Array(items) => {
      let resolved : Array[Json] = []
      for item in items {
        resolved.push(runtime_json(item, sizes, http_base, depth + 1))
      }
      Json(resolved)
    }
    String(text) => Json(expand_text(text, sizes.root, http_base?))
    _ => value
  }
}

///|
/// Resolves all filesystem-derived expected values before the product starts.
pub async fn resolve_runtime_contract(
  fixture : Case,
  root : String,
  http_base? : String,
) -> Case {
  let sizes : RuntimeSizes = {
    root,
    canonical: @fs.realpath(root).replace_all(old="\\", new="/"),
    sizes: Map([]),
  }
  let stdout = match fixture.expected_stdout_text {
    Some(text) => Some(runtime_text(expand_text(text, root, http_base?), sizes))
    None => None
  }
  let stderr = match fixture.expected_stderr_text {
    Some(text) => Some(runtime_text(expand_text(text, root, http_base?), sizes))
    None => None
  }
  let json = match fixture.expected_stdout_json {
    Some(value) => Some(runtime_json(value, sizes, http_base, 0))
    None => None
  }
  {
    ..fixture,
    expected_stdout_text: stdout,
    expected_stderr_text: stderr,
    expected_stdout_json: json,
  }
}

///|
fn runtime_nonnegative(value : Json, integer : Bool) -> Bool {
  value is Number(number, ..) &&
  !number.is_nan() &&
  !number.is_inf() &&
  number >= 0.0 &&
  (!integer || number.floor() == number)
}

///|
fn runtime_duration(value : Json) -> Bool {
  guard value is Object(fields) &&
    fields.length() == 3 &&
    fields.contains("secs") &&
    fields.contains("nanos") &&
    fields.contains("human") &&
    runtime_nonnegative(fields["secs"], true) &&
    runtime_nonnegative(fields["nanos"], true) &&
    fields["nanos"] is Number(nanos, ..) &&
    nanos < 1_000_000_000.0 &&
    fields["human"] is String(human) &&
    human.strip_suffix("s") is Some(seconds) else {
    return false
  }
  let parts = seconds.split(".").collect()
  guard parts is [whole, fractional] &&
    !whole.is_empty() &&
    fractional.length() == 6 &&
    whole.iter().all(c => c >= '0' && c <= '9') &&
    fractional.iter().all(c => c >= '0' && c <= '9') else {
    return false
  }
  whole.length() == 1 || !whole.has_prefix("0")
}

///|
fn runtime_match(
  expected : Json,
  actual : Json,
  location : String,
  depth : Int32,
) -> Array[String] {
  if depth > 64 {
    return [location + ": JSON nesting exceeds limit"]
  }
  if expected is Object(fields) && fields.get("$any") is Some(String(kind)) {
    let valid = fields.length() == 1 &&
      (match kind {
        "duration" => runtime_duration(actual)
        "nonnegative-number" => runtime_nonnegative(actual, false)
        _ => false
      })
    return if valid { [] } else { [location + ": typed variable differs"] }
  }
  match (expected, actual) {
    (Object(left), Object(right)) => {
      if left.length() != right.length() ||
        left.keys().any(key => !right.contains(key)) {
        return [location + ": JSON object keys differ"]
      }
      let errors : Array[String] = []
      for key, value in left {
        errors.append(
          runtime_match(value, right[key], location + "." + key, depth + 1),
        )
      }
      errors
    }
    (Array(left), Array(right)) => {
      if left.length() != right.length() {
        return [location + ": JSON array/event count differs"]
      }
      let errors : Array[String] = []
      for index in 0..<left.length() {
        errors.append(
          runtime_match(
            left[index],
            right[index],
            location + "[" + index.to_string() + "]",
            depth + 1,
          ),
        )
      }
      errors
    }
    _ =>
      if expected == actual {
        []
      } else {
        [location + ": JSON value differs"]
      }
  }
}

///|
fn runtime_unique_keys(text : String) -> Bool raise {
  let stack : Array[Set[String]?] = []
  let mut index = 0
  while index < text.length() {
    match text[index] {
      '{' => {
        stack.push(Some(Set([])))
        index += 1
      }
      '[' => {
        stack.push(None)
        index += 1
      }
      '}' | ']' => {
        ignore(stack.pop())
        index += 1
      }
      '"' => {
        let start = index
        index += 1
        while index < text.length() && text[index] != '"' {
          index += if text[index] == '\\' { 2 } else { 1 }
        }
        index += 1
        let end = index
        while index < text.length() && text[index] is (' ' | '\n' | '\r' | '\t') {
          index += 1
        }
        if index < text.length() && text[index] == ':' {
          guard @json.parse(
              text.view(start_offset=start, end_offset=end).to_owned(),
            )
            is String(key) &&
            stack.last() is Some(Some(keys)) else {
            return false
          }
          if keys.contains(key) {
            return false
          }
          keys.add(key)
        }
      }
      _ => index += 1
    }
  }
  true
}

///|
fn runtime_parse(text : String) -> Json raise {
  let value = @json.parse(text)
  guard runtime_unique_keys(text) else { fail("duplicate JSON object key") }
  value
}

///|
/// Compares the entire parsed stream, including event order and object keysets.
pub fn check_runtime_contract(
  fixture : Case,
  observed : RunResult,
) -> Array[String] {
  guard fixture.expected_stdout_json is Some(expected) else { return [] }
  try {
    let text = @utf8.decode(observed.stdout)
    if fixture.expected_stdout_ends_with_newline == Some(true) &&
      !text.has_suffix("\n") {
      return ["runtime JSON stdout lacks the required final newline"]
    }
    let actual = if fixture.stdout_json_lines == Some(true) {
      let parts = text.split("\n").map(StringView::to_owned).collect()
      if parts.last() == Some("") {
        ignore(parts.pop())
      }
      let values : Array[Json] = []
      for line in parts {
        guard !line.trim().is_empty() else { fail("blank JSONL event") }
        values.push(runtime_parse(line))
      }
      Json(values)
    } else {
      runtime_parse(text)
    }
    runtime_match(expected, actual, "stdout", 0)
  } catch {
    error => ["runtime JSON stdout invalid: " + error.to_string()]
  }
}
