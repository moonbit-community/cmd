///|
async fn tty_pty(work : String, root : String) -> Unit {
  let run = async fn(argv : Array[String]) {
    @harness.run(
      "/usr/bin/script",
      ["-qefc", argv.map(shell_quote).join(" "), "/dev/null"],
      stdin=b"",
      cwd=work,
    )
  }
  let reference = run(["/usr/bin/tty"])
  assert_eq(reference.status, 0)
  assert_eq(reference.stderr, b"")
  let terminal = @utf8.decode(reference.stdout).trim()
  guard terminal.strip_prefix("/dev/pts/") is Some(id) &&
    !id.is_empty() &&
    id.iter().all(ch => ch.is_ascii_digit()) else {
    fail("reference did not receive a Linux PTY")
  }
  let candidate = run(@harness.command_line(root, "tty", []))
  assert_eq(candidate.status, 2)
  assert_eq(candidate.stderr, b"")
  assert_eq(
    @harness.normalize_lf(@utf8.decode(candidate.stdout)),
    "tty: terminal device identity is unavailable\n",
  )
}
