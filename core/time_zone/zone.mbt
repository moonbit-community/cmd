///|
/// Timezone selected from TZ or a caller-readable TZif file. Released x/time
/// handles compatible TZif conversion; POSIX and legacy input rules stay local.
pub struct Zone {
  priv implementation : Implementation
}

///|
priv enum Implementation {
  Tzif(@time.Zone)
  Compatible(Compatibility)
}

///|
priv struct Compatibility {
  types : Array[Offset]
  transitions : Array[(Int64, Int32)]
  future : Rules?
}

///|
fn from_rules(rules : Rules) -> Zone {
  let types = [rules.standard]
  if rules.daylight is Some(offset) {
    types.push(offset)
  }
  {
    implementation: Compatible({ types, transitions: [], future: Some(rules), }),
  }
}

///|
pub async fn load(utc~ : Bool = false) -> Zone {
  let tz = @env.get_env_var("TZ")
  if utc || tz is Some("" | "UTC" | "UTC0" | "GMT" | "GMT0") {
    let name = if !utc && tz is Some("GMT" | "GMT0") { "GMT" } else { "UTC" }
    return from_rules(parse_rules(name + "0"))
  }
  let name = tz.unwrap_or(":/etc/localtime")
  let force_file = name.has_prefix(":")
  let name = name.strip_prefix(":").unwrap_or(name[:]).to_owned()
  // A POSIX rule can contain <, > and : that Windows rejects as filename
  // components. Recognize that unambiguous inline form before filesystem I/O.
  // Explicit ':'/absolute paths still retain file lookup and its real errors.
  if @async.platform is Windows &&
    !force_file &&
    !name.has_prefix("/") &&
    !name.contains("\\") &&
    !(name.length() > 1 && name[1] == ':') &&
    name.iter().any(c => c is ('<' | '>' | ':')) {
    return from_rules(parse_rules(name))
  }
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
fn Compatibility::offset(self : Compatibility, seconds : Int64) -> Offset raise {
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
  nanosecond~ : Int32 = 0,
) -> @time.ZonedDateTime raise {
  match self.implementation {
    Tzif(zone) => @time.unix(seconds, nanosecond~, zone~)
    Compatible(zone) => zone.at_unix(seconds, nanosecond~)
  }
}

///|
fn Compatibility::at_unix(
  self : Compatibility,
  seconds : Int64,
  nanosecond~ : Int32 = 0,
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
/// Preserve abbreviations even at zero offset. The public TZif loader retains
/// this metadata; the fixed-zone constructor used by POSIX rules does not.
pub fn Zone::abbreviation(self : Zone, seconds : Int64) -> String raise {
  match self.implementation {
    Tzif(zone) => @time.unix(seconds, zone~).offset().abbreviation()
    Compatible(zone) => zone.offset(seconds).name
  }
}

///|
pub fn Zone::at_local(
  self : Zone,
  plain : @time.PlainDateTime,
) -> @time.ZonedDateTime raise {
  match self.implementation {
    Tzif(zone) =>
      @time.ZonedDateTime::from_plain(plain, zone~, disambiguation=@time.Reject) catch {
        Failure::Failure(message) if message.has_suffix("Ambiguous local time") =>
          fail("ambiguous local time; use @SECONDS")
        Failure::Failure(message) if message.has_suffix(
            "Nonexistent local time",
          ) => fail("invalid local time in timezone")
        error => raise error
      }
    Compatible(zone) => zone.at_local(plain)
  }
}

///|
fn Compatibility::at_local(
  self : Compatibility,
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
