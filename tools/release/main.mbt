///|
async fn main {
  run() catch {
    error => {
      @stdio.stderr.write("release acceptance: " + error.to_string() + "\n")
      @sys.exit(1)
    }
  }
}

///|
async fn run() -> Unit {
  let args = @env.args()[1:]
  if args is ["--generate-candidate", "--output", output] {
    guard !@fs.exists(output) else { fail("choose a fresh candidate output") }
    generate_candidate(output)
    return
  }
  let mut manifest = "tests/release/latest.json"
  let mut suite = "functional"
  let forwarded : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let flag = args[index]
    guard args.get(index + 1) is Some(value) else {
      fail("missing value for " + flag)
    }
    match flag {
      "--manifest" => manifest = value
      "--suite" => suite = value
      "--moonx"
      | "--oracle-image"
      | "--oracle-profile"
      | "--report-dir"
      | "--command"
      | "--case" => forwarded.append([flag, value])
      "--jobs" => {
        guard value == "1" else {
          fail("published acceptance is serial; use --jobs 1")
        }
      }
      _ => fail("unknown option: " + flag)
    }
    index += 2
  }
  guard ["functional", "oracle", "all", "validate"].contains(suite) else {
    fail("unknown suite: " + suite)
  }
  let profile = @env.get_env_var("CMD_TEST_PROFILE").unwrap_or("release")
  guard ["debug", "release"].contains(profile) else {
    fail("unknown test-tool profile")
  }
  let driver = @fs.realpath(
    "_build/native/" +
    profile +
    "/build/mooxCLI/cmd-tests/harness/driver/driver.exe",
  )
  let arguments = [
    "--published-manifest",
    @fs.realpath(manifest),
    "--jobs",
    "1",
    ..forwarded,
  ]
  if suite == "validate" {
    arguments.append(["--suite", "functional", "--validate-only"])
  } else {
    arguments.append(["--suite", suite])
  }
  // Fixture HOME belongs to the command under test, not MoonX's registry cache.
  let moon_home = @fs.realpath(
    published_moon_home(
      {
        "MOON_HOME": @env.get_env_var("MOON_HOME").unwrap_or(""),
        "HOME": @env.get_env_var("HOME").unwrap_or(""),
        "USERPROFILE": @env.get_env_var("USERPROFILE").unwrap_or(""),
      },
      windows=@async.platform is Windows,
    ),
  )
  @shell.Cmd(
    driver,
    arguments,
    env={ "MOON_HOME": moon_home },
    stdout=Inherit,
    stderr=Inherit,
  ).run()
}
