///|
priv struct RmOptions {
  mut recursive : Bool
  mut force : Bool
  mut empty_directories : Bool
  mut verbose : Bool
}

///|
fn apply_short_options(options : RmOptions, arg : String) -> Bool {
  for flag in arg[1:] {
    match flag {
      'r' | 'R' => options.recursive = true
      'f' => options.force = true
      'd' => options.empty_directories = true
      'v' => options.verbose = true
      _ => return false
    }
  }
  true
}

///|
async fn main {
  let args = @env.args()[1:]
  let options : RmOptions = {
    recursive: false,
    force: false,
    empty_directories: false,
    verbose: false,
  }
  let paths : Array[String] = []
  let mut parsing_options = true
  for arg in args {
    if parsing_options && arg == "--" {
      parsing_options = false
    } else if parsing_options && arg == "--recursive" {
      options.recursive = true
    } else if parsing_options && arg == "--force" {
      options.force = true
    } else if parsing_options && arg == "--dir" {
      options.empty_directories = true
    } else if parsing_options && arg == "--verbose" {
      options.verbose = true
    } else if parsing_options && arg == "--preserve-root" {
      ()
    } else if parsing_options && arg == "--no-preserve-root" {
      @stdio.stderr.write(
        "rm: --no-preserve-root is disabled by repository policy\n",
      )
      @sys.exit(1)
      return
    } else if parsing_options && arg == "--help" {
      @stdio.stdout.write("Usage: rm [-f] [-r|-R] [-d] [-v] FILE...\n")
      return
    } else if parsing_options && arg.has_prefix("-") && arg != "-" {
      if !apply_short_options(options, arg) {
        @stdio.stderr.write("rm: invalid option: '\{arg}'\n")
        @sys.exit(1)
        return
      }
    } else {
      paths.push(arg)
    }
  }
  if paths.is_empty() {
    if options.force {
      return
    }
    @stdio.stderr.write("rm: missing operand\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for path in paths {
    if @fsops.protects_working_directory(path) {
      @stdio.stderr.write("rm: refusing to remove protected path '\{path}'\n")
      failed = true
      continue
    }
    let kind = @fsops.kind_if_exists(path) catch {
      err => {
        @stdio.stderr.write("rm: cannot inspect '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    match kind {
      None if options.force => continue
      None => {
        @stdio.stderr.write("rm: cannot remove '\{path}': no such file\n")
        failed = true
        continue
      }
      Some(Directory) if options.recursive =>
        @fsops.remove_path(path, true) catch {
          @fsops.FsOpError(message) => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{message}\n")
            failed = true
            continue
          }
          err => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
      Some(Directory) if options.empty_directories =>
        @fs.rmdir(path) catch {
          err => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
      Some(Directory) => {
        @stdio.stderr.write("rm: cannot remove '\{path}': is a directory\n")
        failed = true
        continue
      }
      Some(_) =>
        @fsops.remove_path(path, false) catch {
          @fsops.FsOpError(message) => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{message}\n")
            failed = true
            continue
          }
          err => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
    }
    if options.verbose {
      @stdio.stdout.write("removed '\{path}'\n")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
