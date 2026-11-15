///|
fn byte_is_alphanumeric(byte : Byte) -> Bool {
  byte is (b'0'..<=b'9' | b'a'..<=b'z' | b'A'..<=b'Z')
}

///|
pub fn mode_from_flags(flags : Int32) -> CompareMode {
  for
    (mode, flag) in [
      (Random, 16),
      (Numeric, 1),
      (GeneralNumeric, 2),
      (HumanNumeric, 4),
      (Month, 8),
      (Version, 32),
    ] {
    if (flags & flag) != 0 {
      return mode
    }
  }
  Lexical
}

///|
pub fn ordering_flag(mode : CompareMode) -> Int32 {
  match mode {
    Numeric => 1
    GeneralNumeric => 2
    HumanNumeric => 4
    Month => 8
    Random => 16
    Version => 32
    Lexical => 0
  }
}

///|
fn add_ordering(modifiers : Modifiers, mode : CompareMode) -> Unit {
  modifiers.ordering_modes = modifiers.ordering_modes | ordering_flag(mode)
  if mode != Version || modifiers.mode == Lexical {
    modifiers.mode = mode
  }
}

///|
pub fn validate_ordering(modifiers : Modifiers) -> Unit raise CliError {
  let modes = modifiers.ordering_modes & 31
  if (modes & (modes - 1)) == 0 {
    return
  }
  let flags = StringBuilder()
  if modifiers.ignore_leading_blanks {
    flags.write_char('b')
  }
  if modifiers.dictionary_order {
    flags.write_char('d')
  }
  if modifiers.fold_case {
    flags.write_char('f')
  }
  if (modifiers.ordering_modes & 2) != 0 {
    flags.write_char('g')
  }
  if (modifiers.ordering_modes & 4) != 0 {
    flags.write_char('h')
  }
  if modifiers.ignore_nonprinting {
    flags.write_char('i')
  }
  if (modifiers.ordering_modes & 8) != 0 {
    flags.write_char('M')
  }
  if (modifiers.ordering_modes & 1) != 0 {
    flags.write_char('n')
  }
  if (modifiers.ordering_modes & 16) != 0 {
    flags.write_char('R')
  }
  if modifiers.reverse {
    flags.write_char('r')
  }
  if (modifiers.ordering_modes & 32) != 0 {
    flags.write_char('V')
  }
  raise CliError("sort: options '-\{flags.to_string()}' are incompatible")
}

///|
fn apply_modifier(
  modifier : Char,
  modifiers : Modifiers,
  local_ordering : Ref[Bool],
) -> Unit raise CliError {
  match modifier {
    'b' => modifiers.ignore_leading_blanks = true
    'd' => {
      modifiers.dictionary_order = true
      local_ordering.val = true
    }
    'f' => {
      modifiers.fold_case = true
      local_ordering.val = true
    }
    'g' => {
      add_ordering(modifiers, GeneralNumeric)
      local_ordering.val = true
    }
    'h' => {
      add_ordering(modifiers, HumanNumeric)
      local_ordering.val = true
    }
    'i' => {
      modifiers.ignore_nonprinting = true
      local_ordering.val = true
    }
    'M' => {
      add_ordering(modifiers, Month)
      local_ordering.val = true
    }
    'n' => {
      add_ordering(modifiers, Numeric)
      local_ordering.val = true
    }
    'R' => {
      add_ordering(modifiers, Random)
      local_ordering.val = true
    }
    'r' => {
      modifiers.reverse = true
      local_ordering.val = true
    }
    'V' => {
      add_ordering(modifiers, Version)
      local_ordering.val = true
    }
    _ =>
      raise CliError(
        "sort: invalid field specification modifier: '\{modifier}'",
      )
  }
}

