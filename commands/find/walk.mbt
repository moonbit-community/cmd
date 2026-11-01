///|
priv enum DirectoryState {
  Unread
  Failed
  Read(Array[String])
}

///|
priv struct DirectoryVisit {
  path : String
  read : async (String) -> Array[String]
  mut state : DirectoryState
}

///|
async fn DirectoryVisit::names(self : DirectoryVisit) -> Array[String]? {
  match self.state {
    Read(names) => return Some(names)
    Failed => return None
    Unread => ()
  }
  try {
    let names = (self.read)(self.path)
    self.state = Read(names)
    Some(names)
  } catch {
    error => {
      self.state = Failed
      @stdio.stderr.write("find: '\{self.path}': \{error}\n")
      None
    }
  }
}

///|
fn push_children(
  stack : Array[(String, Int32, Bool)],
  path : String,
  depth : Int32,
  entries : Array[String],
) -> Unit {
  entries.sort_by((left, right) => left.lexical_compare(right))
  for index = entries.length(); index > 0; index = index - 1 {
    stack.push((join_path(path, entries[index - 1]), depth + 1, false))
  }
}

///|
async fn walk_find(
  paths : Array[String],
  parser : FindParser,
  expression : FindExpr,
  context : FindContext,
  read_directory~ : async (String) -> Array[String] = path => {
    @fswalk.read_directory(path)
  },
) -> Bool {
  let needs = expression.metadata_needs()
  let stack : Array[(String, Int32, Bool)] = []
  let mut path_index = paths.length()
  while path_index > 0 {
    path_index -= 1
    stack.push((paths[path_index], 0, false))
  }
  let mut failed = false
  let batch = match parser.action {
    Some(Exec(command, true)) => Some(FindBatch::new(command))
    _ => None
  }
  while stack.pop() is Some((path, depth, postorder)) {
    let kind = @fsops.kind_if_exists(path) catch {
      err => {
        @stdio.stderr.write("find: '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    guard kind is Some(kind) else {
      @stdio.stderr.write("find: '\{path}': no such file or directory\n")
      failed = true
      continue
    }
    let directory : DirectoryVisit? = if kind == Directory {
      Some({ path, read: read_directory, state: Unread, })
    } else {
      None
    }
    if parser.depth_first &&
      !postorder &&
      kind == Directory &&
      depth < parser.max_depth {
      stack.push((path, depth, true))
      match directory.unwrap().names() {
        Some(entries) => push_children(stack, path, depth, entries)
        None => failed = true
      }
      continue
    }
    let in_depth = depth >= parser.min_depth && depth <= parser.max_depth
    let size = if needs.size {
      @fswalk.Entry::known(path, kind).regular_size(OpenFile)
    } else {
      None
    }
    let atime = if needs.atime {
      Some(@fsops.read_file_timestamp(path, AccessTime, follow_symlink=false))
    } else {
      None
    }
    let mtime = if needs.mtime {
      Some(
        @fsops.read_file_timestamp(path, ModificationTime, follow_symlink=false),
      )
    } else {
      None
    }
    let ctime = if needs.ctime {
      Some(
        @fsops.read_file_timestamp(path, StatusChangeTime, follow_symlink=false),
      )
    } else {
      None
    }
    let followed_kind = if needs.followed_kind {
      if kind == SymLink {
        Some(@fs.kind(path, follow_symlink=true) catch { _ => SymLink })
      } else {
        Some(kind)
      }
    } else {
      None
    }
    let entry : FindEntry = {
      path,
      kind,
      followed_kind,
      size,
      atime,
      mtime,
      ctime,
      readable: if needs.readable {
        Some(@fs.can_read(path))
      } else {
        None
      },
      writable: if needs.writable {
        Some(@fs.can_write(path))
      } else {
        None
      },
      executable: if needs.executable {
        Some(@fs.can_execute(path))
      } else {
        None
      },
      directory,
    }
    let (matched, prune) = if in_depth {
      expression.evaluate(entry, context)
    } else {
      (false, false)
    }
    if directory is Some({ state: Failed, .. }) {
      failed = true
    }
    if in_depth && matched && !(prune && parser.action is Some(Print(_))) {
      match parser.action {
        None => @stdio.stdout.write(path + "\n")
        Some(Print(zero)) =>
          @stdio.stdout.write(path + (if zero { "\u0000" } else { "\n" }))
        Some(Delete) =>
          if kind == Directory {
            @fs.rmdir(path)
          } else {
            @fs.remove(path)
          }
        Some(Exec(command, grouped)) =>
          if grouped {
            if !batch.unwrap().push(path) {
              failed = true
            }
          } else {
            let expanded : Array[String] = command.map(argument => {
              if argument == "{}" {
                path
              } else {
                argument
              }
            })
            guard expanded.get(0) is Some(program) else { continue }
            let code = @process.run(
              @process.child(program, expanded[1:].to_owned()),
            ) catch {
              err => {
                @stdio.stderr.write("find: \{err}\n")
                failed = true
                continue
              }
            }
            if code < 0 {
              @stdio.stderr.write("find: child terminated by signal\n")
            }
          }
      }
    }
    if !parser.depth_first &&
      kind == Directory &&
      depth < parser.max_depth &&
      !prune {
      match directory.unwrap().names() {
        Some(entries) => push_children(stack, path, depth, entries)
        None => failed = true
      }
    }
  }
  if batch is Some(batch) && !batch.flush() {
    failed = true
  }
  failed
}
