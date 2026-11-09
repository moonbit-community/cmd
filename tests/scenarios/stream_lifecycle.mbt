///|
async fn yes_stream_lifecycle_scenario(
  root : String,
  work : String,
  oracle_image? : String,
) -> Unit {
  for
    (name, args, expected) in [
      ("default", [], "y\ny\n"),
      (
        "operands",
        ["hello", "two words", ""],
        "hello two words \nhello two words \n",
      ),
    ] {
    @async.with_task_group(group => {
      let (reader, stdout) = @process.read_from_process()
      defer reader.close()
      let (diagnostic, stderr) = @process.read_from_process()
      defer diagnostic.close()
      let child = @harness.spawn(
        group,
        @harness.command_program(),
        @harness.command_args(root, "yes", args),
        cwd=work,
        stdout~,
        stderr~,
        cancel_handler=@process.hard_cancel(),
      )
      let prefix = StringBuilder()
      for _ in 0..<2 {
        guard reader.read_until("\n") is Some(line) else {
          fail("yes ended before two complete records")
        }
        prefix.write_string(line)
        prefix.write_char('\n')
      }
      assert_eq(prefix.to_string(), expected)
      // Closing the consumer must terminate the producer without cancellation.
      reader.close()
      let status = @async.with_timeout(5000, () => child.wait())
      let errors = diagnostic.read_all().binary()
      @fs.write_file(work + "/../yes-" + name + ".prefix", prefix.to_string())
      @fs.write_file(work + "/../yes-" + name + ".stderr", errors)
      assert_eq(status, 0)
      assert_eq(errors, b"")

      @harness.assert_observation(
        "yes/" + name,
        "yes",
        {
          "prefix": prefix.to_string(),
          "status": status,
          "stderr": @harness.scenario_text(errors),
        },
        { "prefix": expected, "status": 0, "stderr": "" },
      )
    })
    if oracle_image is Some(image) {
      let compared = @harness.run_oracle_with_deadline(
        "docker",
        [
          "run", "--rm", "-i", "--network", "none", image, "/bin/sh", "-c", "yes \"$@\" | head -n 2",
          "--", ..args,
        ],
        15000,
        evidence_dir=work + "/yes-" + name + "-oracle",
      )
      assert_false(compared.timed_out)
      assert_eq(compared.cleanup_error, None)
      assert_eq(compared.output.status, 0)
      assert_eq(compared.output.stdout, @utf8.encode(expected))
      assert_eq(compared.output.stderr, b"")
    }
  }
}