///|
fn parse_position(
  text : String,
  spec : String,
  inherited : Modifiers,
  end_position : Bool,
) -> (Position, Modifiers, Bool) raise CliError {
  let mut index = 0
  while index < text.length() && text[index] is ('0'..<='9') {
    index += 1
  }
  if index == 0 {
    raise CliError("sort: invalid field specification: '\{spec}'")
  }
  let field = @string.parse_int(text[0:index]) catch {
    _ => raise CliError("sort: invalid field specification: '\{spec}'")
  }
  if field < 1 {
    raise CliError("sort: field number is zero: '\{spec}'")
  }
  let mut character = if end_position { 0 } else { 1 }
  if index < text.length() && text[index] is '.' {
    index += 1
    let start = index
    while index < text.length() && text[index] is ('0'..<='9') {
      index += 1
    }
    if start == index {
      raise CliError("sort: invalid number after '.': '\{spec}'")
    }
    character = @string.parse_int(text[start:index]) catch {
      _ => raise CliError("sort: invalid field specification: '\{spec}'")
    }
    if !end_position && character == 0 {
      raise CliError("sort: character offset is zero: '\{spec}'")
    }
  }
  let modifiers : Modifiers = {
    ignore_leading_blanks: false,
    dictionary_order: false,
    fold_case: false,
    ignore_nonprinting: false,
    mode: Lexical,
    ordering_modes: 0,
    reverse: false,
  }
  let local_ordering = Ref(false)
  for modifier in text[index:] {
    apply_modifier(modifier, modifiers, local_ordering)
  }
  let skip_blanks = modifiers.ignore_leading_blanks
  if !local_ordering.val {
    modifiers.dictionary_order = inherited.dictionary_order
    modifiers.fold_case = inherited.fold_case
    modifiers.ignore_nonprinting = inherited.ignore_nonprinting
    modifiers.mode = inherited.mode
    modifiers.ordering_modes = inherited.ordering_modes
    modifiers.reverse = inherited.reverse
  }
  if inherited.ignore_leading_blanks {
    modifiers.ignore_leading_blanks = true
  }
  (
    {
      field,
      character,
      skip_blanks: skip_blanks || inherited.ignore_leading_blanks,
    },
    modifiers,
    local_ordering.val,
  )
}

///|
pub fn parse_key(
  spec : String,
  inherited : Modifiers,
) -> KeySpec raise CliError {
  let pieces : Array[String] = spec
    .split(",")
    .map(piece => piece.to_owned())
    .collect()
  if pieces.length() > 2 || pieces.is_empty() || pieces[0] == "" {
    raise CliError("sort: invalid key specification: '\{spec}'")
  }
  let (start, start_modifiers, start_local) = parse_position(
    pieces[0],
    spec,
    inherited,
    false,
  )
  let mut modifiers = start_modifiers
  let end = if pieces.length() == 2 {
    if pieces[1] == "" {
      raise CliError("sort: invalid key specification: '\{spec}'")
    }
    let (position, end_modifiers, end_local) = parse_position(
      pieces[1],
      spec,
      inherited,
      true,
    )
    if start_local || end_local {
      modifiers = {
        ignore_leading_blanks: start_modifiers.ignore_leading_blanks,
        dictionary_order: (start_local && start_modifiers.dictionary_order) ||
        (end_local && end_modifiers.dictionary_order),
        fold_case: (start_local && start_modifiers.fold_case) ||
        (end_local && end_modifiers.fold_case),
        ignore_nonprinting: (start_local && start_modifiers.ignore_nonprinting) ||
        (end_local && end_modifiers.ignore_nonprinting),
        mode: if end_local && end_modifiers.mode != Lexical {
          end_modifiers.mode
        } else if start_local {
          start_modifiers.mode
        } else {
          Lexical
        },
        ordering_modes: (if start_local {
          start_modifiers.ordering_modes
        } else {
          0
        }) |
        (if end_local { end_modifiers.ordering_modes } else { 0 }),
        reverse: (start_local && start_modifiers.reverse) ||
        (end_local && end_modifiers.reverse),
      }
    } else {
      modifiers = inherited
    }
    Some(position)
  } else {
    None
  }
  if modifiers.ordering_modes != 0 {
    modifiers.mode = mode_from_flags(modifiers.ordering_modes)
  }
  if end is Some(position) &&
    (
      position.field < start.field ||
      (
        position.field == start.field &&
        position.character != 0 &&
        position.character < start.character
      )
    ) {
    raise CliError("sort: invalid key specification: '\{spec}'")
  }
  { start, end, modifiers, }
}
