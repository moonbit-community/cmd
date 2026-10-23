///|
fn oracle_container_test_result(
  status~ : Int32 = 0,
  stdout~ : Bytes = b"",
  timed_out~ : Bool = false,
  cleanup_error~ : String? = None,
) -> TimedRun {
  { output: { status, stdout, stderr: b"", }, timed_out, cleanup_error, }
}

///|
fn oracle_container_test_inspect(
  name : String,
  token : String,
  id : String,
) -> Bytes {
  @utf8.encode(
    canonical_json([
      {
        "Id": Json(id),
        "Name": Json("/" + name),
        "Config": { "Labels": { "io.moonbit.cmd.oracle-owner": Json(token) } },
        "State": { "Status": "running", "Running": true, "Pid": 123 },
      },
    ]),
  )
}

///|
async fn clear_oracle_test_reservation(evidence : String) -> Unit {
  match @json.parse(@fs.read_file(evidence + "/lifecycle.json").text()) {
    { "reservation": String(path), .. } => {
      assert_true(
        @fs.exists(path),
        msg="uncertain cleanup must retain its reservation",
      )
      @fs.rmdir(path, recursive=true)
    }
    _ => fail("missing retained invocation reservation")
  }
}

///|
async test "owned oracle normal completion keeps the Docker rm fast path" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-success-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let calls : Array[Array[String]] = []
  let result = run_oracle_with_deadline_using(
    ["run", "--rm", "-i", "immutable-image", "hexdump", "-C"],
    1234,
    root + "/lifecycle",
    invocation => {
      calls.push(invocation.args.copy())
      assert_eq(invocation.timeout_ms, 1234)
      assert_eq(invocation.stdin, b"\x00\xff")
      assert_eq(invocation.args[0:2].to_owned(), ["run", "--name"])
      assert_eq(invocation.args[3], "--label")
      assert_eq(
        invocation.args[4],
        oracle_owner_label + "=" + invocation.args[2],
      )
      assert_eq(invocation.args[5:].to_owned(), [
        "--rm", "-i", "immutable-image", "hexdump", "-C",
      ])
      oracle_container_test_result(stdout=b"exact captured bytes")
    },
    stdin=b"\x00\xff",
  )
  assert_eq(calls.length(), 1)
  assert_eq(result.output.stdout, b"exact captured bytes")
  assert_eq(result.cleanup_error, None)
  assert_false(result.timed_out)
  assert_true(
    @fs.read_file(root + "/lifecycle/lifecycle.json")
    .text()
    .contains("completed-with-rm"),
  )
}

///|
async test "owned oracle timeout removes the verified exact container and retains state" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-timeout-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let evidence = root + "/lifecycle"
  let id = sha256_text("owned container")
  let name = Ref("")
  let token = Ref("")
  let removed = Ref(false)
  let calls : Array[Array[String]] = []
  let result = run_oracle_with_deadline_using(
    ["run", "--rm", "image", "sleep", "60"],
    9,
    evidence,
    invocation => {
      let args = invocation.args
      calls.push(args.copy())
      match args[0] {
        "run" => {
          name.val = args[2]
          token.val = args[4]
            .strip_prefix(oracle_owner_label + "=")
            .unwrap()
            .to_owned()
          oracle_container_test_result(
            status=-9,
            stdout=b"partial",
            timed_out=true,
          )
        }
        "ps" if !args.contains("id=" + id) && !removed.val =>
          oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
        "container" =>
          oracle_container_test_result(
            stdout=oracle_container_test_inspect(name.val, token.val, id),
          )
        "rm" => {
          removed.val = true
          assert_eq(args, ["rm", "--force", id])
          assert_true(
            @fs.read_file(evidence + "/inspect-before-remove.stdout.bin")
            .text()
            .contains("running"),
          )
          oracle_container_test_result()
        }
        "ps" => oracle_container_test_result()
        _ => fail("unexpected Docker command")
      }
    },
  )
  assert_eq(calls.length(), 6)
  assert_true(result.timed_out)
  assert_eq(result.output.status, -9)
  assert_eq(result.output.stdout, b"partial")
  assert_eq(result.cleanup_error, None)
  assert_true(
    @fs.read_file(evidence + "/lifecycle.json")
    .text()
    .contains("abnormal-exit-cleaned"),
  )
}

