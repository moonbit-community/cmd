///|
pub async fn current(cred : @procfs.Credentials) -> String {
  if @env.get_env_var("POSIXLY_CORRECT") is None {
    let filesystems = @fs.read_text("/proc/filesystems")
    if filesystems
      .split("\n")
      .any(line => {
        line.trim().has_suffix("\tselinuxfs") ||
        line.trim().has_suffix("\tsmackfs")
      }) {
      raise Failure::Failure(
        "security context is unavailable; POSIXLY_CORRECT selects the POSIX report",
      )
    }
  }
  guard cred.real_gid == cred.effective_gid else {
    raise Failure::Failure(
      "default report for differing real and effective groups is unavailable",
    )
  }
  let user_ids = if cred.real_uid == cred.effective_uid {
    [cred.real_uid]
  } else {
    [cred.real_uid, cred.effective_uid]
  }
  let users = @procfs.local_names(Passwd, user_ids)
  let groups = @procfs.local_names(Group, cred.groups)
  let label = fn(id : String, name : String) { id + "(" + name + ")" }
  let output = [
    "uid=" + label(cred.real_uid, users[0]),
    "gid=" + label(cred.real_gid, groups[0]),
  ]
  if users.length() == 2 {
    output.push("euid=" + label(cred.effective_uid, users[1]))
  }
  let memberships = []
  for i, id in cred.groups {
    if i == 0 || id != cred.groups[i - 1] {
      memberships.push(label(id, groups[i]))
    }
  }
  output.push("groups=" + memberships.join(","))
  output.join(" ")
}
