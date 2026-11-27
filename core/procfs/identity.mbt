///|
/// Numeric credentials reported by the running Linux process.
pub(all) struct Credentials {
  real_uid : String
  effective_uid : String
  real_gid : String
  effective_gid : String
  groups : Array[String]
}

///|
fn status_ids(status : String, key : String) -> Array[String] raise {
  for line in status.split("\n") {
    if line.strip_prefix(key) is Some(rest) {
      return rest
        .trim()
        .split(" ")
        .flat_map(part => part.split("\t"))
        .filter_map(part => {
          if part.is_empty() {
            None
          } else {
            Some(part.to_owned())
          }
        })
        .to_array()
    }
  }
  raise Failure::Failure("missing process credential " + key)
}

///|
pub async fn credentials() -> Credentials {
  guard @async.platform is Linux else {
    raise Failure::Failure("process credentials require Linux procfs")
  }
  let status = @fs.read_text("/proc/self/status")
  guard status_ids(status, "Uid:") is [real_uid, effective_uid, _, _] &&
    status_ids(status, "Gid:") is [real_gid, effective_gid, _, _] else {
    raise Failure::Failure("incomplete Linux process credentials")
  }
  let groups = [real_gid]
  if effective_gid != real_gid {
    groups.push(effective_gid)
  }
  for gid in status_ids(status, "Groups:") {
    if gid != real_gid && gid != effective_gid {
      groups.push(gid)
    }
  }
  { real_uid, effective_uid, real_gid, effective_gid, groups, }
}

///|
pub(all) enum NameDatabase {
  Passwd
  Group
}

///|
/// Resolve an ID only if the local file is the authoritative first NSS source.
pub async fn local_names(
  database : NameDatabase,
  ids : Array[String],
) -> Array[String] {
  let name = match database {
    Passwd => "passwd"
    Group => "group"
  }
  let config = @fs.read_text("/etc/nsswitch.conf")
  let mut files_first = false
  for line in config.split("\n") {
    let entry = line.split("#").next().unwrap().trim()
    let parts = entry.split(":").to_array()
    if parts is [key, sources] && key.trim() == name[:] {
      let words = sources
        .trim()
        .split(" ")
        .flat_map(word => word.split("\t"))
        .filter(word => !word.is_empty())
        .to_array()
      files_first = words is ["files", ..] &&
        !(words is [_, next, ..] && next.has_prefix("["))
      break
    }
  }
  guard files_first else {
    raise Failure::Failure(
      "cannot resolve " + name + " through the configured name service",
    )
  }
  let names : Map[String, String] = Map([])
  for line in @fs.read_text("/etc/" + name).split("\n") {
    let fields = line.split(":").to_array()
    if fields is [login, _, id, ..] &&
      !login.is_empty() &&
      !names.contains(id.to_owned()) {
      names[id.to_owned()] = login.to_owned()
    }
  }
  ids.map(id => {
    names
    .get(id)
    .unwrap_or_else(() => {
      raise Failure::Failure("no local " + name + " entry for " + id)
    })
  })
}
