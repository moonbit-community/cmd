///|
async fn tar(args : ArrayView[String]) -> Unit {
  let normalized = args.to_owned()
  if normalized.get(0) is Some(first) &&
    !first.has_prefix("-") &&
    !first.is_empty() {
    normalized[0] = "-" + first
  }
  let parsed = @cli.parse(normalized, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("tar \{MODULE_VERSION}\n")
    return
  }
  guard parsed.last_value("file") is Some(path) else {
    raise @archivefs.ArchiveError("missing -f ARCHIVE")
  }
  let modes = ["create", "list", "extract"].filter(name => parsed.contains(name))
  guard modes is [mode] else {
    raise @archivefs.ArchiveError("choose one of -c, -t or -x")
  }
  if parsed.contains("to-stdout") && mode != "extract" {
    raise @archivefs.ArchiveError("-O requires -x")
  }
  if parsed.contains("directory") && mode != "extract" {
    raise @archivefs.ArchiveError("-C requires -x")
  }
  if mode == "create" {
    guard !parsed.operands.is_empty() else {
      raise @archivefs.ArchiveError("no files specified")
    }
    let bytes = @ustar.write(
      @archivefs.collect(parsed.operands, recursive=true),
    )
    let archive = if parsed.contains("gzip") {
      @gzip.compress(bytes)
    } else {
      bytes
    }
    guard archive.length() <= @archivefs.MAX_BYTES else {
      raise @archivefs.ArchiveError("archive size limit exceeded")
    }
    @archivefs.write_archive(path, archive)
    return
  }
  let input = @archivefs.read_archive(path)
  let bytes = if parsed.contains("gzip") || input.has_prefix(b"\x1f\x8b") {
    @gzip.decompress(input, max_output_bytes=@archivefs.MAX_BYTES)
  } else {
    input
  }
  let entries = @ustar.read(bytes)
  let wanted = parsed.operands
  let seen : Set[String] = Set([])
  let selected = entries.filter(entry => {
    if wanted.is_empty() {
      return true
    }
    let mut match_entry = false
    for name in wanted {
      if entry.name == name ||
        entry.name.has_prefix(name.trim_end(chars="/").to_owned() + "/") {
        seen.insert(name)
        match_entry = true
      }
    }
    match_entry
  })
  for name in wanted {
    guard seen.contains(name) else {
      raise @archivefs.ArchiveError("member not found: " + name)
    }
  }
  if mode == "list" {
    for entry in selected {
      @stdio.stdout.text.write(entry.name + "\n")
    }
  } else if parsed.contains("to-stdout") {
    for entry in selected {
      match entry.content {
        Regular(payload) => @stdio.stdout.write(payload)
        Directory => ()
        Special =>
          raise @archivefs.ArchiveError(
            "unsupported archive member: " + entry.name,
          )
      }
    }
  } else {
    @archivefs.extract(
      selected,
      parsed.last_value("directory").unwrap_or("."),
      create_root=false,
    )
  }
}

///|
pub async fn run_main() -> Unit {
  let err = try tar(@env.args()[1:]) catch {
    @archivefs.ArchiveError(msg) => msg
    @cli.CliError(option~, message~, ..) => message + ": " + option
    error => error.to_string()
  } noraise {
    _ => return
  }
  @stdio.stderr.text.write("tar: " + err + "\n")
  @env.exit(2)
}
