///|
async fn run_find_child(argv : Array[String]) -> Int32 {
  guard argv.get(0) is Some(program) else { abort("empty find child argv") }
  let spec = @process.child(program, argv[1:].to_owned())
  @async.with_task_group() <| group => {
    let child = @child_process.spawn(
      group,
      spec.program,
      spec.args,
      extra_env=spec.context.env,
      inherit_env=false,
      cwd=spec.context.cwd,
      no_console_window=true,
      cancel_handler=@child_process.hard_cancel(),
    ) catch {
      @os_error.OSError(_) as error => {
        @stdio.stderr.write("find: '\{program}': \{find_os_message(error)}\n")
        return 1
      }
      error => raise error
    }
    child.wait()
  }
}

///|
async fn FindAction::execute(
  self : FindAction,
  entry : FindEntry,
  context : FindEvaluation,
) -> Bool {
  match self {
    Print(zero) => {
      @stdio.stdout.write(entry.path + (if zero { "\u0000" } else { "\n" }))
      true
    }
    Exec(command, grouped) =>
      if grouped {
        if !context.batch.unwrap().push(entry.path) {
          entry.failed = true
        }
        true
      } else {
        let argv = command.map(argument => {
          if argument == "{}" {
            entry.path
          } else {
            argument
          }
        })
        let code = run_find_child(argv)
        if code < 0 {
          @stdio.stderr.write(
            "find: '\{command[0]}' terminated by signal \{-code}\n",
          )
        }
        code == 0
      }
    Delete => {
      // GNU protects the literal starting point ".". Other dot spellings are
      // passed to the filesystem and retain their actual deletion errors.
      if entry.path == "." {
        return true
      }
      try {
        if entry.kind == Directory {
          @fs.rmdir(entry.path)
          if entry.directory is Some(directory) {
            directory.state = Unread
          }
        } else {
          @fs.remove(entry.path)
        }
        true
      } catch {
        @os_error.OSError(_) as error => {
          entry.metadata_error(error, "deletion")
          false
        }
        error => raise error
      }
    }
  }
}
