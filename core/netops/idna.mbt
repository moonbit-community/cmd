///|
priv enum IdnaMapping {
  Valid
  Ignored
  Disallowed
  Std3Valid
  Mapped(String)
  Deviation(String)
  Std3Mapped(String)
}

///|
priv enum IdnaCategory {
  Valid
  ContextJ
  ContextO
  Disallowed
  Unassigned
}

///|
priv enum IdnaBidi {
  Left
  Right
  ArabicRight
  EuropeanNumber
  ArabicNumber
  EuropeanSeparator
  CommonSeparator
  EuropeanTerminator
  OtherNeutral
  BoundaryNeutral
  NonspacingMark
  Other
}

///|
priv enum IdnaJoining {
  NonJoining
  Left
  Right
  Dual
  Transparent
}

///|
priv suberror HostNameError {
  InvalidName
}

///|
fn[T] idna_range(
  ranges : FixedArray[(Int32, Int32, T)],
  code : Int32,
  fallback : T,
) -> T {
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let middle = low + (high - low) / 2
    let (first, last, value) = ranges[middle]
    if code < first {
      high = middle
    } else if code > last {
      low = middle + 1
    } else {
      return value
    }
  }
  fallback
}

///|
fn idna_mapping(character : Char) -> IdnaMapping {
  idna_range(idna_mappings, character.to_int(), IdnaMapping::Disallowed)
}

///|
fn idna_category(character : Char) -> IdnaCategory {
  // The pinned libidn2 2.3.7 profile retains U+19DA as PVALID. A complete
  // comparison with Unicode 15 derived properties found this one difference.
  if character.to_int() == 0x19da {
    IdnaCategory::Valid
  } else {
    idna_range(idna_categories, character.to_int(), IdnaCategory::Unassigned)
  }
}

///|
fn idna_properties(character : Char) -> (Int32, Bool, IdnaBidi) {
  idna_range(
    idna_unicode_properties,
    character.to_int(),
    (0, false, IdnaBidi::Other),
  )
}

///|
fn idna_joining(character : Char) -> IdnaJoining {
  idna_range(idna_joining_types, character.to_int(), IdnaJoining::NonJoining)
}

///|
fn idna_decode(label : String) -> String raise HostNameError {
  guard label.length() > 4 else { raise InvalidName }
  guard label
    .iter()
    .all(character => {
      character is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-' | '_')
    }) else {
    raise InvalidName
  }
  let payload = label[4:].to_owned()
  if payload.rev_find("-") is Some(index) &&
    (index == 0 || index + 1 == payload.length()) {
    raise InvalidName
  }
  let decoded = @punycode.decode(payload) catch { _ => raise InvalidName }
  guard decoded.iter().count() <= 63 else { raise InvalidName }
  decoded
}

///|
fn idna_encode(label : String) -> String raise HostNameError {
  "xn--" + (@punycode.encode(label) catch { _ => raise InvalidName })
}

///|
fn idna_map_host(
  host : String,
  transitional : Bool,
) -> String raise HostNameError {
  let mapped = StringBuilder()
  let mut count = 0
  for character in host {
    let replacement = match idna_mapping(character) {
      Valid | Std3Valid => character.to_string()
      Ignored => ""
      Disallowed => raise InvalidName
      Mapped(value) | Std3Mapped(value) => value
      Deviation(value) =>
        if transitional {
          value
        } else {
          character.to_string()
        }
    }
    count += replacement.iter().count()
    // libidn2 bounds mapped codepoints before NFC and encoded DNS lengths.
    guard count < 255 else { raise InvalidName }
    mapped.write_string(replacement)
  }
  @normalization.nfc(mapped.to_string())
}

///|
fn idna_convert_pass(
  host : String,
  transitional : Bool,
) -> String raise HostNameError {
  let mapped = idna_map_host(host, transitional)
  let labels = mapped.split(".").map(label => label.to_owned()).to_array()
  let encoded : Array[String] = []
  let mut length = 0
  for index, label in labels {
    let ace = label.has_prefix("xn--")
    let unicode = if ace { idna_decode(label) } else { label }
    idna_basic_label(unicode, transitional && !ace)
    let ascii = if !ace &&
      label.iter().all(character => character.to_int() < 128) {
      label
    } else {
      if !transitional {
        idna_nontransitional_label(unicode)
      }
      let result = idna_encode(unicode)
      if ace {
        guard result == label else { raise InvalidName }
      } else {
        guard idna_decode(result) == unicode else { raise InvalidName }
      }
      result
    }
    guard ascii.length() <= 63 else { raise InvalidName }
    let last = index + 1 == labels.length()
    let limit = if ascii.is_empty() && last { 254 } else { 253 }
    guard length + ascii.length() <= limit else { raise InvalidName }
    encoded.push(ascii)
    length += ascii.length() + (if last { 0 } else { 1 })
  }
  encoded.join(".")
}

///|
fn idna_host(host : String) -> String raise HostNameError {
  idna_convert_pass(host, false) catch {
    _ => idna_convert_pass(host, true)
  }
}
