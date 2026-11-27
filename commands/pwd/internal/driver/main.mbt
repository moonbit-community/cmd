///|
fn valid_logical_path(path : String) -> Bool {
  if !path.has_prefix("/") {
    return false
  }
  for part in path.split("/") {
    if part == "." || part == ".." {
      return false
    }
  }
  true
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("pwd \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("pwd: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(metadata_help())
    return
  }
  if !parsed.operands.is_empty() {
    @stdio.stderr.write("pwd: ignoring non-option arguments\n")
  }
  let logical = match parsed.last_occurrence(["logical", "physical"]) {
    Some("logical") => true
    Some("physical") => false
    _ => @env.get_env_var("POSIXLY_CORRECT") is Some(_)
  }
  guard @env.current_dir() is Some(current) else {
    @stdio.stderr.write("pwd: cannot determine current directory\n")
    @env.exit(1)
    return
  }
  let selected = if logical {
    match @env.get_env_var("PWD") {
      Some(path) if valid_logical_path(path) => {
        let resolved = @fs.realpath(path) catch { _ => "" }
        let physical = @fs.realpath(current) catch { _ => current }
        if resolved != "" && resolved == physical {
          path
        } else {
          current
        }
      }
      _ => current
    }
  } else {
    @fs.realpath(current) catch {
      err => {
        @stdio.stderr.write("pwd: \{err}\n")
        @env.exit(1)
        return
      }
    }
  }
  @stdio.stdout.write(selected + "\n")
}
