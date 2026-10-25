///|
fn resource_number(
  value : String,
  label : String,
) -> (Int64, Int32) raise CliError {
  let mut start = 0
  while start < value.length() &&
        value[start] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    start += 1
  }
  if start < value.length() && value[start] == '+' {
    start += 1
  }
  let mut end = start
  let mut number = 0L
  while end < value.length() && value[end] >= '0' && value[end] <= '9' {
    let digit = (value[end].to_int() - '0'.to_int()).to_int64()
    if number > (9223372036854775807L - digit) / 10L {
      raise CliError("sort: \{label} argument '\{value}' too large")
    }
    number = number * 10L + digit
    end += 1
  }
  if end == start {
    raise CliError("sort: invalid \{label} argument '\{value}'")
  }
  (number, end)
}

///|
fn buffer_size(value : String) -> Int64 raise CliError {
  let suffix_power = (suffix : String) => {
    match suffix {
      "K" | "k" => Some(1)
      "M" | "m" => Some(2)
      "G" | "g" => Some(3)
      "T" | "t" => Some(4)
      "P" => Some(5)
      "E" => Some(6)
      "Z" => Some(7)
      "Y" => Some(8)
      "R" => Some(9)
      "Q" => Some(10)
      _ => None
    }
  }
  let (amount, end) = if suffix_power(value) is Some(_) {
    (1L, 0)
  } else {
    resource_number(value, "--buffer-size")
  }
  let mut number = amount
  let suffix = value[end:]
  if suffix == "%" {
    if number == 0L {
      return 0L
    }
    raise CliError(
      "sort: unsupported capability: percentage buffer size requires a public physical-memory query",
    )
  }
  let power = match suffix {
    "" => 1
    "b" => 0
    _ =>
      match suffix_power(suffix.to_owned()) {
        Some(power) => power
        None =>
          raise CliError("sort: invalid --buffer-size argument '\{value}'")
      }
  }
  for _ in 0..<power {
    if number > 9223372036854775807L / 1024L {
      raise CliError("sort: --buffer-size argument '\{value}' too large")
    }
    number *= 1024L
  }
  number
}

///|
fn resource_controls(parsed : @cli.ParsedArgs) -> (Int64, Int32) raise CliError {
  let sizes = parsed.values("buffer-size")
  let mut budget = if sizes.is_empty() { 67108864L } else { 0L }
  for value in sizes {
    budget = budget.max(buffer_size(value))
  }
  let mut fan_in = 16
  for value in parsed.values("batch-size") {
    let (number, end) = resource_number(value, "--batch-size")
    if end != value.length() {
      raise CliError("sort: invalid --batch-size argument '\{value}'")
    }
    if number < 2 {
      raise CliError(
        "sort: invalid --batch-size argument '\{value}'\nsort: minimum --batch-size argument is '2'",
      )
    }
    fan_in = number.min(16L).to_int()
  }
  (budget, fan_in)
}

///|
async fn temporary_root(parent : String) -> String {
  for _ in 0..<32 {
    let random = match @env.rand(16) {
      Some(bytes) => @crypto.bytes_to_hex_string(bytes)
      None => raise CliError("sort: secure random source is unavailable")
    }
    let path = parent + "/cli-sort-" + random
    try @fs.mkdir(path, permission=0o700) catch {
      @os_error.OSError(_) as error if error.is_EEXIST() => ()
      error => raise error
    } noraise {
      _ => return path
    }
  }
  raise CliError("sort: cannot create an exclusive temporary directory")
}
