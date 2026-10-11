///|
/// Timezone selected from TZ or the host TZif file. All timestamp conversion
/// uses checked 64-bit TZif transitions, including POSIX future rules.
pub struct Zone {
  priv types : Array[Offset]
  priv transitions : Array[(Int64, Int)]
  priv future : Rules?
}

///|
fn from_rules(rules : Rules) -> Zone {
  let types = [rules.standard]
  if rules.daylight is Some(offset) {
    types.push(offset)
  }
  { types, transitions: [], future: Some(rules), }
}

///|
pub async fn load(utc? : Bool = false) -> Zone {
  let tz = @env.get_env_var("TZ")
  if utc || tz is Some("" | "UTC" | "UTC0" | "GMT" | "GMT0") {
    let name = if !utc && tz is Some("GMT" | "GMT0") { "GMT" } else { "UTC" }
    return from_rules(parse_rules(name + "0"))
  }
  let name = tz.unwrap_or(":/etc/localtime")
  let name = name.strip_prefix(":").unwrap_or(name[:]).to_owned()
  let file = if name.has_prefix("/") ||
    name.contains("\\") ||
    (name.length() > 1 && name[1] == ':') {
    name
  } else {
    @env.get_env_var("TZDIR").unwrap_or("/usr/share/zoneinfo") + "/" + name
  }
  if @fs.exists(file) {
    return decode(@fs.read_file(file).binary())
  }
  if tz is None {
    fail("local timezone database unavailable; set TZ or use -u")
  }
  from_rules(parse_rules(name))
}

///|
fn Zone::offset(self : Zone, seconds : Int64) -> Offset raise {
  if self.transitions.is_empty() ||
    seconds > self.transitions[self.transitions.length() - 1].0 {
    if self.future is Some(rules) {
      return rules.offset(seconds)
    }
  }
  let mut selected = 0
  for (instant, index) in self.transitions {
    if instant > seconds {
      break
    }
    selected = index
  }
  self.types[selected]
}

///|
pub fn Zone::at_unix(
  self : Zone,
  seconds : Int64,
  nanosecond? : Int = 0,
) -> @time.ZonedDateTime raise {
  let offset = self.offset(seconds)
  let zone = @time.fixed_zone(
    offset.name,
    offset.seconds,
    abbrev=offset.name,
    dst=offset.dst,
  )
  @time.unix(seconds, nanosecond~, zone~)
}

///|
/// Preserve TZif abbreviations even at zero offset, where x/time 0.5.5's
/// ZoneOffset factory substitutes the shared UTC value.
pub fn Zone::abbreviation(self : Zone, seconds : Int64) -> String raise {
  self.offset(seconds).name
}

///|
pub fn Zone::at_local(
  self : Zone,
  plain : @time.PlainDateTime,
) -> @time.ZonedDateTime raise {
  let offsets = self.types.map(t => t.seconds)
  if self.future is Some(rules) {
    offsets.push(rules.standard.seconds)
    if rules.daylight is Some(daylight) {
      offsets.push(daylight.seconds)
    }
  }
  let mut found : @time.ZonedDateTime? = None
  for offset in offsets {
    let seconds = plain.to_unix_second() - offset.to_int64()
    let value = self.at_unix(seconds, nanosecond=plain.nanosecond())
    if value.to_plain_date_time() == plain {
      if found is Some(previous) && previous.to_unix_second() != seconds {
        fail("ambiguous local time; use @SECONDS")
      }
      found = Some(value)
    }
  }
  match found {
    Some(value) => value
    None => fail("invalid local time in timezone")
  }
}
