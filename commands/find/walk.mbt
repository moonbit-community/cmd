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
async fn DirectoryVisit::names(
  self : DirectoryVisit,
  fresh~ : Bool = false,
) -> Array[String]? {
  if fresh {
    self.state = Unread
  }
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
    @os_error.OSError(_) as error => {
      self.state = Failed
      @stdio.stderr.write("find: '\{self.path}': \{find_os_message(error)}\n")
      None
    }
    error => raise error
  }
}

///|
fn push_children(
  stack : Array[(String, Int32, FindEntry?)],
  path : String,
  depth : Int32,
  entries : Array[String],
) -> Unit {
  entries.sort_by((left, right) => left.lexical_compare(right))
  for index = entries.length(); index > 0; index = index - 1 {
    stack.push((join_path(path, entries[index - 1]), depth + 1, None))
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
  let expression = expression.optimize()
  let needs = expression.metadata_needs()
  let expression = if parser.action is None {
    And(expression, Action(Print(false)))
  } else {
    expression
  }
  let stack : Array[(String, Int32, FindEntry?)] = []
  let mut path_index = paths.length()
  while path_index > 0 {
    path_index -= 1
    stack.push((paths[path_index], 0, None))
  }
  let mut failed = false
  let batch = match parser.action {
    Some(Exec(command, true)) => Some(FindBatch::new(command))
    _ => None
  }
  let evaluation : FindEvaluation = { times: context, batch, }
  while stack.pop() is Some((path, depth, previous)) {
    let kind = try {
      match previous {
        Some(entry) => Some(entry.kind)
        None => @fsops.kind_if_exists(find_lookup_path(path))
      }
    } catch {
      @os_error.OSError(_) as err => {
        @stdio.stderr.write("find: '\{path}': \{find_os_message(err)}\n")
        failed = true
        continue
      }
      err => raise err
    }
    guard kind is Some(kind) else {
      @stdio.stderr.write("find: '\{path}': No such file or directory\n")
      failed = true
      continue
    }
    let directory : DirectoryVisit? = if kind == Directory {
      Some({ path, read: read_directory, state: Unread, })
    } else {
      None
    }
    let in_depth = depth >= parser.min_depth && depth <= parser.max_depth
    let entry : FindEntry = match previous {
      Some(entry) => { ..entry, directory, }
      None =>
        {
          path,
          kind,
          size: Unloaded,
          atime: Unloaded,
          mtime: Unloaded,
          ctime: Unloaded,
          failed: false,
          directory,
        }
    }
    if in_depth {
      entry.load_stat_fields(needs)
    }
    if parser.depth_first &&
      previous is None &&
      kind == Directory &&
      depth < parser.max_depth {
      stack.push((path, depth, Some(entry)))
      match directory.unwrap().names() {
        Some(entries) => push_children(stack, path, depth, entries)
        None => failed = true
      }
      continue
    }
    let (_, prune) = if in_depth {
      expression.evaluate(entry, evaluation)
    } else {
      (false, false)
    }
    if entry.failed || directory is Some({ state: Failed, .. }) {
      failed = true
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
