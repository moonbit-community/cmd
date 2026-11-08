///|
#derive(Eq, Debug)
pub(all) enum UpdateMode {
  UpdateAll
  UpdateNone
  UpdateNoneFail
  UpdateOlder
}

///|
#derive(Eq, Debug)
pub(all) enum BackupControl {
  NoBackup
  SimpleBackup
  NumberedBackup
  ExistingBackup
}

///|
#derive(Eq, Debug)
pub(all) enum OverwriteDecision {
  ReplaceDestination
  SkipDestination
  RejectDestination
}

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
fn backup_number(name : String) -> (String, String)? {
  guard name.has_suffix("~") && name.rev_find(".~") is Some(marker) else {
    return None
  }
  let start = marker + 2
  if name.length() <= start + 1 {
    return None
  }
  let digits = name[start:name.length() - 1]
  if !(digits[0] is ('1'..<='9')) {
    return None
  }
  for digit in digits {
    if !(digit is ('0'..<='9')) {
      return None
    }
  }
  Some((name[:marker].to_owned(), digits.to_owned()))
}

///|
async fn backup_alias_exists(path : String, number : String) -> Bool {
  try (kind_if_exists(path + ".~" + number + "~") is Some(_)) catch {
    // An unrelated short basename can have a suffix too long for this target.
    @os_error.OSError(code, ..) if code == name_too_long_code() => false
    error => raise error
  }
}

///|
fn name_too_long_code() -> Int32 {
  // Released OSError exposes native errno/GetLastError, but no named predicate
  // for this code. OS definitions and replacement conditions are in ADR-0004.
  match @async.platform {
    Linux => 36
    MacOS => 63
    Windows => 206
  }
}

///|
async fn highest_backup_number(path : String) -> String? {
  let directory = dirname(path)
  let base = basename(path)
  let entries = @fs.readdir(
    directory,
    include_hidden=true,
    include_special=false,
    sort=false,
  )
  let mut highest : String? = None
  for entry in entries {
    if backup_number(entry) is Some((entry_base, number)) {
      let larger = match highest {
        Some(previous) =>
          number.length() > previous.length() ||
          (number.length() == previous.length() && number > previous)
        None => true
      }
      if larger && (entry_base == base || backup_alias_exists(path, number)) {
        // Let the filesystem identify aliases; never assume case folding.
        highest = Some(number)
      }
    }
  }
  highest
}

///|
fn next_backup_number(number : String) -> String {
  // Decimal names may exceed machine integers; carry directly through digits.
  let digits : Array[Char] = number.iter().collect()
  for index = digits.length() - 1; index >= 0; index = index - 1 {
    if digits[index] == '9' {
      digits[index] = '0'
    } else {
      digits[index] = (digits[index].to_int() + 1).to_char().unwrap()
      return String::from_array(digits)
    }
  }
  "1" + String::from_array(digits)
}

///|
priv struct Backup {
  path : String
  replace : Bool
}

///|
async fn select_backup(
  path : String,
  control : BackupControl,
  suffix~ : String = "~",
) -> Backup? {
  match control {
    NoBackup => None
    SimpleBackup => Some({ path: path + suffix, replace: true, })
    NumberedBackup | ExistingBackup =>
      match highest_backup_number(path) {
        Some(number) =>
          Some({
            path: path + ".~" + next_backup_number(number) + "~",
            replace: false,
          })
        None =>
          if control == NumberedBackup {
            Some({ path: path + ".~1~", replace: false, })
          } else {
            Some({ path: path + suffix, replace: true, })
          }
      }
  }
}

///|
pub async fn select_backup_path(
  path : String,
  control : BackupControl,
  suffix~ : String = "~",
) -> String? {
  select_backup(path, control, suffix~).map(backup => backup.path)
}

///|
async fn rename_backup(
  source : String,
  destination : String,
  replace : Bool,
) -> Unit {
  @fs.rename(source, destination, replace~)
}

///|
async fn backup_entry(
  path : String,
  control : BackupControl,
  suffix~ : String = "~",
  rename~ : async (String, String, Bool) -> Unit = rename_backup,
) -> String? {
  guard kind_if_exists(path) is Some(_) else { return None }
  guard select_backup(path, control, suffix~) is Some(backup) else {
    return None
  }
  rename(path, backup.path, backup.replace)
  Some(backup.path)
}

///|
pub async fn backup_destination(
  path : String,
  control : BackupControl,
  suffix~ : String = "~",
) -> String? {
  backup_entry(path, control, suffix~)
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

///|
pub extend UpdateMode with Eq::{not_equal, equal}

///|
pub extend UpdateMode with @debug.Debug::{to_repr}

///|
pub extend BackupControl with Eq::{not_equal, equal}

///|
pub extend BackupControl with @debug.Debug::{to_repr}

///|
pub extend OverwriteDecision with Eq::{not_equal, equal}

///|
pub extend OverwriteDecision with @debug.Debug::{to_repr}
