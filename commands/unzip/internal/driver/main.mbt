///|
priv enum Action {
  Names
  Pipe
  Test
  Extract
}

///|
fn content(entry : @zip.Entry) -> @archivefs.Content {
  let unix = entry.creator_system() == 3 || entry.creator_system() == 19
  let kind = (entry.external_attributes() >> 28) & 15
  let dir = entry.name().has_suffix("/") ||
    (entry.external_attributes() & 16) != 0 ||
    (unix && kind == 4)
  if unix && kind != 0 && kind != 4 && kind != 8 {
    return Special
  }
  if dir {
    Directory
  } else {
    Regular(entry.data())
  }
}

///|
async fn unzip(args : ArrayView[String]) -> Unit {
  let normalized = args.to_owned()
  if normalized.get(0) == Some("-Z1") {
    normalized[0] = "--names"
  }
  let parsed = @cli.parse(normalized, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("unzip \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands is [archive, .. wanted] else {
    raise @archivefs.ArchiveError("missing archive")
  }
  let actions = ["names", "pipe", "test"].filter(name => parsed.contains(name))
  let action : Action = match actions {
    [] => Extract
    ["names"] => Names
    ["pipe"] => Pipe
    ["test"] => Test
    _ => raise @archivefs.ArchiveError("choose one of -Z1, -p or -t")
  }
  let data = @archivefs.read_archive(archive)
  let decoded = @zip.read_all(
    data,
    limits=@zip.ReadLimits(
      max_entries=@archivefs.MAX_ENTRIES,
      max_entry_uncompressed_bytes=@archivefs.MAX_BYTES,
      max_total_uncompressed_bytes=@archivefs.MAX_BYTES,
    ),
  )
  let selected : Array[@archivefs.Member] = []
  let missing = Set::from_iter(wanted.iter())
  for entry in decoded.entries() {
    let name = entry.name()
    if wanted.is_empty() || wanted.contains(name) {
      missing.remove(name)
      selected.push({ name, content: content(entry), })
    }
  }
  if missing.iter().next() is Some(name) {
    raise @archivefs.ArchiveError("member not found: " + name)
  }
  match action {
    Names =>
      for entry in selected {
        @stdio.stdout.text.write(entry.name + "\n")
      }
    Pipe =>
      for entry in selected {
        match entry.content {
          Regular(bytes) => @stdio.stdout.write(bytes)
          Directory => ()
          Special =>
            raise @archivefs.ArchiveError(
              "unsupported archive member: " + entry.name,
            )
        }
      }
    Test => {
      let quiet = parsed.order.filter(name => name == "quiet").length()
      if quiet == 0 {
        @stdio.stdout.text.write("Archive:  " + archive + "\n")
        for entry in selected {
          let padding = " ".repeat((22 - entry.name.length()).max(0))
          @stdio.stdout.text.write(
            "    testing: " + entry.name + padding + "   OK\n",
          )
        }
      }
      if quiet < 2 {
        @stdio.stdout.text.write(
          "No errors detected in compressed data of " + archive + ".\n",
        )
      }
    }
    Extract => {
      @archivefs.extract(
        selected,
        parsed.last_value("directory").unwrap_or("."),
        skip_existing=parsed.contains("never-overwrite"),
      )
      if !parsed.contains("quiet") {
        @stdio.stdout.text.write("Archive:  " + archive + "\n")
      }
    }
  }
}

///|
pub async fn run_main() -> Unit {
  let err = try unzip(@env.args()[1:]) catch {
    @archivefs.ArchiveError(msg) => msg
    @cli.CliError(option~, message~, ..) => message + ": " + option
    error => error.to_string()
  } noraise {
    _ => return
  }
  @stdio.stderr.text.write("unzip: " + err + "\n")
  @env.exit(1)
}
