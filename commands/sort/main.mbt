///|
priv suberror CliError {
  CliError(String)
}

///|
priv enum CompareMode {
  Lexical
  Numeric
  GeneralNumeric
  HumanNumeric
  Month
  Version
  Random
} derive(Eq)

///|
priv enum GeneralNumber {
  NonNumber
  NotANumber
  NegativeInfinity
  Finite(Double)
  PositiveInfinity
}

///|
priv struct Modifiers {
  mut ignore_leading_blanks : Bool
  mut dictionary_order : Bool
  mut fold_case : Bool
  mut ignore_nonprinting : Bool
  mut mode : CompareMode
  mut reverse : Bool
}

///|
priv struct Position {
  field : Int
  character : Int
  skip_blanks : Bool
}

///|
priv struct KeySpec {
  start : Position
  end : Position?
  modifiers : Modifiers
}

///|
priv struct Entry {
  record : Bytes
  keys : Array[Bytes]
  index : Int
}

///|
fn byte_is_blank(byte : Byte) -> Bool {
  byte is (b' ' | b'\t')
}

///|
fn byte_is_digit(byte : Byte) -> Bool {
  byte is (b'0'..=b'9')
}

///|
fn byte_is_alphanumeric(byte : Byte) -> Bool {
  byte is (b'0'..=b'9' | b'a'..=b'z' | b'A'..=b'Z')
}

///|
fn split_records(data : Bytes, delimiter : Byte) -> Array[Bytes] {
  let records : Array[Bytes] = []
  let mut start = 0
  for index, byte in data {
    if byte == delimiter {
      records.push(data[start:index].to_owned())
      start = index + 1
    }
  }
  if start < data.length() {
    records.push(data[start:].to_owned())
  }
  records
}

///|
fn mode_from_order(order : Array[String]) -> CompareMode {
  for index = order.length() - 1; index >= 0; index = index - 1 {
    match order[index] {
      "numeric-sort" => return Numeric
      "general-numeric-sort" => return GeneralNumeric
      "human-numeric-sort" => return HumanNumeric
      "month-sort" => return Month
      "version-sort" => return Version
      "random-sort" => return Random
      _ => ()
    }
  }
  Lexical
}

