///|
priv suberror DateError {
  DateError(String)
}

///|
fn pad(value : Int, width : Int) -> String {
  let text = value.to_string()
  if text.length() >= width {
    text
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
fn parse_instant(value : String) -> @time.ZonedDateTime raise DateError {
  if value.has_prefix("@") {
    let seconds = @string.parse_int64(value[1:].to_owned()) catch {
      _ => raise DateError("invalid date '\{value}'")
    }
    @time.unix(seconds, zone=@time.utc_zone) catch {
      _ => raise DateError("invalid date '\{value}'")
    }
  } else {
    let normalized = value.replace(old=" ", new="T")
    let plain : @time.PlainDateTime = @string.from_str(normalized) catch {
      _ => raise DateError("invalid date '\{value}'")
    }
    @time.ZonedDateTime::from_plain_datetime(plain, zone=@time.utc_zone)
  }
}

///|
fn format_date(value : @time.ZonedDateTime, format : String) -> String {
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
      'y' => pad(value.year() % 100, 2)
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
      'F' => "\{value.year()}-\{pad(value.month(), 2)}-\{pad(value.day(), 2)}"
      'T' =>
        "\{pad(value.hour(), 2)}:\{pad(value.minute(), 2)}:\{pad(value.second(), 2)}"
      'R' => "\{pad(value.hour(), 2)}:\{pad(value.minute(), 2)}"
      's' => value.to_unix_second().to_string()
      'N' => pad(value.nanosecond(), 9)
      'z' => compact_offset(value.offset())
      'Z' => "UTC"
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
fn iso_format(value : String) -> String raise DateError {
  match value {
    "date" | "" => "%Y-%m-%d"
    "hours" => "%Y-%m-%dT%H+00:00"
    "minutes" => "%Y-%m-%dT%H:%M+00:00"
    "seconds" => "%Y-%m-%dT%H:%M:%S+00:00"
    "ns" => "%Y-%m-%dT%H:%M:%S.%N+00:00"
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
      "Usage: date [OPTION]... [+FORMAT]\nPrint a UTC timestamp; -d accepts ISO-like text or @SECONDS.\n",
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
  let instant = match parsed.last_value("date") {
    Some(value) =>
      parse_instant(value) catch {
        DateError(message) => {
          @stdio.stderr.write("date: \{message}\n")
          @sys.exit(1)
          return
        }
      }
    None =>
      @time.unix(@env.now().reinterpret_as_int64() / 1000L, zone=@time.utc_zone)
  }
  let format = if parsed.contains("rfc-email") {
    "%a, %d %b %Y %H:%M:%S +0000"
  } else if parsed.contains("iso") {
    iso_format(parsed.last_value("iso").unwrap_or("date")) catch {
      DateError(message) => {
        @stdio.stderr.write("date: \{message}\n")
        @sys.exit(1)
        return
      }
    }
  } else if parsed.operands.length() == 1 && parsed.operands[0].has_prefix("+") {
    parsed.operands[0][1:].to_owned()
  } else if parsed.operands.is_empty() {
    "%a %b %e %H:%M:%S UTC %Y"
  } else {
    @stdio.stderr.write("date: extra operand\n")
    @sys.exit(1)
    return
  }
  @stdio.stdout.write(format_date(instant, format) + "\n")
}
