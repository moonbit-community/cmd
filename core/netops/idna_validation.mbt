///|
fn idna_basic_label(
  label : String,
  transitional : Bool,
) -> Unit raise HostNameError {
  let characters = label.iter().to_array()
  guard @normalization.nfc(label) == label else { raise InvalidName }
  if characters.is_empty() {
    return
  }
  guard characters[0] != '-' && characters[characters.length() - 1] != '-' else {
    raise InvalidName
  }
  guard !(characters.length() >= 4 &&
    characters[2] == '-' &&
    characters[3] == '-') else {
    raise InvalidName
  }
  guard !idna_properties(characters[0]).1 else { raise InvalidName }
  for character in characters {
    guard character != '.' else { raise InvalidName }
    match idna_mapping(character) {
      Valid | Std3Valid | Std3Mapped(_) => ()
      Deviation(_) if !transitional => ()
      _ => raise InvalidName
    }
  }
}

///|
fn idna_joiner_allowed(characters : Array[Char], index : Int32) -> Bool {
  if index > 0 && idna_properties(characters[index - 1]).0 == 9 {
    return true
  }
  if characters[index] != '\u200c' ||
    index == 0 ||
    index + 1 == characters.length() {
    return false
  }
  let mut left = index - 1
  while left > 0 && idna_joining(characters[left]) is Transparent {
    left -= 1
  }
  guard idna_joining(characters[left]) is (Left | Dual) else { return false }
  let mut right = index + 1
  while right + 1 < characters.length() &&
        idna_joining(characters[right]) is Transparent {
    right += 1
  }
  idna_joining(characters[right]) is (Right | Dual)
}

///|
fn idna_bidi_allowed(characters : Array[Char]) -> Bool {
  let classes = characters.map(character => idna_properties(character).2)
  if !classes.iter().any(value => value is (Right | ArabicRight | ArabicNumber)) {
    return true
  }
  guard !classes.is_empty() else { return true }
  let rtl = match classes[0] {
    Left => false
    Right | ArabicRight => true
    _ => return false
  }
  let mut ending = true
  for value in classes[1:] {
    match value {
      EuropeanSeparator
      | CommonSeparator
      | EuropeanTerminator
      | OtherNeutral
      | BoundaryNeutral => ending = false
      EuropeanNumber | NonspacingMark => ending = true
      Right | ArabicRight | ArabicNumber if rtl => ending = true
      Left if !rtl => ending = true
      _ => return false
    }
  }
  // The pinned lookup checks each label separately and accepts mixed EN/AN;
  // a trailing NSM restores its accepted-ending state even after punctuation.
  ending
}

///|
fn idna_nontransitional_label(label : String) -> Unit raise HostNameError {
  let characters = label.iter().to_array()
  for index, character in characters {
    match idna_category(character) {
      Valid => ()
      Disallowed => {
        guard idna_mapping(character) is (Std3Valid | Std3Mapped(_)) else {
          raise InvalidName
        }
      }
      Unassigned => raise InvalidName
      ContextJ => {
        guard idna_joiner_allowed(characters, index) else { raise InvalidName }
      }
      ContextO => {
        // This profile checks that a context rule exists, without executing
        // the optional CONTEXTO validation rules during lookup.
        guard character.to_int()
          is (0x00b7
          | 0x0375
          | 0x05f3
          | 0x05f4
          | 0x0660..<=0x0669
          | 0x06f0..<=0x06f9
          | 0x30fb) else {
          raise InvalidName
        }
      }
    }
  }
  guard idna_bidi_allowed(characters) else { raise InvalidName }
}
