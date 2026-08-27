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
    match exists {
      None if no_create => ()
      None => {
        let file = @fs.open(path, mode=WriteOnly, create_mode=OpenOrCreate) catch {
          err => {
            @stdio.stderr.write("touch: cannot create '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
        file.close()
      }
      Some(Regular) => {
        let file = @fs.open(path, mode=ReadWrite) catch {
          err => {
            @stdio.stderr.write("touch: cannot open '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
        let update = try {
          let size = file.size()
          if size == 0L {
            @fs.write_file(path, "", create_mode=CreateOrTruncate)
          } else {
            let final_byte = file.read_exactly_at(1, position=size - 1L)
            file.write_at(final_byte[:], position=size - 1L)
          }
        } catch {
          err => Some(err)
        } noraise {
          _ => None
        }
        file.close()
        if update is Some(err) {
          @stdio.stderr.write("touch: cannot update '\{path}': \{err}\n")
          failed = true
        }
      }
      Some(SymLink) => {
        @stdio.stderr.write("touch: refusing symbolic link '\{path}'\n")
        failed = true
      }
      Some(_) => {
        @stdio.stderr.write("touch: cannot update non-regular file '\{path}'\n")
        failed = true
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
