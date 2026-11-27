///|
fn omp(key : String) -> UInt64? {
  guard @env.get_env_var(key) is Some(raw) else { return None }
  let value = raw.split(",").next().unwrap().trim()
  guard !value.is_empty() && value.iter().all(ch => ch >= '0' && ch <= '9') else {
    return None
  }
  let count = @string.parse_uint64(value) catch { _ => 0xffffffffffffffffUL }
  if count == 0UL {
    None
  } else {
    Some(count)
  }
}

///|
fn cpu_count(list : StringView) -> UInt64 raise {
  let mut count = 0UL
  for entry in list.trim().split(",") {
    let (lo, hi) = match entry.split_once("-") {
      Some(interval) => interval
      None => (entry, entry)
    }
    let first = @string.parse_uint64(lo)
    let last = @string.parse_uint64(hi)
    guard first <= last else { raise Failure::Failure("invalid CPU range") }
    count += last - first + 1UL
  }
  count
}

///|
async fn current() -> UInt64 {
  let status = @fs.read_text("/proc/self/status")
  guard status
    .split("\n")
    .filter_map(line => line.strip_prefix("Cpus_allowed_list:"))
    .next()
    is Some(cpus) else {
    raise Failure::Failure("missing process CPU affinity")
  }
  let mut count = cpu_count(cpus)
  if count == 1UL {
    return count
  }
  let stat = @fs.read_text("/proc/self/stat")
  guard stat.rev_split_once(") ") is Some((_, fields)) &&
    fields.split(" ").nth(38) is Some(policy) else {
    raise Failure::Failure("missing process scheduler policy")
  }
  if policy is ("1" | "2" | "6") {
    return count
  }
  let groups = @fs.read_text("/proc/self/cgroup")
  guard groups.split("\n").filter_map(line => line.strip_prefix("0::/")).next()
    is Some(path) else {
    return count
  }
  guard @fs.exists("/sys/fs/cgroup/cgroup.controllers") else {
    raise Failure::Failure("standard cgroup v2 mount is unavailable")
  }
  let mut dir = "/sys/fs/cgroup"
  let levels = [dir]
  for part in path.split("/") {
    if part.is_empty() {
      continue
    }
    guard !(part is ("." | "..")) else {
      raise Failure::Failure("cgroup hierarchy is outside the visible mount")
    }
    dir = dir + "/" + part.to_owned()
    levels.push(dir)
  }
  for level in levels {
    let quota = @fs.read_text(level + "/cpu.max") catch {
      @os_error.OsError(NotFound, ..) => continue
      err => raise err
    }
    guard quota.trim().split(" ").to_array() is [raw, per] else {
      raise Failure::Failure("invalid CPU quota")
    }
    if raw == "max" {
      continue
    }
    let period = @string.parse_uint64(per)
    guard period > 0UL else {
      raise Failure::Failure("invalid CPU quota period")
    }
    let value = @string.parse_uint64(raw)
    count = count.min(((value + period / 2UL) / period).max(1UL))
  }
  count
}