///|
async test "owned oracle refuses mismatched identity name or ownership labels" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-mismatch-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let id = sha256_text("owned identity")
  for mismatch in ["id", "name", "label"] {
    let evidence = root + "/" + mismatch
    let run_args : Ref[Array[String]] = Ref([])
    let removed = Ref(false)
    let result = run_oracle_with_deadline_using(
      ["run", "--rm", "image", "false"],
      100,
      evidence,
      invocation => {
        let args = invocation.args
        match args[0] {
          "run" => {
            run_args.val = args
            oracle_container_test_result(status=1)
          }
          "ps" => oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
          "container" => {
            let owned_name = run_args.val[2]
            oracle_container_test_result(
              stdout=oracle_container_test_inspect(
                if mismatch == "name" {
                  "unrelated-container"
                } else {
                  owned_name
                },
                if mismatch == "label" {
                  "unrelated-owner"
                } else {
                  owned_name
                },
                if mismatch == "id" {
                  sha256_text("other container")
                } else {
                  id
                },
              ),
            )
          }
          "rm" => {
            removed.val = true
            oracle_container_test_result()
          }
          _ => fail("unexpected Docker command")
        }
      },
    )
    assert_false(removed.val)
    assert_true(result.cleanup_error.unwrap().contains("ownership mismatch"))
    assert_eq(result.output.status, 1)
    assert_true(
      @fs.read_file(evidence + "/lifecycle.json")
      .text()
      .contains("cleanup-failed"),
    )
    clear_oracle_test_reservation(evidence)
  }
}

///|
async test "owned oracle observation removal and absence failures remain infrastructure errors" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-failures-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let id = sha256_text("container under observation")
  for
    fault in [
      "discover", "invalid-id", "ambiguous", "inspect", "malformed", "remove", "absence",
      "inspect-timeout", "remove-timeout", "remove-cleanup", "direct-child",
    ] {
    let evidence = root + "/" + fault
    let name = Ref("")
    let removed = Ref(false)
    let disappeared = Ref(false)
    let result = run_oracle_with_deadline_using(
      ["run", "--rm", "image", "true"],
      100,
      evidence,
      invocation => {
        let args = invocation.args
        match args[0] {
          "run" => {
            name.val = args[2]
            oracle_container_test_result(
              cleanup_error=Some("child wait failed"),
            )
          }
          "ps" if !args.contains("id=" + id) && !removed.val && !disappeared.val =>
            match fault {
              "discover" => oracle_container_test_result(timed_out=true)
              "invalid-id" =>
                oracle_container_test_result(stdout=b"partial-id\n")
              "ambiguous" =>
                oracle_container_test_result(
                  stdout=@utf8.encode(id + "\n" + id + "\n"),
                )
              _ => oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
            }
          "container" =>
            match fault {
              "inspect" => oracle_container_test_result(status=1)
              "inspect-timeout" => {
                disappeared.val = true
                oracle_container_test_result(timed_out=true)
              }
              "malformed" => oracle_container_test_result(stdout=b"not JSON")
              _ =>
                oracle_container_test_result(
                  stdout=oracle_container_test_inspect(name.val, name.val, id),
                )
            }
          "rm" => {
            removed.val = true
            oracle_container_test_result(
              status=if fault == "remove" { 1 } else { 0 },
              timed_out=fault == "remove-timeout",
              cleanup_error=if fault == "remove-cleanup" {
                Some("control wait failed")
              } else {
                None
              },
            )
          }
          "ps" =>
            oracle_container_test_result(
              stdout=if fault == "remove" || fault == "absence" {
                @utf8.encode(id + "\n")
              } else {
                b""
              },
            )
          _ => fail("unexpected Docker command")
        }
      },
    )
    let error = result.cleanup_error.unwrap()
    assert_true(error.contains("child wait failed"))
    assert_eq(
      error.contains("oracle container cleanup failed"),
      fault != "direct-child",
    )
    assert_eq(
      removed.val,
      fault == "remove" ||
      fault == "absence" ||
      fault == "remove-timeout" ||
      fault == "remove-cleanup" ||
      fault == "direct-child",
    )
    if fault != "direct-child" {
      assert_true(
        @fs.read_file(evidence + "/lifecycle.json")
        .text()
        .contains("cleanup-failed"),
      )
    }
    clear_oracle_test_reservation(evidence)
  }
}

///|
async test "owned oracle startup exception preserves failure and cleans its container" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-exception-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let evidence = root + "/lifecycle"
  let id = sha256_text("container created before exception")
  let name = Ref("")
  let removed = Ref(false)
  try
    run_oracle_with_deadline_using(
      ["run", "--rm", "image", "true"],
      100,
      evidence,
      invocation => {
        let args = invocation.args
        match args[0] {
          "run" => {
            name.val = args[2]
            fail("synthetic invocation failure")
          }
          "ps" if !args.contains("id=" + id) && !removed.val =>
            oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
          "container" =>
            oracle_container_test_result(
              stdout=oracle_container_test_inspect(name.val, name.val, id),
            )
          "rm" => {
            removed.val = true
            oracle_container_test_result()
          }
          "ps" => oracle_container_test_result()
          _ => fail("unexpected Docker command")
        }
      },
    )
  catch {
    error =>
      assert_true(error.to_string().contains("synthetic invocation failure"))
  } noraise {
    _ => fail("an exception must not become an oracle result")
  }
  assert_true(removed.val)
  assert_true(
    @fs.read_file(evidence + "/invocation-error.txt")
    .text()
    .contains("synthetic invocation failure"),
  )
  assert_true(
    @fs.read_file(evidence + "/lifecycle.json")
    .text()
    .contains("exception-cleaned"),
  )
}

