///|
pub(all) enum UpdateMode {
  UpdateAll
  UpdateNone
  UpdateNoneFail
  UpdateOlder
} derive(Eq, Debug)

///|
pub(all) enum BackupControl {
  NoBackup
  SimpleBackup
  NumberedBackup
  ExistingBackup
} derive(Eq, Debug)

///|
pub(all) enum OverwriteDecision {
  ReplaceDestination
  SkipDestination
  RejectDestination
} derive(Eq, Debug)

///|
pub fn parse_update_mode(value : String) -> UpdateMode raise FsOpError {
  match value {
    "all" => UpdateAll
    "none" => UpdateNone
    "none-fail" => UpdateNoneFail
    "older" => UpdateOlder
    _ => raise FsOpError("invalid update mode: '\{value}'")
  }
}

///|
pub fn parse_backup_control(value : String) -> BackupControl raise FsOpError {
  match value {
    "none" | "off" => NoBackup
    "simple" | "never" => SimpleBackup
    "numbered" | "t" => NumberedBackup
    "existing" | "nil" => ExistingBackup
    _ => raise FsOpError("invalid backup control: '\{value}'")
  }
}

///|
pub fn overwrite_decision(
  update : UpdateMode,
  source_time : FileTimestamp,
  destination_time : FileTimestamp?,
) -> OverwriteDecision {
  guard destination_time is Some(destination_time) else {
    return ReplaceDestination
  }
  match update {
    UpdateAll => ReplaceDestination
    UpdateNone => SkipDestination
    UpdateNoneFail => RejectDestination
    UpdateOlder =>
      if compare_timestamps(source_time, destination_time) > 0 {
        ReplaceDestination
      } else {
        SkipDestination
      }
  }
}

///|
fn is_numbered_backup(name : String, base : String) -> Bool {
  let prefix = base + ".~"
  if !name.has_prefix(prefix) || !name.has_suffix("~") {
    return false
  }
  let digits = name[prefix.length():name.length() - 1]
  if digits == "" {
    return false
  }
  for digit in digits {
    if !(digit is ('0'..='9')) {
      return false
    }
  }
  true
}

///|
async fn numbered_backups_exist(path : String) -> Bool {
  let directory = dirname(path)
  let base = basename(path)
  let entries = @fs.readdir(
    directory,
    include_hidden=true,
    include_special=false,
    sort=false,
  ) catch {
    _ => return false
  }
  entries.any(name => is_numbered_backup(name, base))
}

///|
async fn next_numbered_backup(path : String) -> String {
  for number = 1; ; number = number + 1 {
    let candidate = path + ".~" + number.to_string() + "~"
    if kind_if_exists(candidate) is None {
      return candidate
    }
  }
}

///|
pub async fn select_backup_path(
  path : String,
  control : BackupControl,
  suffix? : String = "~",
) -> String? {
  match control {
    NoBackup => None
    SimpleBackup => Some(path + suffix)
    NumberedBackup => Some(next_numbered_backup(path))
    ExistingBackup =>
      if numbered_backups_exist(path) {
        Some(next_numbered_backup(path))
      } else {
        Some(path + suffix)
      }
  }
}

///|
pub async fn backup_destination(
  path : String,
  control : BackupControl,
  suffix? : String = "~",
) -> String? {
  guard kind_if_exists(path) is Some(_) else { return None }
  guard select_backup_path(path, control, suffix~) is Some(backup) else {
    return None
  }
  @fs.rename(
    path,
    backup,
    replace=control == SimpleBackup || control == ExistingBackup,
  )
  Some(backup)
}

///|
pub async fn restore_backup(path : String, backup : String) -> Unit {
  match kind_if_exists(path) {
    Some(Directory) => remove_path(path, true)
    Some(_) => remove_path(path, false)
    None => ()
  }
  @fs.rename(backup, path, replace=false)
}
