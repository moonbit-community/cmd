///|
priv suberror DateError {
  DateError(String)
}

///|
fn pad(value : Int, width : Int) -> String {
  let text = value.to_string()
  if text.length() >= width {
    text
  } else if value < 0 {
    "-" + "0".repeat(width - text.length()) + text[1:].to_owned()
  } else {
    "0".repeat(width - text.length()) + text
  }
}

///|
fn weekday_short(value : @time.Weekday) -> String {
  match value {
    Monday => "Mon"
    Tuesday => "Tue"
    Wednesday => "Wed"
    Thursday => "Thu"
    Friday => "Fri"
    Saturday => "Sat"
    Sunday => "Sun"
  }
}

///|
fn weekday_long(value : @time.Weekday) -> String {
  match value {
    Monday => "Monday"
    Tuesday => "Tuesday"
    Wednesday => "Wednesday"
    Thursday => "Thursday"
    Friday => "Friday"
    Saturday => "Saturday"
    Sunday => "Sunday"
  }
}

///|
fn month_short(month : Int) -> String {
  [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ][month - 1]
}

///|
fn month_long(month : Int) -> String {
  [
    "January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December",
  ][month - 1]
}

///|
fn compact_offset(offset : @time.ZoneOffset) -> String {
  let seconds = offset.seconds()
  let sign = if seconds < 0 { "-" } else { "+" }
  let absolute = if seconds < 0 { -seconds } else { seconds }
  sign + pad(absolute / 3600, 2) + pad(absolute / 60 % 60, 2)
}

///|
fn parse_instant(
  value : String,
  zone : @time_zone.Zone,
) -> @time.ZonedDateTime raise {
  if value.has_prefix("@") {
    let text = value[1:].to_owned()
    let parts = text.split(".").map(p => p.to_owned()).collect()
    guard parts.length() <= 2 else {
      raise DateError("invalid date '\{value}'")
    }
    let mut seconds = @string.parse_int64(parts[0])
    let mut nanos = 0
    if parts.length() == 2 {
      let fraction = parts[1]
      guard fraction.length() >= 1 &&
        fraction.length() <= 9 &&
        fraction.iter().all(c => c is ('0'..='9')) else {
        raise DateError("invalid fractional timestamp")
      }
      nanos = @string.parse_int(fraction + "0".repeat(9 - fraction.length()))
      if text.has_prefix("-") && nanos > 0 {
        guard seconds > -9223372036854775808L else {
          raise DateError("timestamp out of range")
        }
        seconds -= 1L
        nanos = 1000000000 - nanos
      }
    }
    zone.at_unix(seconds, nanosecond=nanos)
  } else {
    let normalized = value.replace(old=" ", new="T")
    let normalized = if normalized.contains("T") {
      normalized
    } else {
      normalized + "T00:00:00"
    }
    let plain : @time.PlainDateTime = @string.from_str(normalized) catch {
      _ => raise DateError("invalid date '\{value}'")
    }
    zone.at_local(plain)
  }
}

///|
fn format_date(
  value : @time.ZonedDateTime,
  format : String,
  abbreviation? : String,
) -> String raise DateError {
  let chars : Array[Char] = format.iter().collect()
  let output = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '%' || index + 1 >= chars.length() {
      output.write_char(chars[index])
      index += 1
      continue
    }
    let code = chars[index + 1]
    let rendered = match code {
      '%' => "%"
      'Y' => pad(value.year(), 4)
      'y' => pad((value.year() % 100).abs(), 2)
      'm' => pad(value.month(), 2)
      'd' => pad(value.day(), 2)
      'e' =>
        if value.day() < 10 {
          " \{value.day()}"
        } else {
          value.day().to_string()
        }
      'H' => pad(value.hour(), 2)
      'M' => pad(value.minute(), 2)
      'S' => pad(value.second(), 2)
      'j' => pad(value.ordinal(), 3)
      'a' => weekday_short(value.weekday())
      'A' => weekday_long(value.weekday())
      'b' | 'h' => month_short(value.month())
      'B' => month_long(value.month())
      'F' =>
        "\{pad(value.year(), 4)}-\{pad(value.month(), 2)}-\{pad(value.day(), 2)}"
      'T' =>
        "\{pad(value.hour(), 2)}:\{pad(value.minute(), 2)}:\{pad(value.second(), 2)}"
      'R' => "\{pad(value.hour(), 2)}:\{pad(value.minute(), 2)}"
      's' => value.to_unix_second().to_string()
      'N' => pad(value.nanosecond(), 9)
      'z' => compact_offset(value.offset())
      'Z' => abbreviation.unwrap_or(value.offset().abbreviation())
      'C'
      | 'D'
      | 'c'
      | 'x'
      | 'X'
      | 'I'
      | 'k'
      | 'l'
      | 'p'
      | 'P'
      | 'r'
      | 'n'
      | 't'
      | 'u'
      | 'w'
      | 'U'
      | 'W'
      | 'V'
      | 'g'
      | 'G'
      | 'q'
      | ':'
      | '-'
      | '_'
      | '^'
      | '#'
      | '+'
      | '0'..='9'
      | 'E'
      | 'O' =>
        raise DateError(
          "unsupported format directive or modifier: %" + code.to_string(),
        )
      _ => "%" + code.to_string()
    }
    output.write_string(rendered)
    index += 2
  }
  output.to_string()
}