///|
async test "owned oracle outer cancellation joins protected container cleanup" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-cancel-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let evidence = root + "/lifecycle"
  let id = sha256_text("outer cancellation container")
  let name = Ref("")
  let removed = Ref(false)
  let returned = Ref(false)
  let started : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      // Exercise startup slower than the former 100 ms cancellation trigger.
      @async.sleep(150)
      ignore(
        run_oracle_with_deadline_using(
          ["run", "--rm", "image", "sleep", "60"],
          30000,
          evidence,
          invocation => {
            let args = invocation.args
            match args[0] {
              "run" => {
                name.val = args[2]
                started.put(())
                @async.sleep(5000)
                oracle_container_test_result()
              }
              "ps" if !args.contains("id=" + id) && !removed.val =>
                oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
              "container" =>
                oracle_container_test_result(
                  stdout=oracle_container_test_inspect(name.val, name.val, id),
                )
              "rm" => {
                @async.sleep(5)
                removed.val = true
                oracle_container_test_result()
              }
              "ps" => oracle_container_test_result()
              _ => fail("unexpected Docker command")
            }
          },
        ),
      )
      returned.val = true
    })
    // Acknowledge execution before cancellation; filesystem setup is outside
    // the cancellation trigger and may take longer on a loaded Windows host.
    @async.with_timeout(10000, () => started.get())
    task.cancel()
    try task.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => raise error
    } noraise {
      _ => fail("outer cancellation must interrupt the owned oracle task")
    }
  })
  assert_false(returned.val)
  assert_true(removed.val)
  assert_true(
    @fs.read_file(evidence + "/lifecycle.json")
    .text()
    .contains("outer-cancelled-cleaned"),
  )
}

///|
async test "owned oracle absent containers retain abnormal exit without promotion" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-absent-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let calls = Ref(0)
  let result = run_oracle_with_deadline_using(
    ["run", "--rm", "missing-image", "true"],
    100,
    root + "/lifecycle",
    invocation => {
      calls.val += 1
      oracle_container_test_result(
        status=if invocation.args[0] == "run" { 125 } else { 0 },
      )
    },
  )
  assert_eq(calls.val, 2)
  assert_eq(result.output.status, 125)
  assert_eq(result.cleanup_error, None)
  assert_false(result.timed_out)
}

///|
test "owned oracle Docker options cannot override invocation ownership" {
  for
    args in [
      ["run", "--rm", "--name", "other", "image"],
      ["run", "--rm", "--name=other", "image"],
      ["run", "--rm", "--label", oracle_owner_label + "=other", "image"],
      ["run", "--rm", "-l", oracle_owner_label, "image"],
      ["run", "--rm", "--label=" + oracle_owner_label + "=other", "image"],
      ["run", "image", "--rm"],
    ] {
    try validate_oracle_run_args(args) catch {
      _ => ()
    } noraise {
      _ => fail("invalid Docker ownership prefix must be rejected")
    }
  }
  validate_oracle_run_args([
    "run", "--rm", "-e", "--name", "image", "command", "--name", "operand",
  ])
  validate_oracle_run_args([
    "run", "--rm", "--label", "unrelated=value", "image",
  ])
}

///|
async test "owned oracle interrupted creation without identity remains unresolved" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-pending-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let evidence = root + "/lifecycle"
  let removed = Ref(false)
  let result = run_oracle_with_deadline_using(
    ["run", "--rm", "image", "sleep", "60"],
    10,
    evidence,
    invocation => {
      if invocation.args[0] == "run" {
        oracle_container_test_result(status=-9, timed_out=true)
      } else {
        if invocation.args[0] == "rm" {
          removed.val = true
        }
        // An empty snapshot cannot exclude a daemon create still in flight.
        oracle_container_test_result()
      }
    },
  )
  assert_true(result.timed_out)
  assert_true(
    result.cleanup_error
    .unwrap()
    .contains("delayed daemon-create boundary unresolved"),
  )
  assert_false(removed.val)
  clear_oracle_test_reservation(evidence)
}

