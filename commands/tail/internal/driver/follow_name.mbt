///|
priv enum NameState {
  Initial
  Waiting(String)
  Open(@xfs.File, @xfs.FileIdentity, offset~ : Int64)
}

///|
fn NameState::close(self : NameState) -> Unit {
  if self is Open(file, _, ..) {
    file.close()
  }
}

///|
async fn open_named_regular(path : String) -> (@xfs.File, @xfs.FileIdentity) {
  // Avoid opening a named pipe while polling a regular log. Recheck the kind
  // on the acquired handle because a different object can occupy the name.
  guard @std_fs.kind(path) is Regular else { fail("not a regular file") }
  let file = @xfs.open(path, mode=ReadOnly)
  errdefer file.close()
  guard file.kind() is Regular else { fail("not a regular file") }
  guard file.identity() is Some(id) else { fail("file identity unavailable") }
  (file, id)
}

///|
fn open_message(error : Error) -> String {
  match error {
    @os_error.OsError(NotFound, ..) => "No such file or directory"
    @os_error.OsError(NotDirectory, ..) => "Not a directory"
    @os_error.OsError(AccessDenied, ..) => "Permission denied"
    Failure(message) => message
    other => other.to_string()
  }
}

///|
async fn follow_names(
  paths : Array[String],
  spec : CountSpec,
  bytes_mode : Bool,
  delimiter : Byte,
  interval_ms : Int32,
  show_headers : Bool,
) -> Unit {
  let states = Array::make(paths.length(), NameState::Initial)
  defer (for state in states {
    state.close()
  })
  let mut last_output = -1
  let buffer : FixedArray[Byte] = FixedArray::make(CHUNK_SIZE, 0)
  for ;; {
    for index, path in paths {
      let previous = states[index]
      let (file, id, offset) = match previous {
        Open(file, id, offset~) if (@xfs.identity(path) catch { _ => None }) ==
          Some(id) => (file, id, offset)
        _ => {
          let (file, id) = open_named_regular(path) catch {
            error => {
              let message = open_message(error)
              match previous {
                Initial =>
                  @stdio.stderr.write(
                    "tail: cannot open '\{path}' for reading: \{message}\n",
                  )
                Waiting(last) if last == message => ()
                _ =>
                  @stdio.stderr.write(
                    "tail: '\{path}' has become inaccessible: \{message}\n",
                  )
              }
              previous.close()
              states[index] = Waiting(message)
              continue
            }
          }
          previous.close()
          states[index] = Open(file, id, offset=0)
          match previous {
            Initial => {
              if show_headers {
                @stdio.stdout.write(
                  (if last_output < 0 { "" } else { "\n" }) +
                  "==> \{path} <==\n",
                )
                last_output = index
              }
              let offset = tail_file(
                file.size(),
                (len, position) => {
                  let chunk : FixedArray[Byte] = FixedArray::make(len, 0)
                  guard file.read_into_at(chunk.mut_view(), position~) == len else {
                    fail("unexpected EOF while reading \{path}")
                  }
                  chunk.unsafe_reinterpret_as_bytes()
                },
                spec,
                bytes_mode,
                delimiter~,
              )
              states[index] = Open(file, id, offset~)
              continue
            }
            Waiting(_) =>
              @stdio.stderr.write(
                "tail: '\{path}' has appeared;  following new file\n",
              )
            Open(_, _, ..) =>
              @stdio.stderr.write(
                "tail: '\{path}' has been replaced;  following new file\n",
              )
          }
          (file, id, 0L)
        }
      }
      let size = file.size()
      let mut position = offset
      if size < position {
        @stdio.stderr.write("tail: \{path}: file truncated\n")
        position = 0
      }
      while position < size {
        let amount = (size - position).min(CHUNK_SIZE.to_int64()).to_int()
        let n = file.read_into_at(buffer.mut_view(end=amount), position~)
        if n == 0 {
          break
        }
        if show_headers && index != last_output {
          @stdio.stdout.write(
            (if last_output < 0 { "" } else { "\n" }) + "==> \{path} <==\n",
          )
        }
        last_output = index
        @stdio.stdout.write(Bytes::from_array(buffer[:n]))
        position += n.to_int64()
      }
      states[index] = Open(file, id, offset=position)
    }
    @async.sleep(interval_ms)
  }
}
