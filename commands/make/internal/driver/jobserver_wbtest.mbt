///|
priv struct FailedTokenReturn {
  mut attempts : Int32
  bytes : Array[Byte]
}

///|
impl @io.Writer for FailedTokenReturn with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  self.attempts += 1
  self.bytes.append(bytes[offset:offset + len].to_array())
  raise MakeError("injected token return failure")
}

///|
async test "jobserver token return failures propagate and are never retried" {
  let (server, reader, writer) = test_jobserver()
  defer server.close()
  let failed : FailedTokenReturn = { attempts: 0, bytes: [], }
  let server = { ..server, writer: failed, }
  server.implicit.acquire()
  defer server.implicit.release()
  writer.write(b"Q")
  try server.with_slot(() => ()) catch {
    MakeError(message) => assert_eq(message, "injected token return failure")
    err => raise err
  } noraise {
    _ => fail("token return failure disappeared")
  }
  assert_eq(failed.attempts, 1)
  assert_eq(Bytes::from_array(failed.bytes), b"Q")
  assert_eq(@async.with_timeout_opt(30, () => reader.read_exactly(1)), None)
}

///|
fn test_jobserver() -> (Jobserver, @pipe.PipeRead, @pipe.PipeWrite) raise {
  let (reader, writer) = @pipe.pipe()
  let server : Jobserver = {
    reader,
    writer,
    close_handles: () => {
      reader.close()
      writer.close()
    },
    implicit: @semaphore.Semaphore(1),
    acquiring: @async.Mutex(),
  }
  (server, reader, writer)
}

///|
async test "jobserver returns the exact borrowed byte after success failure and cancellation" {
  let (server, reader, writer) = test_jobserver()
  defer server.close()
  server.implicit.acquire()
  defer server.implicit.release()
  writer.write(b"AB")
  server.with_slot(() => assert_eq(reader.read_exactly(1), b"B"))
  assert_eq(reader.read_exactly(1), b"A")
  writer.write(b"Q")
  let failing : async () -> Unit = () => raise MakeError("recipe failure")
  try server.with_slot(failing) catch {
    MakeError(message) => assert_eq(message, "recipe failure")
    err => raise err
  } noraise {
    _ => fail("recipe failure disappeared")
  }
  assert_eq(reader.read_exactly(1), b"Q")
  writer.write(b"\xff")
  assert_eq(
    @async.with_timeout_opt(30, () => {
      server.with_slot(() => @async.sleep(60000))
    }),
    None,
  )
  assert_eq(reader.read_exactly(1), b"\xff")
  assert_eq(@async.with_timeout_opt(30, () => reader.read_exactly(1)), None)
}

///|
async test "jobserver simultaneous readiness neither loses a token nor invents an implicit slot" {
  let (server, reader, writer) = test_jobserver()
  defer server.close()
  for _ in 0..<32 {
    writer.write(b"Z")
    let calls = Ref(0)
    server.with_slot(() => calls.val += 1)
    assert_eq(calls.val, 1)
    assert_eq(reader.read_exactly(1), b"Z")
    assert_true(server.implicit.try_acquire())
    assert_false(server.implicit.try_acquire())
    server.implicit.release()
  }
  assert_eq(@async.with_timeout_opt(30, () => reader.read_exactly(1)), None)
}

///|
async test "jobserver wakes on its implicit slot without waiting for a FIFO byte" {
  let (server, reader, _) = test_jobserver()
  defer server.close()
  server.implicit.acquire()
  let calls = Ref(0)
  @async.with_timeout(2000, () => {
    @async.with_task_group(group => {
      let waiting = group.spawn(() => server.with_slot(() => calls.val += 1))
      @async.pause()
      server.implicit.release()
      waiting.wait()
    })
  })
  assert_eq(calls.val, 1)
  assert_eq(@async.with_timeout_opt(30, () => reader.read_exactly(1)), None)
}

///|
test "MAKEFLAGS authentication takes the last entry and preserves escaped paths" {
  let words = makeflag_words(
    "ks -j3 --jobserver-auth=3,4 --jobserver-auth=fifo:/tmp/two\\ words -- VALUE=a\\ b",
  )
  assert_eq(inherited_jobserver(words), Some("fifo:/tmp/two words"))
  assert_eq(inherited_make_arguments(words), ["-k", "-s", "-j3", "VALUE=a b"])
  assert_eq(makeflag_words(escape_makeflag("x\\y z\tw")), ["x\\y z\tw"])
  assert_eq(
    inherited_jobserver(makeflag_words("-- --jobserver-auth=wrong")),
    None,
  )
}

///|
test "MAKEFLAGS option values remain distinct from assignments" {
  let words = makeflag_words(
    "--jobs 2 --jobserver-auth fifo:/tmp/token=value -- -X=two\\ words",
  )
  assert_eq(inherited_jobserver(words), Some("fifo:/tmp/token=value"))
  assert_eq(inherited_make_arguments(words, include_assignments=false), ["-j2"])
  assert_eq(inherited_make_assignments(words), [("-X", "=", "two words")])
  assert_eq(inherited_make_arguments(words), ["-j2", "-X=two words"])
  assert_eq(
    serial_child_flags("--jobs 2 -- -X=two\\ words"),
    "-j1 -- -X=two\\ words",
  )
}