///|
async test "owned oracle auto removal races require exact and owner absence" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-race-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let id = sha256_text("auto removed container")
  for race in ["inspect", "remove"] {
    let evidence = root + "/" + race
    let name = Ref("")
    let exists = Ref(true)
    let observed_filters : Array[String] = []
    let result = run_oracle_with_deadline_using(
      ["run", "--rm", "image", "false"],
      10,
      evidence,
      invocation => {
        let args = invocation.args
        match args[0] {
          "run" => {
            name.val = args[2]
            oracle_container_test_result(status=1)
          }
          "ps" => {
            observed_filters.push(args[4])
            oracle_container_test_result(
              stdout=if exists.val { @utf8.encode(id + "\n") } else { b"" },
            )
          }
          "container" =>
            if race == "inspect" {
              exists.val = false
              oracle_container_test_result(status=1)
            } else {
              oracle_container_test_result(
                stdout=oracle_container_test_inspect(name.val, name.val, id),
              )
            }
          "rm" => {
            assert_eq(race, "remove")
            exists.val = false
            oracle_container_test_result(status=1)
          }
          _ => fail("unexpected Docker command")
        }
      },
    )
    assert_eq(result.cleanup_error, None)
    assert_eq(result.output.status, 1)
    assert_true(observed_filters.contains("id=" + id))
    assert_eq(
      observed_filters.filter(value => value.has_prefix("label=")).length(),
      2,
    )
  }
}

///|
async test "owned oracle cleanup continues when lifecycle storage fails" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-sink-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let evidence = root + "/lifecycle"
  let id = sha256_text("container with unavailable evidence sink")
  let name = Ref("")
  let reservation = Ref("")
  let removed = Ref(false)
  defer (if reservation.val != "" {
    @fs.rmdir(reservation.val, recursive=true) catch {
      _ => ()
    }
  })
  let result = run_oracle_with_deadline_using(
    ["run", "--rm", "image", "false"],
    10,
    evidence,
    invocation => {
      let args = invocation.args
      match args[0] {
        "run" => {
          name.val = args[2]
          match
            @json.parse(@fs.read_file(evidence + "/lifecycle.json").text()) {
            { "reservation": String(path), .. } => reservation.val = path
            _ => fail("missing reservation evidence")
          }
          @fs.rmdir(evidence, recursive=true)
          @fs.write_file(evidence, "blocked lifecycle directory")
          oracle_container_test_result(status=1, stdout=b"retained prefix")
        }
        "ps" if !removed.val =>
          oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
        "container" =>
          oracle_container_test_result(
            stdout=oracle_container_test_inspect(name.val, name.val, id),
          )
        "rm" => {
          removed.val = true
          oracle_container_test_result()
        }
        "ps" => oracle_container_test_result()
        _ => fail("unexpected Docker command")
      }
    },
  )
  assert_true(result.cleanup_error.unwrap().contains("lifecycle"))
  assert_eq(result.output.status, 1)
  assert_eq(result.output.stdout, b"retained prefix")
  assert_true(removed.val)
  assert_true(@fs.exists(reservation.val))
}

///|
async test "owned oracle concurrent cleanup isolates invocation identities" {
  let root = @fs.tmpdir(prefix="mooncmd-owned-concurrent-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let names : Array[String] = []
  let removed_ids : Array[String] = []
  @async.with_task_group(group => {
    let tasks = Array::makei(2, index => {
      group.spawn(() => {
        let name = Ref("")
        let removed = Ref(false)
        let id = sha256_text("concurrent container " + index.to_string())
        let result = run_oracle_with_deadline_using(
          ["run", "--rm", "image", "sleep", "60"],
          10,
          root + "/" + index.to_string(),
          invocation => {
            let args = invocation.args
            match args[0] {
              "run" => {
                name.val = args[2]
                names.push(name.val)
                @async.sleep(10)
                oracle_container_test_result(status=-9, timed_out=true)
              }
              "ps" if !removed.val =>
                oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
              "container" =>
                oracle_container_test_result(
                  stdout=oracle_container_test_inspect(name.val, name.val, id),
                )
              "rm" => {
                assert_eq(args, ["rm", "--force", id])
                @async.sleep(5)
                removed_ids.push(id)
                removed.val = true
                oracle_container_test_result()
              }
              "ps" => oracle_container_test_result()
              _ => fail("unexpected Docker command")
            }
          },
        )
        assert_eq(result.cleanup_error, None)
        assert_true(result.timed_out)
      })
    })
    for task in tasks {
      task.wait()
    }
  })
  assert_eq(names.length(), 2)
  assert_true(names[0] != names[1])
  assert_eq(removed_ids.length(), 2)
  assert_true(removed_ids[0] != removed_ids[1])
}
