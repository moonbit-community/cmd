///|
async fn typst_artifacts_scenario(
  root : String,
  work : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  let source = @fs.read_file(
    @harness.repository_path("tests/fixtures/typst/rectangle.typ"),
  ).text()
  let svg = @fs.read_file(
      @harness.repository_path("tests/fixtures/typst/rectangle.svg"),
    )
    .text()
    .trim()
    .to_owned()
  @fs.write_file(work + "/main.typ", source)
  let base = ["compile", "--ignore-system-fonts", "--creation-timestamp=0"]
  let result = scenario_run(
    work,
    root,
    "typst",
    [..base, "--deps=deps.json", "--deps-format=json", "main.typ", "out.pdf"],
    cwd=work,
  )
  assert_eq(result.status, 0)
  assert_eq(result.stdout, b"")
  assert_eq(result.stderr, b"")
  let pdf = @fs.read_file(work + "/out.pdf").binary()
  assert_true(pdf.length() > 200)
  assert_eq(pdf[:5].to_owned(), b"%PDF-")
  let streamed = scenario_run(
    work,
    root,
    "typst",
    [..base, "main.typ", "-"],
    cwd=work,
  )
  assert_eq(streamed.status, 0)
  assert_eq(streamed.stderr, b"")
  assert_eq(streamed.stdout, pdf)
  let deps = @json.parse(@fs.read_file(work + "/deps.json").text())
  assert_eq(deps, ({ "inputs": ["main.typ"], "outputs": ["out.pdf"] } : Json))
  for (ppi, width, height) in [(72, 20, 10), (144, 40, 20)] {
    let image = scenario_run(
      work,
      root,
      "typst",
      [..base, "--format=png", "--ppi=" + ppi.to_string(), "main.typ", "-"],
      cwd=work,
    )
    assert_eq(image.status, 0)
    assert_eq(image.stderr, b"")
    assert_eq(image.stdout[:8].to_owned(), b"\x89PNG\r\n\x1a\n")
    assert_eq(image.stdout[12:16].to_owned(), b"IHDR")
    assert_eq(
      image.stdout[16:20].to_owned(),
      Bytes::from_array([0, 0, 0, width.to_byte()]),
    )
    assert_eq(
      image.stdout[20:24].to_owned(),
      Bytes::from_array([0, 0, 0, height.to_byte()]),
    )
  }
  @fs.write_file(
    work + "/two.typ",
    source +
    "\n#pagebreak()\n#rect(width:20pt,height:10pt,fill:black,stroke:none)\n",
  )
  let selected = scenario_run(
    work,
    root,
    "typst",
    [..base, "--pages=2", "two.typ", "page-{p}.svg"],
    cwd=work,
  )
  assert_eq(selected.status, 0)
  assert_eq(selected.stderr, b"")
  assert_eq(selected.stdout, b"")
  assert_false(@fs.exists(work + "/page-1.svg"))
  assert_eq(@fs.read_file(work + "/page-2.svg").text(), svg)
  assert_eq(@fs.read_file(work + "/main.typ").text(), source)
  let failure_status = @async.with_task_group(group => {
    let (consumer, stdout) = @process.read_from_process()
    consumer.close()
    let child = @process.spawn(
      group,
      @harness.command_program(),
      @harness.command_args(root, "typst", [
        "eval", "--ignore-system-fonts", "--format=raw", "bytes((0, 255, 65, 10))",
      ]),
      cwd=work,
      stdout~,
      stderr=@process.redirect_to_file(work + "/failed-output.stderr"),
      cancel_handler=@process.hard_cancel(),
    )
    @async.with_timeout(10000, () => child.wait())
  })
  assert_eq(failure_status, 1)
  let failure_diagnostic = @fs.read_file(work + "/failed-output.stderr").text()
  assert_true(failure_diagnostic.contains("failed to write eval output"))
  if proof is Some(proof) {
    proof.observe_equal(
      "typst/exports",
      "typst",
      {
        "pdf_stream_equals_file": streamed.stdout == pdf,
        "deps": deps,
        "ppi_dimensions": true,
        "selected_page": 2,
        "svg": @fs.read_file(work + "/page-2.svg").text(),
        "source_retained": true,
      },
      {
        "pdf_stream_equals_file": true,
        "deps": { "inputs": ["main.typ"], "outputs": ["out.pdf"] },
        "ppi_dimensions": true,
        "selected_page": 2,
        "svg": svg,
        "source_retained": true,
      },
    )
    proof.observe_equal(
      "typst/output-failure",
      "typst",
      {
        "status": failure_status,
        "diagnostic": failure_diagnostic.contains("failed to write eval output"),
        "child_reaped": true,
      },
      { "status": 1, "diagnostic": true, "child_reaped": true },
    )
  }
}

