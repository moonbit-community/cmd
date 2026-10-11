///|
fn help_message() -> String {
  let message =
    #|Usage: patch [OPTION]... [ORIGINALFILE [PATCHFILE]]
    #|Apply unified or context patches with exact hunk positions and context.
    #|  -p, --strip=N       remove N leading file-name components
    #|  -i, --input=FILE    read the patch from FILE instead of stdin
    #|  -o, --output=-      write one patched file to stdout
    #|  -d, --directory=DIR resolve target paths relative to DIR
    #|  -R, --reverse       apply additions as removals and vice versa
    #|      --dry-run       check without writing or deleting files
    #|  -s, --quiet         suppress routine file messages
    #|  -u, --unified       require unified input
    #|  -c, --context       require context input
    #|  -t, --batch         accept the noninteractive behavior
    #|  -F, --fuzz=0        only exact context is supported
    #|      --no-backup-if-mismatch  accept the no-backup strict profile
    #|      --help          display this help and exit
    #|      --version       display version and exit
  message
}

///|
fn stripped(name : String, count : Int?) -> String raise PatchError {
  let pieces = name.split("/").filter(s => s != "").to_array()
  let drop = count.unwrap_or((pieces.length() - 1).max(0))
  if count == Some(0) && name.has_prefix("/") {
    raise PatchError("absolute paths in patch headers are not supported")
  }
  if drop >= pieces.length() {
    raise PatchError("file name has too few components for --strip")
  }
  let selected = pieces[drop:]
  if selected.any(part => part == "." || part == ".." || part.contains("\\")) {
    raise PatchError("unsafe file name in patch header")
  }
  selected.map(v => v.to_owned()).join("/")
}

///|
async fn run(args : ArrayView[String]) -> Int {
  let parsed = @cli.parse(args, [
    @cli.option("strip", short='p'),
    @cli.option("input", short='i'),
    @cli.option("output", short='o'),
    @cli.option("directory", short='d'),
    @cli.flag("reverse", short='R'),
    @cli.flag("dry-run"),
    @cli.flag("quiet", short='s'),
    @cli.flag("unified", short='u'),
    @cli.flag("context", short='c'),
    @cli.flag("batch", short='t'),
    @cli.option("fuzz", short='F'),
    @cli.flag("no-backup-if-mismatch"),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("patch (cli) \{command_version}\n")
    return 0
  }
  if parsed.operands.length() > 2 {
    raise PatchError("too many operands")
  }
  if parsed.last_value("fuzz").unwrap_or("0") != "0" {
    raise PatchError("only exact context (--fuzz=0) is supported")
  }
  if parsed.last_value("output") is Some(path) && path != "-" {
    raise PatchError(
      "named output requires public source mode metadata; use --output=-",
    )
  }
  if parsed.contains("unified") && parsed.contains("context") {
    raise PatchError("select either unified or context input")
  }
  let strip = match parsed.last_value("strip") {
    Some(value) => {
      let n = @string.parse_int(value) catch {
        _ => raise PatchError("invalid strip count")
      }
      if n < 0 {
        raise PatchError("invalid strip count")
      }
      Some(n)
    }
    None => None
  }
  if parsed.operands.length() == 2 && parsed.contains("input") {
    raise PatchError("patch file specified twice")
  }
  let input = parsed
    .last_value("input")
    .unwrap_or(
      if parsed.operands.length() == 2 {
        parsed.operands[1]
      } else {
        "-"
      },
    )
  let data = if input == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(input).binary()
  }
  let patches = if parsed.contains("unified") {
    parse_unified(data)
  } else if parsed.contains("context") {
    parse_context(data)
  } else {
    parse_patch(data)
  }
  let explicit : String? = if parsed.operands.is_empty() {
    None
  } else {
    Some(parsed.operands[0])
  }
  if patches.length() > 1 && (explicit is Some(_) || parsed.contains("output")) {
    raise PatchError(
      "an explicit target or output requires a single file patch",
    )
  }
  let reverse = parsed.contains("reverse")
  let dry_run = parsed.contains("dry-run")
  let directory = parsed.last_value("directory").unwrap_or(".")
  let targets : Array[(String, String, Bool, Bool)] = []
  // Validate all names before any patch writes. Exact matching is checked per file.
  for patch in patches {
    let old_name = if reverse { patch.new_name } else { patch.old_name }
    let new_name = if reverse { patch.old_name } else { patch.new_name }
    let create = old_name == "/dev/null"
    let remove = new_name == "/dev/null"
    if !dry_run &&
      !create &&
      !remove &&
      parsed.last_value("output") != Some("-") {
      raise PatchError(
        "rewriting an existing file requires public source mode metadata; use --dry-run or --output=-",
      )
    }
    if create && remove {
      raise PatchError("both patch file names are /dev/null")
    }
    let label = match explicit {
      Some(path) => path
      None => stripped(if create { new_name } else { old_name }, strip)
    }
    let path = if directory == "." {
      label
    } else {
      @fsops.join(directory, label)
    }
    let output = match parsed.last_value("output") {
      Some("-") => "-"
      Some(name) =>
        if directory == "." {
          name
        } else {
          @fsops.join(directory, name)
        }
      None => path
    }
    targets.push((label, path, create, remove))
    if output != "-" {
      let kind = @fsops.kind_if_exists(output)
      if kind is Some(kind) && kind != @fs.FileKind::Regular {
        raise PatchError("output is not a regular file: '\{output}'")
      }
    }
  }
  let mut failed = false
  for index, patch in patches {
    let (label, path, create, remove) = targets[index]
    let kind = @fsops.kind_if_exists(path)
    if create && kind is Some(_) {
      raise PatchError("cannot create existing file '\{label}'")
    }
    if !create && kind != Some(@fs.FileKind::Regular) {
      raise PatchError("input is not a regular file: '\{label}'")
    }
    let original = if create { b"" } else { @fs.read_file(path).binary() }
    if !parsed.contains("quiet") {
      @stdio.stdout.write(
        (if dry_run { "checking file " } else { "patching file " }) +
        label +
        "\n",
      )
    }
    let result = apply_patch_bytes(original, patch.hunks, reverse) catch {
      HunkMismatch(number, position) => {
        @stdio.stderr.write(
          "patch: hunk #\{number} does not match at line \{position}; file unchanged\n",
        )
        failed = true
        continue
      }
    }
    if remove && !result.is_empty() {
      raise PatchError("deletion patch leaves file content")
    }
    if dry_run {
      continue
    }
    match parsed.last_value("output") {
      Some("-") => @stdio.stdout.write(result)
      Some(_) =>
        raise PatchError(
          "named output requires public source mode metadata; use --output=-",
        )
      None =>
        if remove {
          @fs.remove(path)
        } else if create {
          let parent = @fsops.dirname(path)
          if parent != "." {
            @fs.mkdir(parent, recursive=true, permission=0o777)
          }
          @fs.write_file(path, result, create_mode=CreateNew, permission=0o666)
        } else {
          raise PatchError(
            "existing file updates require public source mode metadata",
          )
        }
    }
  }
  if failed {
    1
  } else {
    0
  }
}

///|
async fn main {
  let status = run(@env.args()[1:]) catch {
    PatchError(message) => {
      @stdio.stderr.write("patch: \{message}\n")
      2
    }
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("patch: \{message}: '\{option}'\n")
      2
    }
    err => {
      @stdio.stderr.write("patch: \{err}\n")
      2
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}