///|
fn default_modifiers(parsed : @cli.ParsedArgs) -> Modifiers {
  {
    ignore_leading_blanks: parsed.contains("ignore-leading-blanks"),
    dictionary_order: parsed.contains("dictionary-order"),
    fold_case: parsed.contains("ignore-case"),
    ignore_nonprinting: parsed.contains("ignore-nonprinting"),
    mode: mode_from_order(parsed.order),
    reverse: parsed.contains("reverse"),
  }
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
      modifiers.mode = GeneralNumeric
      local_ordering.val = true
    }
    'h' => {
      modifiers.mode = HumanNumeric
      local_ordering.val = true
    }
    'i' => {
      modifiers.ignore_nonprinting = true
      local_ordering.val = true
    }
    'M' => {
      modifiers.mode = Month
      local_ordering.val = true
    }
    'n' => {
      modifiers.mode = Numeric
      local_ordering.val = true
    }
    'R' => {
      modifiers.mode = Random
      local_ordering.val = true
    }
    'r' => {
      modifiers.reverse = true
      local_ordering.val = true
    }
    'V' => {
      modifiers.mode = Version
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
  while index < text.length() && text[index] is ('0'..='9') {
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
    while index < text.length() && text[index] is ('0'..='9') {
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
fn parse_key(spec : String, inherited : Modifiers) -> KeySpec raise CliError {
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

///|
fn field_ranges(line : Bytes, separator : Byte?) -> Array[(Int, Int)] {
  let ranges : Array[(Int, Int)] = []
  match separator {
    Some(delimiter) => {
      let mut start = 0
      for index, byte in line {
        if byte == delimiter {
          ranges.push((start, index))
          start = index + 1
        }
      }
      ranges.push((start, line.length()))
    }
    None => {
      let mut start = 0
      let mut index = 0
      let mut seen_nonblank = false
      while index < line.length() {
        if byte_is_blank(line[index]) {
          if seen_nonblank {
            ranges.push((start, index))
            start = index
            seen_nonblank = false
          }
        } else {
          seen_nonblank = true
        }
        index += 1
      }
      if start < line.length() {
        ranges.push((start, line.length()))
      }
    }
  }
  ranges
}

///|
fn key_start(
  line : Bytes,
  position : Position,
  ranges : Array[(Int, Int)],
) -> Int {
  if position.field > ranges.length() {
    return line.length()
  }
  let (field_start, field_end) = ranges[position.field - 1]
  let mut start = field_start
  if position.skip_blanks {
    while start < field_end && byte_is_blank(line[start]) {
      start += 1
    }
  }
  Int::min(field_end, start + Int::max(0, position.character - 1))
}

///|
fn key_end(
  line : Bytes,
  position : Position,
  ranges : Array[(Int, Int)],
) -> Int {
  if position.field > ranges.length() {
    return line.length()
  }
  let (field_start, field_end) = ranges[position.field - 1]
  let mut start = field_start
  if position.skip_blanks {
    while start < field_end && byte_is_blank(line[start]) {
      start += 1
    }
  }
  if position.character == 0 {
    field_end
  } else {
    Int::min(field_end, start + position.character)
  }
}

///|
fn extract_key(line : Bytes, spec : KeySpec, separator : Byte?) -> Bytes {
  let ranges = field_ranges(line, separator)
  let start = key_start(line, spec.start, ranges)
  let end = match spec.end {
    Some(position) => key_end(line, position, ranges)
    None => line.length()
  }
  if end <= start {
    b""
  } else {
    line[start:end].to_owned()
  }
}

///|
fn transformed_key(key : Bytes, modifiers : Modifiers) -> Bytes {
  let output : Array[Byte] = []
  let mut start = 0
  if modifiers.ignore_leading_blanks {
    while start < key.length() && byte_is_blank(key[start]) {
      start += 1
    }
  }
  for byte in key[start:] {
    if modifiers.ignore_nonprinting &&
      (byte.to_int() < 0x20 || byte.to_int() > 0x7E) {
      continue
    }
    if modifiers.dictionary_order &&
      !byte_is_blank(byte) &&
      !byte_is_alphanumeric(byte) {
      continue
    }
    let value = byte.to_int()
    output.push(
      if modifiers.fold_case && value >= 0x61 && value <= 0x7A {
        (value - 0x20).to_byte()
      } else {
        byte
      },
    )
  }
  Bytes::from_array(output)
}

///|
fn numeric_slice(key : Bytes, exponent : Bool, allow_plus : Bool) -> Bytes? {
  let mut index = 0
  while index < key.length() && byte_is_blank(key[index]) {
    index += 1
  }
  let start = index
  if index < key.length() && key[index] is b'-' {
    index += 1
  } else if allow_plus && index < key.length() && key[index] is b'+' {
    index += 1
  }
  let mut digits = 0
  while index < key.length() && byte_is_digit(key[index]) {
    digits += 1
    index += 1
  }
  if index < key.length() && key[index] is b'.' {
    index += 1
    while index < key.length() && byte_is_digit(key[index]) {
      digits += 1
      index += 1
    }
  }
  if exponent &&
    digits > 0 &&
    index < key.length() &&
    (key[index] is b'e' || key[index] is b'E') {
    let exponent_start = index
    index += 1
    if index < key.length() && (key[index] is b'+' || key[index] is b'-') {
      index += 1
    }
    let exponent_digits = index
    while index < key.length() && byte_is_digit(key[index]) {
      index += 1
    }
    if exponent_digits == index {
      index = exponent_start
    }
  }
  if digits == 0 {
    return None
  }
  Some(key[start:index].to_owned())
}

///|
fn numeric_prefix(key : Bytes, exponent : Bool) -> Double {
  match numeric_slice(key, exponent, exponent) {
    Some(number) =>
      @string.parse_double(@utf8.decode(number)) catch {
        _ => 0.0
      }
    None => 0.0
  }
}

///|
fn ascii_lower_byte(byte : Byte) -> Byte {
  let value = byte.to_int()
  if value >= 0x41 && value <= 0x5A {
    (value + 0x20).to_byte()
  } else {
    byte
  }
}

///|
fn ascii_prefix_at(key : Bytes, index : Int, prefix : Bytes) -> Bool {
  if index + prefix.length() > key.length() {
    return false
  }
  for offset, byte in prefix {
    if ascii_lower_byte(key[index + offset]) != byte {
      return false
    }
  }
  true
}

///|
fn general_number(key : Bytes) -> GeneralNumber {
  let mut index = 0
  while index < key.length() && byte_is_blank(key[index]) {
    index += 1
  }
  let mut negative = false
  if index < key.length() && key[index] is b'-' {
    negative = true
    index += 1
  } else if index < key.length() && key[index] is b'+' {
    index += 1
  }
  if ascii_prefix_at(key, index, b"nan") {
    return NotANumber
  }
  if ascii_prefix_at(key, index, b"inf") {
    return if negative { NegativeInfinity } else { PositiveInfinity }
  }
  match numeric_slice(key, true, true) {
    None => NonNumber
    Some(number) => {
      let value = @string.parse_double(@utf8.decode(number)) catch {
        _ => return NonNumber
      }
      if value.is_nan() {
        NotANumber
      } else if value.is_inf() {
        if value < 0.0 {
          NegativeInfinity
        } else {
          PositiveInfinity
        }
      } else {
        Finite(value)
      }
    }
  }
}

///|
fn general_compare(left : Bytes, right : Bytes) -> Int {
  match (general_number(left), general_number(right)) {
    (NonNumber, NonNumber) | (NotANumber, NotANumber) => 0
    (NonNumber, _) => -1
    (_, NonNumber) => 1
    (NotANumber, _) => -1
    (_, NotANumber) => 1
    (NegativeInfinity, NegativeInfinity) => 0
    (NegativeInfinity, _) => -1
    (_, NegativeInfinity) => 1
    (PositiveInfinity, PositiveInfinity) => 0
    (PositiveInfinity, _) => 1
    (_, PositiveInfinity) => -1
    (Finite(left), Finite(right)) => left.compare(right)
  }
}

///|
fn human_parts(key : Bytes) -> (Int, Int, Double) {
  let mut index = 0
  while index < key.length() && byte_is_blank(key[index]) {
    index += 1
  }
  let start = index
  if index < key.length() && key[index] is b'-' {
    index += 1
  } else if index < key.length() && key[index] is b'+' {
    return (0, 0, 0.0)
  }
  let mut digits = 0
  while index < key.length() && byte_is_digit(key[index]) {
    digits += 1
    index += 1
  }
  if index < key.length() && key[index] is b'.' {
    index += 1
    while index < key.length() && byte_is_digit(key[index]) {
      digits += 1
      index += 1
    }
  }
  if digits == 0 {
    return (0, 0, 0.0)
  }
  let number = @string.parse_double(@utf8.decode(key[start:index].to_owned())) catch {
    _ => 0.0
  }
  let power = if index < key.length() {
    match key[index] {
      b'K' | b'k' => 1
      b'M' => 2
      b'G' => 3
      b'T' => 4
      b'P' => 5
      b'E' => 6
      b'Z' => 7
      b'Y' => 8
      b'R' => 9
      b'Q' => 10
      _ => 0
    }
  } else {
    0
  }
  let sign = if number < 0.0 { -1 } else if number > 0.0 { 1 } else { 0 }
  (sign, power, number)
}

///|
fn human_compare(left : Bytes, right : Bytes) -> Int {
  let (left_sign, left_power, left_value) = human_parts(left)
  let (right_sign, right_power, right_value) = human_parts(right)
  if left_sign != right_sign {
    return left_sign - right_sign
  }
  if left_power != right_power {
    return if left_sign < 0 {
      right_power - left_power
    } else {
      left_power - right_power
    }
  }
  left_value.compare(right_value)
}

///|
fn month_value(key : Bytes) -> Int {
  let text = transformed_key(key, {
    ignore_leading_blanks: true,
    dictionary_order: false,
    fold_case: true,
    ignore_nonprinting: false,
    mode: Lexical,
    reverse: false,
  })
  let text = @utf8.decode(text) catch { _ => "" }
  if text.length() < 3 {
    return 0
  }
  match text[0:3].to_owned() {
    "JAN" => 1
    "FEB" => 2
    "MAR" => 3
    "APR" => 4
    "MAY" => 5
    "JUN" => 6
    "JUL" => 7
    "AUG" => 8
    "SEP" => 9
    "OCT" => 10
    "NOV" => 11
    "DEC" => 12
    _ => 0
  }
}

///|
fn version_compare(left : Bytes, right : Bytes) -> Int {
  let mut li = 0
  let mut ri = 0
  while li < left.length() || ri < right.length() {
    if li < left.length() && left[li] is b'~' {
      if ri < right.length() && right[ri] is b'~' {
        li += 1
        ri += 1
        continue
      }
      return -1
    }
    if ri < right.length() && right[ri] is b'~' {
      return 1
    }
    if li == left.length() {
      return -1
    }
    if ri == right.length() {
      return 1
    }
    if byte_is_digit(left[li]) && byte_is_digit(right[ri]) {
      let mut lzero = li
      while lzero < left.length() && left[lzero] is b'0' {
        lzero += 1
      }
      let mut rzero = ri
      while rzero < right.length() && right[rzero] is b'0' {
        rzero += 1
      }
      let mut lend = lzero
      while lend < left.length() && byte_is_digit(left[lend]) {
        lend += 1
      }
      let mut rend = rzero
      while rend < right.length() && byte_is_digit(right[rend]) {
        rend += 1
      }
      let llen = lend - lzero
      let rlen = rend - rzero
      if llen != rlen {
        return llen - rlen
      }
      let cmp = left[lzero:lend].lexical_compare(right[rzero:rend])
      if cmp != 0 {
        return cmp
      }
      li = lend
      ri = rend
    } else {
      if left[li] != right[ri] {
        return left[li].to_int() - right[ri].to_int()
      }
      li += 1
      ri += 1
    }
  }
  0
}

///|
fn compare_key(left : Bytes, right : Bytes, modifiers : Modifiers) -> Int {
  let left = transformed_key(left, modifiers)
  let right = transformed_key(right, modifiers)
  let result = match modifiers.mode {
    Lexical => left.lexical_compare(right)
    Numeric => numeric_prefix(left, false).compare(numeric_prefix(right, false))
    GeneralNumeric => general_compare(left, right)
    HumanNumeric => human_compare(left, right)
    Month => month_value(left) - month_value(right)
    Version => version_compare(left, right)
    Random => 0
  }
  if modifiers.reverse {
    -result
  } else {
    result
  }
}

///|
fn compare_entries(
  left : Entry,
  right : Entry,
  specs : Array[KeySpec],
  global : Modifiers,
  last_resort : Bool,
) -> Int {
  if specs.is_empty() {
    let result = compare_key(left.record, right.record, global)
    if result != 0 || !last_resort {
      return result
    }
  } else {
    for index, spec in specs {
      let result = compare_key(
        left.keys[index],
        right.keys[index],
        spec.modifiers,
      )
      if result != 0 {
        return result
      }
    }
    if !last_resort {
      return 0
    }
  }
  let result = left.record.lexical_compare(right.record)
  if global.reverse {
    -result
  } else {
    result
  }
}

///|
async fn read_source(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
  }
}

///|
fn normalized_args(args : ArrayView[String]) -> Array[String] {
  args.map(arg => if arg == "--check=quiet" { "--check-quiet" } else { arg })
}

///|
async fn main {
  let parsed = @cli.parse(normalized_args(@env.args()[1:]), [
    @cli.flag("reverse", short='r'),
    @cli.flag("numeric-sort", short='n'),
    @cli.flag("general-numeric-sort", short='g'),
    @cli.flag("human-numeric-sort", short='h'),
    @cli.flag("month-sort", short='M'),
    @cli.flag("version-sort", short='V'),
    @cli.flag("random-sort", short='R'),
    @cli.flag("unique", short='u'),
    @cli.flag("ignore-case", short='f'),
    @cli.flag("ignore-leading-blanks", short='b'),
    @cli.flag("dictionary-order", short='d'),
    @cli.flag("ignore-nonprinting", short='i'),
    @cli.flag("zero-terminated", short='z'),
    @cli.flag("check", short='c'),
    @cli.flag("check-quiet", short='C'),
    @cli.option("key", short='k'),
    @cli.option("field-separator", short='t'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("sort: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: sort [-bcdfghinMruVz] [-k KEY] [-t CHAR] [-c|-C] [FILE...]\n",
    )
    return
  }
  let global = default_modifiers(parsed)
  if global.mode == Random {
    @stdio.stderr.write(
      "sort: random sort requires a deterministic seed contract\n",
    )
    @sys.exit(2)
    return
  }
  if parsed.contains("check") && parsed.contains("check-quiet") {
    @stdio.stderr.write("sort: options '-c' and '-C' are incompatible\n")
    @sys.exit(2)
    return
  }
  let separator = match parsed.last_value("field-separator") {
    Some(text) => {
      let bytes = @utf8.encode(text)
      if bytes.length() != 1 {
        @stdio.stderr.write("sort: the field separator must be a single byte\n")
        @sys.exit(2)
        return
      }
      Some(bytes[0])
    }
    None => None
  }
  let specs : Array[KeySpec] = []
  for key in parsed.values("key") {
    let spec = parse_key(key, global) catch {
      CliError(message) => {
        @stdio.stderr.write(message + "\n")
        @sys.exit(2)
        return
      }
    }
    if spec.modifiers.mode == Random {
      @stdio.stderr.write(
        "sort: random sort requires a deterministic seed contract\n",
      )
      @sys.exit(2)
      return
    }
    specs.push(spec)
  }
  let delimiter : Byte = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
  let check = parsed.contains("check") || parsed.contains("check-quiet")
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  if check && sources.length() > 1 {
    @stdio.stderr.write("sort: extra operand in check mode\n")
    @sys.exit(2)
    return
  }
  let records : Array[Bytes] = []
  for path in sources {
    let data = read_source(path) catch {
      err => {
        @stdio.stderr.write("sort: \{err}\n")
        @sys.exit(1)
        return
      }
    }
    records.append(split_records(data, delimiter))
  }
  let entries : Array[Entry] = []
  for index, record in records {
    let keys = specs.map(spec => extract_key(record, spec, separator))
    entries.push({ record, keys, index, })
  }
  if check {
    for index in 1..<entries.length() {
      let ordering = compare_entries(
        entries[index - 1],
        entries[index],
        specs,
        global,
        true,
      )
      let duplicate = parsed.contains("unique") &&
        compare_entries(
          entries[index - 1],
          entries[index],
          specs,
          global,
          false,
        ) ==
        0
      if ordering > 0 || duplicate {
        if parsed.contains("check") {
          let record = @utf8.decode(entries[index].record) catch { _ => "" }
          @stdio.stderr.write("sort: -:\{index + 1}: disorder: \{record}\n")
        }
        @sys.exit(1)
        return
      }
    }
    return
  }
  entries.sort_by((left, right) => {
    let result = compare_entries(
      left,
      right,
      specs,
      global,
      !parsed.contains("unique"),
    )
    if result == 0 {
      left.index - right.index
    } else {
      result
    }
  })
  let mut previous : Entry? = None
  for entry in entries {
    let emit = match previous {
      Some(old) if parsed.contains("unique") =>
        compare_entries(old, entry, specs, global, false) != 0
      _ => true
    }
    if emit {
      @stdio.stdout.write(entry.record)
      @stdio.stdout.write(if delimiter is b'\x00' { b"\x00" } else { b"\n" })
      previous = Some(entry)
    }
  }
}