///|
async fn typst_watch_scenario(
  root : String,
  work : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  let source = @fs.read_file(
    @harness.repository_path("tests/fixtures/typst/rectangle.typ"),
  ).text()
  let svg = @fs.read_file(
      @harness.repository_path("tests/fixtures/typst/rectangle.svg"),
    )
    .text()
    .trim()
    .to_owned()
  @fs.write_file(work + "/main.typ", source)
  let output = work + "/watched.svg"
  let changed = svg.replace_all(old="#000000", new="#ff0000")
  let (reader_out, child_stdout) = @process.read_from_process()
  let (reader_err, child_stderr) = @process.read_from_process()
  defer reader_out.close()
  defer reader_err.close()
  @async.with_task_group(group => {
    let out_task = group.spawn(() => reader_out.read_all().binary())
    let err_task = group.spawn(() => reader_err.read_all().binary())
    let child = @process.spawn(
      group,
      @harness.command_program(),
      @harness.command_args(root, "typst", [
        "watch", "--ignore-system-fonts", "--no-fullscreen", "main.typ", "watched.svg",
      ]),
      cwd=work,
      stdout=child_stdout,
      stderr=child_stderr,
      // On Windows, CTRL_BREAK reaches the MoonX console group, including
      // its Moonrun child. TerminateProcess on MoonX alone leaves it alive.
      cancel_handler=@process.graceful_cancel(timeout=1000),
    )
    @async.with_timeout(10000, () => {
      while !@fs.exists(output) || @fs.read_file(output).text() != svg {
        @async.sleep(20)
      }
    })
    // Repeated writes avoid assuming an OS watcher registration timing window.
    // Success still requires the exact new document after the initial render.
    @async.with_timeout(10000, () => {
      while @fs.read_file(output).text() != changed {
        @fs.write_file(
          work + "/main.typ",
          source.replace_all(old="fill: black", new="fill: rgb(\"#ff0000\")"),
        )
        @async.sleep(200)
      }
    })
    child.cancel()
    @async.with_timeout(5000, () => {
      child.wait() |> ignore
      @fs.write_file(work + "/stdout", out_task.wait())
      @fs.write_file(work + "/stderr", err_task.wait())
    })
    if @async.platform is Windows {
      // Pipe EOF and the wrapper's exit are insufficient to prove that the
      // descendant has released its working directory. Require that release.
      let moved = work + ".released"
      let last_error = Ref("")
      let released = @async.with_timeout_opt(5000, () => {
        for ;; {
          let renamed = try @fs.rename(work, moved) catch {
            error => {
              last_error.val = error.to_string()
              false
            }
          } noraise {
            _ => true
          }
          if renamed {
            @fs.rename(moved, work)
            break
          }
          @async.sleep(10)
        }
      })
      guard released is Some(_) else {
        fail("watch child retained its working directory: " + last_error.val)
      }
    }
    assert_eq(@fs.read_file(output).text(), changed)
    assert_eq(@fs.read_file(work + "/stdout").binary(), b"")
    if proof is Some(proof) {
      proof.observe_equal(
        "typst/watch",
        "typst",
        {
          "initial": svg,
          "updated": @fs.read_file(output).text(),
          "child_reaped": true,
        },
        { "initial": svg, "updated": changed, "child_reaped": true },
      )
    }
  })
}
