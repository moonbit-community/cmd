///|
/// Portable fixture description. Text and hex are mutually exclusive.
pub(all) struct FixtureFile {
  path : String
  content_hex : String?
  content_text : String?
  kind : String?
  target : String?
  mode : Int?
  atime : String?
  mtime : String?
} derive(FromJson, ToJson, Debug)

///|
pub(all) struct Normalization {
  field : String
  rule : String
  comment : String
} derive(FromJson, ToJson, Debug)

///|
pub(all) struct ExpectedFile {
  path : String
  exists : Bool?
  kind : String?
  content_text : String?
  content_hex : String?
  mode : Int?
  target : String?
  same_identity_as : String?
} derive(FromJson, ToJson, Debug)

///|
/// Schema 1 fields remain readable; optional additions describe schema 2 cases.
pub(all) struct Case {
  id : String
  aliases : Array[String]?
  command : String
  related_commands : Array[String]?
  args : Array[String]
  stdin_hex : String?
  stdin_text : String?
  files : Array[FixtureFile]
  delay_ms : Int?
  environment : Map[String, String]
  expected_status : Int
  expected_rejection : String?
  normalizations : Array[Normalization]
  timeout_ms : Int?
  comparison : String?
  oracle : Bool?
  expected_stdout_hex : String?
  expected_stdout_text : String?
  expected_stderr_hex : String?
  expected_stderr_text : String?
  expected_stdout_contains : String?
  expected_stderr_contains : String?
  diagnostic_reason : String?
  expected_stdout_ends_with_newline : Bool?
  expected_stderr_ends_with_newline : Bool?
  forbidden_stderr : Array[String]?
  coverage : Array[String]?
  host_platforms : Array[String]?
  observe : Array[String]?
  source_version : String?
  cwd : String?
  expected_files : Array[ExpectedFile]?
  expected_stdout_contains_all : Array[String]?
  expected_stderr_contains_all : Array[String]?
  stdout_order : String?
} derive(FromJson, ToJson, Debug)

///|
fn hex_nibble(char : Char) -> Int? {
  match char {
    '0'..='9' => Some(char.to_int() - '0'.to_int())
    'a'..='f' => Some(char.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(char.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
pub fn decode_hex(value : String, label : String) -> Bytes raise Failure {
  guard value.length() % 2 == 0 else { fail("\{label}: odd hex length") }
  let output : Array[Byte] = []
  for index = 0; index < value.length(); index = index + 2 {
    guard value[index].to_char() is Some(h) &&
      value[index + 1].to_char() is Some(l) &&
      hex_nibble(h) is Some(high) &&
      hex_nibble(l) is Some(low) else {
      fail("\{label}: invalid hex at offset \{index}")
    }
    output.push(((high << 4) | low).to_byte())
  }
  Bytes::from_array(output)
}

///|
pub fn input_bytes(
  hex : String?,
  text : String?,
  label : String,
) -> Bytes raise Failure {
  match (hex, text) {
    (Some(_), Some(_)) => fail("\{label}: specify text or hex, not both")
    (Some(value), None) => decode_hex(value, label)
    (None, Some(value)) => @utf8.encode(value)
    (None, None) => b""
  }
}

///|
pub fn Case::input(
  self : Case,
  root? : String,
  http_base? : String,
) -> Bytes raise Failure {
  input_bytes(
    self.stdin_hex,
    self.stdin_text.map(value => {
      match root {
        Some(root) => expand_text(value, root, http_base?)
        None => value
      }
    }),
    self.id + " stdin",
  )
}

///|
pub fn Case::working_directory(
  self : Case,
  root : String,
) -> String raise Failure {
  match self.cwd {
    None => root
    Some(relative) => {
      guard safe_relative_path(relative) else { fail("unsafe case cwd") }
      @path.Path(root).join(Path(relative)).to_string()
    }
  }
}

///|
pub fn safe_relative_path(value : String) -> Bool {
  if value == "" || @path.Path(value).is_absolute() {
    return false
  }
  let normalized = value.replace_all(old="\\", new="/")
  if normalized.length() >= 2 && normalized[1] == ':' {
    return false
  }
  !normalized.split("/").any(part => part == "" || part == "." || part == "..")
}

///|
pub fn safe_symlink_target(value : String) -> Bool {
  if value == "" || @path.Path(value).is_absolute() {
    return false
  }
  let normalized = value.replace_all(old="\\", new="/")
  if normalized.length() >= 2 && normalized[1] == ':' {
    return false
  }
  !normalized.split("/").any(part => part == "..")
}

///|
pub fn controlled_environment(
  extra : Map[String, String],
) -> Map[String, String] {
  let result : Map[String, String] = { "LC_ALL": "C", "LANG": "C", "TZ": "UTC" }
  for name, value in extra {
    result[name] = value
  }
  result
}

///|
pub extend FixtureFile with @json.FromJson::{from_json}

///|
pub extend FixtureFile with ToJson::{to_json}

///|
pub extend FixtureFile with @debug.Debug::{to_repr}

///|
pub extend Normalization with @json.FromJson::{from_json}

///|
pub extend Normalization with ToJson::{to_json}

///|
pub extend Normalization with @debug.Debug::{to_repr}

///|
pub extend ExpectedFile with @json.FromJson::{from_json}

///|
pub extend ExpectedFile with ToJson::{to_json}

///|
pub extend ExpectedFile with @debug.Debug::{to_repr}

///|
pub extend Case with @json.FromJson::{from_json}

///|
pub extend Case with ToJson::{to_json}

///|
pub extend Case with @debug.Debug::{to_repr}
