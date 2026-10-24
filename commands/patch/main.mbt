///|
fn help_message() -> String {
  let message =
    #|Usage: patch [OPTION]... [ORIGINALFILE [PATCHFILE]]
    #|Apply unified or context patches with offsets, fuzz and rejected hunks.
    #|  -p, --strip=N       remove N leading file-name components
    #|  -i, --input=FILE    read the patch from FILE instead of stdin
    #|  -o, --output=-      write patched files to stdout
    #|  -r, --reject-file=FILE  write rejected hunks to a new FILE; - discards
    #|  -d, --directory=DIR resolve target paths relative to DIR
    #|  -R, --reverse       apply additions as removals and vice versa
    #|      --dry-run       check without writing or deleting files
    #|  -s, --quiet         suppress routine file messages
    #|  -u, --unified       require unified input
    #|  -c, --context       require context input
    #|  -t, --batch         select a detected reverse without prompting
    #|  -F, --fuzz=N        ignore up to N outer context lines (default 2)
    #|      --no-backup-if-mismatch  accept the no-backup strict profile
    #|      --help          display this help and exit
    #|      --version       display version and exit
  message
}

///|
fn stripped(name : String, count : Int32?) -> String raise PatchError {
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
async fn run(args : ArrayView[String]) -> Int32 {
  let parsed = @cli.parse(args, [
    @cli.option("strip", short='p'),
    @cli.option("input", short='i'),
    @cli.option("output", short='o'),
    @cli.option("reject-file", short='r'),
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
    @stdio.stdout.write("patch \{command_version}\n")
    return 0
  }
  if parsed.operands.length() > 2 {
    raise PatchError("too many operands")
  }
  let fuzz = @string.parse_int(parsed.last_value("fuzz").unwrap_or("2")) catch {
    _ => raise PatchError("invalid fuzz factor")
  }
  if fuzz < 0 {
    raise PatchError("invalid fuzz factor")
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
  let directory = parsed.last_value("directory").unwrap_or(".")
  let data = if input == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(@fsops.join(directory, input)).binary()
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
  if patches.length() > 1 &&
    (
      explicit is Some(_) ||
      (parsed.last_value("output") is Some(output) && output != "-")
    ) {
    raise PatchError(
      "an explicit target or output requires a single file patch",
    )
  }
  let reverse = parsed.contains("reverse")
  let dry_run = parsed.contains("dry-run")
  let targets : Array[(String, String, Bool, Bool)] = []
  // Validate names and the supported writeback profile before any patch writes.
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
  let diagnostic = if parsed.last_value("output") == Some("-") {
    @stdio.stderr
  } else {
    @stdio.stdout
  }
  let reject_outputs : Map[String, @fs.File] = Map([])
  defer (for file in reject_outputs.values() {
    file.close()
  })
  for index, patch in patches {
    let (label, path, expected_create, expected_remove) = targets[index]
    let mut create = expected_create
    let mut remove = expected_remove
    let mut actual_reverse = reverse
    let mut switched = false
    let kind = @fsops.kind_if_exists(path)
    if parsed.contains("batch") &&
      (
        (create && kind == Some(@fs.FileKind::Regular)) ||
        (remove && kind is None)
      ) {
      diagnostic.write(
        "The next patch would " +
        (if create { "create" } else { "delete" }) +
        " the file \{label},\nwhich " +
        (if create { "already exists" } else { "does not exist" }) +
        "!  " +
        (if reverse { "Ignoring -R.\n" } else { "Assuming -R.\n" }),
      )
      actual_reverse = !reverse
      let previous_create = create
      create = remove
      remove = previous_create
      switched = true
    }
    if create && kind is Some(_) {
      raise PatchError("cannot create existing file '\{label}'")
    }
    if !create && kind != Some(@fs.FileKind::Regular) {
      raise PatchError("input is not a regular file: '\{label}'")
    }
    let original = if create { b"" } else { @fs.read_file(path).binary() }
    if !parsed.contains("quiet") {
      diagnostic.write(
        (if dry_run { "checking file " } else { "patching file " }) +
        (if parsed.last_value("output") == Some("-") {
          "- (read from " + label + ")"
        } else {
          label
        }) +
        "\n",
      )
    }
    if parsed.contains("batch") && !switched {
      actual_reverse = batch_reverse(original, patch.hunks[0], reverse, fuzz)
      if actual_reverse != reverse {
        diagnostic.write(
          if reverse {
            "Unreversed patch detected!  Ignoring -R.\n"
          } else {
            "Reversed (or previously applied) patch detected!  Assuming -R.\n"
          },
        )
      }
    }
    let result = apply_hunks(original, patch.hunks, actual_reverse, fuzz)
    let mut rejected = 0
    for number, outcome in result.results {
      match outcome {
        Rejected(position~, ..) => {
          rejected += 1
          if !parsed.contains("quiet") {
            diagnostic.write("Hunk #\{number + 1} FAILED at \{position}.\n")
          }
        }
        Applied(position~, offset~, fuzz~) =>
          if !parsed.contains("quiet") && (offset != 0 || fuzz != 0) {
            diagnostic.write("Hunk #\{number + 1} succeeded at \{position}")
            if fuzz != 0 {
              diagnostic.write(" with fuzz \{fuzz}")
            }
            if offset != 0 {
              diagnostic.write(
                " (offset \{offset} line" +
                (if offset == 1 { "" } else { "s" }) +
                ")",
              )
            }
            diagnostic.write(".\n")
          }
      }
    }
    let reject_name = parsed
      .last_value("reject-file")
      .unwrap_or(parsed.last_value("output").unwrap_or(label) + ".rej")
    let reject_path = @fsops.join(directory, reject_name)
    if rejected > 0 {
      failed = true
      if !dry_run &&
        reject_name != "-" &&
        !reject_outputs.contains(reject_path) &&
        @fsops.kind_if_exists(reject_path) is Some(_) {
        raise PatchError(
          "replacing an existing reject file requires public file identity; choose a new --reject-file",
        )
      }
    }
    if !dry_run &&
      parsed.last_value("output") != Some("-") &&
      remove &&
      !result.data.is_empty() &&
      result.data != original {
      raise PatchError(
        "partial deletion writeback requires public source mode metadata; use --dry-run or --output=-",
      )
    }
    if dry_run {
      if rejected > 0 {
        diagnostic.write(
          "\{rejected} out of \{patch.hunks.length()} hunk" +
          (if patch.hunks.length() == 1 { "" } else { "s" }) +
          " FAILED\n",
        )
      }
      if parsed.last_value("output") == Some("-") {
        @stdio.stdout.write(result.data)
      }
      continue
    }
    if rejected > 0 {
      diagnostic.write(
        "\{rejected} out of \{patch.hunks.length()} hunk" +
        (if patch.hunks.length() == 1 { "" } else { "s" }) +
        " FAILED",
      )
      if reject_name != "-" {
        diagnostic.write(" -- saving rejects to file \{reject_name}\n")
      } else {
        diagnostic.write("\n")
      }
    }
    match parsed.last_value("output") {
      Some("-") => @stdio.stdout.write(result.data)
      Some(_) =>
        raise PatchError(
          "named output requires public source mode metadata; use --output=-",
        )
      None =>
        if remove && result.data.is_empty() {
          @fs.remove(path)
        } else if create {
          let parent = @fsops.dirname(path)
          if parent != "." {
            @fs.mkdir(parent, recursive=true, permission=0o777)
          }
          @fs.write_file(
            path,
            result.data,
            create_mode=CreateNew,
            permission=0o666,
          )
        }
    }
    if rejected > 0 && reject_name != "-" {
      let reject = match reject_outputs.get(reject_path) {
        Some(file) => file
        None => {
          let file = @fs.open(
            reject_path,
            mode=WriteOnly,
            create_mode=CreateNew,
            permission=0o666,
          )
          reject_outputs[reject_path] = file
          file
        }
      }
      reject.write(reject_bytes(patch, result.results, actual_reverse))
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
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("patch \{command_version}\n")
    return
  }
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
