///|
async fn main {
  let args = @env.args()[1:]
  let files : Array[String] = []
  let mut no_create = false
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-c" || arg == "--no-create") {
      no_create = true
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: touch [-c] FILE...\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("touch: unsupported option: '\{arg}'\n")
      @sys.exit(1)
      return
    } else {
      files.push(arg)
    }
  }
  if files.is_empty() {
    @stdio.stderr.write("touch: missing file operand\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for path in files {
    let exists = @fsops.kind_if_exists(path) catch {
      err => {
        @stdio.stderr.write("touch: cannot inspect '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    if exists is None && !no_create {
      let file = @fs.open(path, mode=WriteOnly, create_mode=OpenOrCreate) catch {
        err => {
          @stdio.stderr.write("touch: cannot create '\{path}': \{err}\n")
          failed = true
          continue
        }
      }
      file.close()
    }
  }
  if failed {
    @sys.exit(1)
  }
}
