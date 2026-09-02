///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("no-create", short='c'),
    @cli.flag("access-time", short='a'),
    @cli.flag("modification-time", short='m'),
    @cli.option("date", short='d'),
    @cli.option("reference", short='r'),
    @cli.option("stamp", short='t'),
    @cli.option("time"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("touch: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: touch [-c] [-a|-m] [-d STRING|-r FILE|-t STAMP] FILE...\nNote: -a/-m/-d/-r/-t are recognized but unavailable without a portable timestamp setter.\n",
    )
    return
  }
  let files = parsed.operands
  let no_create = parsed.contains("no-create")
  if files.is_empty() {
    @stdio.stderr.write("touch: missing file operand\n")
    @sys.exit(1)
    return
  }
  if parsed.contains("access-time") ||
    parsed.contains("modification-time") ||
    parsed.contains("date") ||
    parsed.contains("reference") ||
    parsed.contains("stamp") ||
    parsed.contains("time") {
    @stdio.stderr.write(
      "touch: selecting or setting timestamps is unavailable in the portable filesystem API\n",
    )
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
