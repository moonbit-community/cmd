///|
/// Files, pipes, sockets and block devices cannot be terminals. A character
/// device requires an actual terminal ioctl before its status is known.
pub fn require_redirected(fd : Int32) -> Unit raise {
  guard fd >= 0 && fd <= 2 else {
    raise TerminalError(2, "unsupported descriptor")
  }
  let dir = match @async.platform {
    Linux => "/proc/self/fd/"
    MacOS => "/dev/fd/"
    _ => raise TerminalError(2, "descriptor inspection is unavailable")
  }
  let kind = if @async.platform is MacOS {
    // Darwin fdescfs path metadata describes the descriptor node. Opening it
    // duplicates the existing description and exposes the underlying file kind.
    let handle = @file.open(
      dir + fd.to_string(),
      mode=if fd == 0 { ReadOnly } else { WriteOnly },
    )
    defer handle.close()
    handle.kind()
  } else {
    @file.kind(dir + fd.to_string())
  }
  match kind {
    Regular | Directory | Pipe | Socket | BlockDevice => ()
    _ => raise TerminalError(2, "terminal device identity is unavailable")
  }
}
