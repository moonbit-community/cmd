///|
#derive(Eq, Debug)
pub(all) enum TimestampKind {
  AccessTime
  ModificationTime
  StatusChangeTime
}

///|
#derive(Eq, Debug)
pub(all) struct FileTimestamp {
  seconds : Int64
  nanoseconds : Int32
}

///|
pub fn compare_timestamps(left : FileTimestamp, right : FileTimestamp) -> Int32 {
  if left.seconds < right.seconds {
    -1
  } else if left.seconds > right.seconds {
    1
  } else if left.nanoseconds < right.nanoseconds {
    -1
  } else if left.nanoseconds > right.nanoseconds {
    1
  } else {
    0
  }
}

///|
pub async fn read_file_timestamp(
  path : String,
  kind : TimestampKind,
  follow_symlink~ : Bool = true,
) -> FileTimestamp {
  let path = @platform.normalize_input_separators(path)
  let (seconds, nanoseconds) = match kind {
    AccessTime => @fs.atime(path, follow_symlink~)
    ModificationTime => @fs.mtime(path, follow_symlink~)
    StatusChangeTime => @fs.ctime(path, follow_symlink~)
  }
  { seconds, nanoseconds, }
}

///|
pub fn current_timestamp() -> FileTimestamp {
  let milliseconds = @env.now().reinterpret_as_int64()
  {
    seconds: milliseconds / 1000L,
    nanoseconds: (milliseconds % 1000L * 1000000L).to_int(),
  }
}

///|
pub extend TimestampKind with Eq::{not_equal, equal}

///|
pub extend TimestampKind with @debug.Debug::{to_repr}

///|
pub extend FileTimestamp with Eq::{not_equal, equal}

///|
pub extend FileTimestamp with @debug.Debug::{to_repr}