///|
fn normalize_args(raw : ArrayView[String]) -> Array[String] {
  let args : Array[String] = []
  for arg in raw {
    if arg == "--iso-8601" {
      args.push("--iso=date")
    } else if arg.has_prefix("--iso-8601=") {
      args.push("--iso=" + arg[11:].to_owned())
    } else if arg == "-I" {
      args.push("--iso=date")
    } else if arg.has_prefix("-I") && arg.length() > 2 {
      args.push("--iso=" + arg[2:].to_owned())
    } else {
      args.push(arg)
    }
  }
  args
}

///|
fn iso_format(
  value : String,
  instant : @time.ZonedDateTime,
) -> String raise DateError {
  let compact = compact_offset(instant.offset())
  let offset = compact[:3].to_owned() + ":" + compact[3:].to_owned()
  match value {
    "date" | "" => "%Y-%m-%d"
    "hours" => "%Y-%m-%dT%H" + offset
    "minutes" => "%Y-%m-%dT%H:%M" + offset
    "seconds" => "%Y-%m-%dT%H:%M:%S" + offset
    "ns" => "%Y-%m-%dT%H:%M:%S,%N" + offset
    _ => raise DateError("invalid ISO-8601 precision '\{value}'")
  }
}

///|
async fn main {
  let parsed = @cli.parse(normalize_args(@env.args()[1:]), [
    @cli.flag("utc", short='u'),
    @cli.option("date", short='d'),
    @cli.option("iso"),
    @cli.flag("rfc-email", short='R'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("date: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: date [OPTION]... [+FORMAT]\nPrint time in TZ or the host local timezone.\n  -u, --utc           use UTC\n  -d, --date=TEXT     ISO date/time or @SECONDS (up to 9 fractional digits)\n  -I[PRECISION], --iso-8601[=PRECISION]\n                      date, hours, minutes, seconds, or ns\n  -R, --rfc-email     RFC email timestamp\n      --help          display this help and exit\n      --version       display version and exit\nFormats: %Y %y %m %d %e %H %M %S %j %a %A %b %h %B %F %T %R %s %N %z %Z %%\nRelative date parsing and setting the clock are unsupported.\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("date (cli) \{command_version}\n")
    return
  }
  if parsed.contains("rfc-email") && parsed.contains("iso") {
    @stdio.stderr.write("date: conflicting output formats\n")
    @sys.exit(1)
    return
  }
  if parsed.operands.length() > 1 ||
    parsed.operands.any(arg => !arg.has_prefix("+")) ||
    (
      !parsed.operands.is_empty() &&
      (parsed.contains("rfc-email") || parsed.contains("iso"))
    ) {
    @stdio.stderr.write("date: extra operand or conflicting output formats\n")
    @sys.exit(1)
    return
  }
  let (instant, abbreviation) = try {
    let zone = @time_zone.load(utc=parsed.contains("utc"))
    let value = match parsed.last_value("date") {
      Some(value) => parse_instant(value, zone)
      None => {
        let milliseconds = @env.now().reinterpret_as_int64()
        zone.at_unix(
          milliseconds / 1000L,
          nanosecond=(milliseconds % 1000L).to_int() * 1000000,
        )
      }
    }
    (value, zone.abbreviation(value.to_unix_second()))
  } catch {
    DateError(message) => {
      @stdio.stderr.write("date: \{message}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("date: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  let format = if parsed.contains("rfc-email") {
    "%a, %d %b %Y %H:%M:%S %z"
  } else if parsed.contains("iso") {
    iso_format(parsed.last_value("iso").unwrap_or("date"), instant) catch {
      DateError(message) => {
        @stdio.stderr.write("date: \{message}\n")
        @sys.exit(1)
        return
      }
    }
  } else if parsed.operands.length() == 1 && parsed.operands[0].has_prefix("+") {
    parsed.operands[0][1:].to_owned()
  } else if parsed.operands.is_empty() {
    "%a %b %e %H:%M:%S %Z %Y"
  } else {
    @stdio.stderr.write("date: extra operand\n")
    @sys.exit(1)
    return
  }
  let rendered = format_date(instant, format, abbreviation~) catch {
    DateError(message) => {
      @stdio.stderr.write("date: \{message}\n")
      @sys.exit(1)
      return
    }
  }
  @stdio.stdout.write(rendered + "\n")
}
