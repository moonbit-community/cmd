///|
pub(all) enum TimestampKind {
  AccessTime
  ModificationTime
  StatusChangeTime
} derive(Eq, Debug)

///|
pub(all) struct FileTimestamp {
  seconds : Int64
  nanoseconds : Int
} derive(Eq, Debug)

///|
pub fn compare_timestamps(left : FileTimestamp, right : FileTimestamp) -> Int {
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
pub fn timestamp_age_bucket(
  now : FileTimestamp,
  timestamp : FileTimestamp,
  bucket_seconds : Int64,
) -> Int64 raise FsOpError {
  if bucket_seconds <= 0L {
    raise FsOpError("timestamp bucket must be positive")
  }
  let mut elapsed_seconds = now.seconds - timestamp.seconds
  if now.nanoseconds < timestamp.nanoseconds {
    elapsed_seconds -= 1L
  }
  if elapsed_seconds >= 0L {
    elapsed_seconds / bucket_seconds
  } else {
    -((-elapsed_seconds + bucket_seconds - 1L) / bucket_seconds)
  }
}

///|
pub async fn read_file_timestamp(
  path : String,
  kind : TimestampKind,
  follow_symlink? : Bool = true,
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
