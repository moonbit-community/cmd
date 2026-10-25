///|
async fn directory_exists(path : String) -> Bool {
  try @fs.kind(path) catch {
    @os_error.OSError(_) as error if error.is_ENOENT() => false
    error => raise error
  } noraise {
    kind => kind is Directory
  }
}

///|
async fn create_parents(path : String, verbose : Bool) -> Unit {
  let pending : Array[String] = []
  let mut ancestor = path
  while !directory_exists(ancestor) {
    pending.push(ancestor)
    let parent = @fsops.dirname(ancestor)
    if parent == ancestor {
      @fs.mkdir(ancestor, permission=0o777)
      break
    }
    ancestor = parent
  }
  for index = pending.length() - 1; index >= 0; index = index - 1 {
    let directory = pending[index]
    // A preceding creation can make an explicit dot/dot-dot prefix exist.
    if directory_exists(directory) {
      continue
    }
    @fs.mkdir(directory, permission=0o777)
    if verbose {
      @stdio.stdout.write("mkdir: created directory '\{directory}'\n")
    }
  }
}

///|
fn mkdir_error(error : Error) -> String {
  match error {
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      "No such file or directory"
    @os_error.OSError(_) as error if error.is_ENOTDIR() => "Not a directory"
    @os_error.OSError(_) as error if error.is_EACCES() => "Permission denied"
    @os_error.OSError(_) as error if error.is_EEXIST() => "File exists"
    _ => error.to_string()
  }
}
