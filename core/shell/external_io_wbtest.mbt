///|
priv suberror TransferFailure {
  TransferFailure
}

///|
priv struct FailingTransferWriter {
  mut calls : Int32
  bytes : Array[Byte]
  os_error : Bool
}

///|
impl @io.Writer for FailingTransferWriter with fn write_once(
  self,
  data,
  offset~,
  len~,
) {
  self.calls += 1
  if len > 0 {
    self.bytes.push(data[offset])
  }
  if self.os_error {
    raise @os_error.OSError(
      @os_error.errno_ENOTDIR,
      context="injected output write",
    )
  }
  raise TransferFailure
}

///|
async test "real external child output failures propagate without replay or later commands" {
  let root = @fs.tmpdir(prefix="cmd-sh-child-io-")
  defer @fs.rmdir(root, recursive=true)
  for
    (name, command, failure_channel, os_error) in [
      ("stdout", "moon --version", 1, false),
      ("stderr", "moon --invalid-cmd-shell-io-probe", 2, false),
      ("merged", "moon --version 2>&1", 1, false),
      ("typed-os-error", "moon --version", 1, true),
    ] {
    let failure : FailingTransferWriter = { calls: 0, bytes: [], os_error, }
    let other : CaptureBuffer = { bytes: [], }
    let failing_writer : &@io.Writer = failure
    let other_writer : &@io.Writer = other
    let output = if failure_channel == 1 {
      failing_writer
    } else {
      other_writer
    }
    let error = if failure_channel == 2 { failing_writer } else { other_writer }
    let session = Session::new(cwd=root, output~, error~)
    try session.feed(command + "; printf wrong > " + name) catch {
      TransferFailure => assert_false(os_error)
      @os_error.OSError(code, context~) => {
        assert_true(os_error)
        assert_eq(code, @os_error.errno_ENOTDIR)
        assert_eq(context, "injected output write")
      }
      error => raise error
    } noraise {
      _ => fail("output failure became an ordinary shell exit status")
    }
    assert_eq(failure.calls, 1)
    assert_eq(failure.bytes.length(), 1)
    assert_false(@fs.exists(root + "/" + name))
  }
}

///|
async test "command substitution preserves a nonlanguage diagnostic write failure" {
  let root = @fs.tmpdir(prefix="cmd-sh-substitution-io-")
  defer @fs.rmdir(root, recursive=true)
  let failure : FailingTransferWriter = {
    calls: 0,
    bytes: [],
    os_error: false,
  }
  let output : CaptureBuffer = { bytes: [], }
  let session = Session::new(cwd=root, output~, error=failure)
  try session.feed("VALUE=$(printf err >&2); printf wrong > marker") catch {
    TransferFailure => ()
    error => raise error
  } noraise {
    _ => fail("substitution relabeled an I/O failure as a shell language error")
  }
  assert_eq(failure.calls, 1)
  assert_eq(failure.bytes.length(), 1)
  assert_eq(output.bytes.length(), 0)
  assert_false(@fs.exists(root + "/marker"))
}
