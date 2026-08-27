///|
priv struct LsOptions {
  mut all : Bool
  mut almost_all : Bool
  mut directory : Bool
  mut classify : Bool
  mut recursive : Bool
}

///|
fn join_path(parent : String, name : String) -> String {
  if parent == "/" {
    "/" + name
  } else {
    parent + "/" + name
  }
}

///|
fn indicator(kind : @fs.FileKind) -> String {
  match kind {
    Directory => "/"
    SymLink => "@"
    Pipe => "|"
    Socket => "="
    _ => ""
  }
}

///|
async fn print_operand(path : String, options : LsOptions) -> Unit {
  let suffix = if options.classify {
    indicator(@fs.kind(path, follow_symlink=false))
  } else {
    ""
  }
  @stdio.stdout.write(path + suffix + "\n")
}

///|
async fn directory_entries(path : String, options : LsOptions) -> Array[String] {
  let entries = @fs.readdir(
    path,
    include_hidden=options.all || options.almost_all,
    include_special=options.all,
    sort=false,
  )
  entries.sort_by((left, right) => left.lexical_compare(right))
  entries
}

///|
async fn print_directory(
  path : String,
  options : LsOptions,
  show_header : Bool,
  printed_section : Ref[Bool],
) -> Array[String] {
  if show_header {
    if printed_section.val {
      @stdio.stdout.write("\n")
    }
    @stdio.stdout.write(path + ":\n")
  }
  printed_section.val = true
  let entries = directory_entries(path, options)
  let child_dirs : Array[String] = []
  for name in entries {
    let child = join_path(path, name)
    let kind = @fs.kind(child, follow_symlink=false)
    let suffix = if options.classify { indicator(kind) } else { "" }
    @stdio.stdout.write(name + suffix + "\n")
    if options.recursive && kind == Directory && name != "." && name != ".." {
      child_dirs.push(child)
    }
  }
  child_dirs
}

///|
fn apply_short_flags(options : LsOptions, arg : String) -> Bool {
  for flag in arg[1:] {
    match flag {
      'a' => options.all = true
      'A' => options.almost_all = true
      'd' => options.directory = true
      'F' => options.classify = true
      'R' => options.recursive = true
      '1' => ()
      _ => return false
    }
  }
  true
}

///|
async fn main {
  let args = @env.args()[1:]
  let options : LsOptions = {
    all: false,
    almost_all: false,
    directory: false,
    classify: false,
    recursive: false,
  }
  let operands : Array[String] = []
  let mut options_enabled = true
  for arg in args {
    if options_enabled && arg == "--" {
      options_enabled = false
    } else if options_enabled && arg == "--all" {
      options.all = true
    } else if options_enabled && arg == "--almost-all" {
      options.almost_all = true
    } else if options_enabled && arg == "--directory" {
      options.directory = true
    } else if options_enabled && arg == "--classify" {
      options.classify = true
    } else if options_enabled && arg == "--recursive" {
      options.recursive = true
    } else if options_enabled && arg == "--help" {
      @stdio.stdout.write("Usage: ls [-aAdF1R] [FILE...]\n")
      return
    } else if options_enabled && arg.has_prefix("-") && arg != "-" {
      if !apply_short_flags(options, arg) {
        @stdio.stderr.write("ls: unsupported option: '\{arg}'\n")
        @sys.exit(2)
        return
      }
    } else {
      operands.push(arg)
    }
  }
  let paths = if operands.is_empty() { ["."] } else { operands }
  let mut failed = false
  let directories : Array[String] = []
  for path in paths {
    let kind = @fs.kind(path, follow_symlink=false) catch {
      err => {
        @stdio.stderr.write("ls: cannot access '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    if kind == Directory && !options.directory {
      directories.push(path)
    } else {
      print_operand(path, options) catch {
        err => {
          @stdio.stderr.write("ls: cannot access '\{path}': \{err}\n")
          failed = true
        }
      }
    }
  }
  let printed_section = Ref(false)
  let show_top_header = paths.length() > 1 || options.recursive
  for directory in directories {
    let pending : Array[String] = [directory]
    let mut first = true
    while pending.pop() is Some(path) {
      let children = print_directory(
        path,
        options,
        show_top_header || !first,
        printed_section,
      ) catch {
        err => {
          @stdio.stderr.write("ls: cannot open '\{path}': \{err}\n")
          failed = true
          first = false
          continue
        }
      }
      let mut index = children.length()
      while index > 0 {
        index -= 1
        pending.push(children[index])
      }
      first = false
      if !options.recursive {
        pending.clear()
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
