///|
async fn make_fifo_scenario(
  root : String,
  work : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  let helper = shell_quote(@fs.realpath(@env.args()[0]))
  for recursive in [false, true] {
    let name = if recursive { "recursive" } else { "direct" }
    let directory = work + "/" + name
    @fs.mkdir(directory)
    let fifo = directory + "/token=value with space"
    // Host mkfifo only creates the observation fixture; the product opens and
    // manages inherited tokens through released public MoonBit APIs.
    let setup = @harness.run_with_deadline(
      "/usr/bin/mkfifo",
      [fifo],
      5000,
      stdin=b"",
    )
    assert_false(setup.timed_out)
    assert_eq(setup.cleanup_error, None)
    assert_eq(setup.output.status, 0)
    assert_eq(setup.output.stderr, b"")
    let keeper = @fs.open(fifo, mode=ReadWrite, create_mode=OpenExisting)
    defer keeper.close()
    keeper.write(b"Q")
    let command = helper + " --test-helper ready " + shell_quote(directory)
    let names = if recursive {
      ["left-a", "left-b", "right-a", "right-b"]
    } else {
      ["a", "b", "c"]
    }
    if recursive {
      @fs.write_file(
        directory + "/Makefile",
        ".PHONY: all left right\nall: left right\nleft right:\n\t@$(MAKE) -f Child.mk PREFIX=$@\n",
      )
      @fs.write_file(
        directory + "/Child.mk",
        ".PHONY: all a b\nall: a b\na b:\n\t@" + command + " '$(PREFIX)-$@'\n",
      )
    } else {
      @fs.write_file(
        directory + "/Makefile",
        ".PHONY: all a b c\nall: a b c\na b c:\n\t@" + command + " '$@'\n",
      )
    }
    let states : Array[Json] = []
    let result = @async.with_task_group(group => {
      let child = group.spawn(() => {
        scenario_run(directory, root, "make", ["all"], cwd=directory, extra_env={
          "MAKEFLAGS": "--jobs 3 --jobserver-auth fifo:" +
          fifo.replace_all(old=" ", new="\\ "),
          "MAKELEVEL": "0",
        })
      })
      let acknowledged : Set[String] = Set([])
      let mut peak = 0
      while acknowledged.length() < names.length() {
        let required = if acknowledged.is_empty() { 2 } else { 1 }
        let mut ready : Array[String] = []
        while ready.length() < required {
          ready = []
          for name in names {
            if !acknowledged.contains(name) &&
              @fs.exists(directory + "/" + name + ".ready") {
              ready.push(name)
            }
          }
          if ready.length() < required {
            @async.sleep(5)
          }
        }
        let mut active = 0
        for name in names {
          if @fs.exists(directory + "/" + name + ".ready") &&
            !@fs.exists(directory + "/" + name + ".done") {
            active += 1
          }
        }
        assert_true(active <= 2)
        peak = peak.max(active)
        if acknowledged.is_empty() {
          let start = @async.now()
          while @async.now() - start < 250L {
            let mut held = 0
            for candidate in names {
              if @fs.exists(directory + "/" + candidate + ".ready") {
                held += 1
              }
            }
            assert_eq(held, 2)
            @async.sleep(5)
          }
          states.push({
            "held_observation_ms": @async.now() - start,
            "ready_count": 2,
          })
        }
        states.push({
          "ready": ready,
          "observed_active": active,
          "acknowledged": acknowledged.length(),
        })
        let selected = ready[0]
        @fs.write_file(directory + "/" + selected + ".ack", "ack")
        acknowledged.add(selected)
        while !@fs.exists(directory + "/" + selected + ".done") {
          @async.sleep(5)
        }
      }
      assert_eq(peak, 2)
      child.wait()
    })
    assert_eq(result.status, 0)
    assert_eq(result.stdout, b"")
    assert_eq(result.stderr, b"")
    let byte = FixedArray::make(1, b'\x00')
    assert_eq(@async.with_timeout(1000, () => keeper.read(byte, max_len=1)), 1)
    assert_eq(byte[0], b'Q')
    let extra = @async.with_timeout_opt(50, () => keeper.read(byte, max_len=1))
    assert_eq(extra, None)
    assert_eq(@fs.kind(fifo), Pipe)
    let done : Array[Bool] = []
    for name in names {
      done.push(@fs.exists(directory + "/" + name + ".done"))
    }
    assert_true(done.all(value => value))
    @fs.write_file(
      directory + "/observations.json",
      ({ "states": states, "token_hex": "51", "done": done } : Json).stringify(
        indent=2,
      ),
    )
    if proof is Some(proof) {
      proof.observe_equal(
        "make/fifo-" + name,
        "make",
        {
          "status": result.status,
          "stdout": @harness.scenario_text(result.stdout),
          "stderr": @harness.scenario_text(result.stderr),
          "done": done,
          "token": byte[0].to_int(),
          "extra_token": extra is Some(_),
          "fifo_retained": @fs.kind(fifo) == Pipe,
        },
        {
          "status": 0,
          "stdout": "",
          "stderr": "",
          "done": names.map(_ => true),
          "token": 81,
          "extra_token": false,
          "fifo_retained": true,
        },
      )
    }
  }
}

///|
async fn jobserver_bridge(work : String) -> Unit {
  @fs.write_file(
    work + "/bridge.flags",
    @env.get_env_var("MAKEFLAGS").unwrap_or(""),
  )
  @fs.write_file(work + "/bridge.ready", "ready")
  while !@fs.exists(work + "/bridge.ack") {
    @async.sleep(5)
  }
  let status = @string.parse_int(
    @fs.read_file(work + "/bridge.ack").text(),
    base=10,
  )
  @sys.exit(status)
}

///|
async fn make_gnu_jobserver_scenario(
  root : String,
  work : String,
  image : String,
) -> Unit {
  let helper = @harness.option_child_path()
  let command = shell_quote(helper) +
    " --test-helper ready " +
    shell_quote(work)
  @fs.write_file(
    work + "/Host.mk",
    "SHELL := /oracle/bin/sh\n.PHONY: all outer inner\nall: outer inner\nouter:\n\t@" +
    command +
    " outer\ninner:\n\t+@" +
    shell_quote(helper) +
    " --test-helper jobserver-bridge " +
    shell_quote(work) +
    "\n",
  )
  @fs.write_file(
    work + "/Product.mk",
    ".PHONY: all a b\nall: a b\na b:\n\t@" + command + " '$@'\n",
  )
  let events : Array[Json] = []
  @async.with_task_group(group => {
    // A GNU child exports its actual FIFO authentication across the shared
    // filesystem. The Wasm client runs on the host so published MoonX uses its
    // normal exact-coordinate launcher without mounting account credentials.
    let server = group.spawn(() => {
      @harness.run_oracle_with_deadline(
        "docker",
        [
          "run",
          "--rm",
          "-i",
          "--user",
          @harness.docker_user(),
          "-v",
          work + ":" + work + ":rw",
          "-v",
          helper + ":" + helper + ":ro",
          "-w",
          work,
          "-e",
          "TMPDIR=" + work,
          image,
          "/oracle/bin/make",
          "--no-print-directory",
          "--jobserver-style=fifo",
          "-j2",
          "-f",
          "Host.mk",
        ],
        30000,
        evidence_dir=work + "-lifecycle",
        stdin=b"",
      )
    })
    while !@fs.exists(work + "/bridge.ready") {
      @async.sleep(5)
    }
    let flags = @fs.read_file(work + "/bridge.flags").text()
    assert_true(flags.contains("--jobserver-auth=fifo:"))
    let client = group.spawn(() => {
      scenario_run(work, root, "make", ["-f", "Product.mk"], cwd=work, extra_env={
        "MAKEFLAGS": flags,
        "MAKELEVEL": "1",
      })
    })
    while !@fs.exists(work + "/outer.ready") ||
          (!@fs.exists(work + "/a.ready") && !@fs.exists(work + "/b.ready")) {
      @async.sleep(5)
    }
    let first = if @fs.exists(work + "/a.ready") { "a" } else { "b" }
    let second = if first == "a" { "b" } else { "a" }
    assert_false(@fs.exists(work + "/" + first + ".done"))
    assert_false(@fs.exists(work + "/" + second + ".ready"))
    let start = @async.now()
    while @async.now() - start < 250L {
      assert_false(@fs.exists(work + "/" + second + ".ready"))
      assert_false(@fs.exists(work + "/outer.done"))
      assert_false(@fs.exists(work + "/" + first + ".done"))
      @async.sleep(5)
    }
    events.push({
      "held_observation_ms": @async.now() - start,
      "second_ready": false,
    })
    events.push({
      "outer_ready": true,
      "first": first,
      "second": second,
      "second_ready": false,
    })
    @fs.write_file(work + "/outer.ack", "ack")
    while !@fs.exists(work + "/" + second + ".ready") {
      @async.sleep(5)
    }
    assert_true(@fs.exists(work + "/outer.done"))
    assert_false(@fs.exists(work + "/" + first + ".done"))
    events.push({
      "outer_done": true,
      "first_done": false,
      "second_ready": true,
    })
    @fs.write_file(work + "/a.ack", "ack")
    @fs.write_file(work + "/b.ack", "ack")
    let product = client.wait()
    @fs.write_file(work + "/bridge.ack", product.status.to_string())
    let oracle = server.wait()
    @fs.write_file(work + "/server.stdout.bin", oracle.output.stdout)
    @fs.write_file(work + "/server.stderr.bin", oracle.output.stderr)
    @fs.write_file(work + "/events.json", Json(events).stringify(indent=2))
    assert_eq(product.status, 0)
    assert_eq(product.stdout, b"")
    assert_eq(product.stderr, b"")
    assert_false(oracle.timed_out)
    assert_eq(oracle.cleanup_error, None)
    assert_eq(oracle.output.status, 0)
    assert_eq(oracle.output.stdout, b"")
    assert_eq(oracle.output.stderr, b"")
  })
}
