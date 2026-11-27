///|
async fn zip(args : ArrayView[String]) -> Unit {
  let parsed = @cli.parse(args, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("zip \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands is [archive, .. paths] else {
    raise @archivefs.ArchiveError("expected ARCHIVE FILE...")
  }
  let level = match
    parsed.last_occurrence(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]) {
    Some(level) => level[0].to_int() - '0'.to_int()
    None => 6
  }
  let name = if archive != "-" &&
    !archive.split("/").last().unwrap().contains(".") {
    archive + ".zip"
  } else {
    archive
  }
  let testing = parsed.contains("test")
  let limits = @zip.ReadLimits(
    max_entries=@archivefs.MAX_ENTRIES,
    max_entry_uncompressed_bytes=@archivefs.MAX_BYTES,
    max_total_uncompressed_bytes=@archivefs.MAX_BYTES,
  )
  if paths.is_empty() {
    guard testing else {
      raise @archivefs.ArchiveError("expected ARCHIVE FILE...")
    }
    ignore(@zip.read_all(@archivefs.read_archive(name), limits~))
    if !parsed.contains("quiet") {
      @stdio.stdout.text.write("test of " + name + " OK\n")
    }
    return
  }
  let entries = @archivefs.collect(
    paths,
    recursive=parsed.contains("recursive"),
  )
  let data = @zip.Archive()
  for entry in entries {
    match entry.content {
      Directory => data.insert(entry.name, b"", compression=Store)
      Regular(bytes) =>
        data.insert(
          entry.name,
          bytes,
          compression=if level == 0 { Store } else { Deflate },
        )
      Special =>
        raise @archivefs.ArchiveError(
          "unsupported archive member: " + entry.name,
        )
    }
  }
  let packed = @zip.write(data, level~, max_output_bytes=@archivefs.MAX_BYTES)
  if testing {
    ignore(@zip.read_all(packed, limits~))
  }
  @archivefs.write_archive(name, packed)
  if !parsed.contains("quiet") && name != "-" {
    for entry in entries {
      @stdio.stdout.text.write("  adding: " + entry.name + "\n")
    }
    if testing {
      @stdio.stdout.text.write("test of " + name + " OK\n")
    }
  }
}

///|
pub async fn run_main() -> Unit {
  let err = try zip(@env.args()[1:]) catch {
    @archivefs.ArchiveError(msg) => msg
    @cli.CliError(option~, message~, ..) => message + ": " + option
    error => error.to_string()
  } noraise {
    _ => return
  }
  @stdio.stderr.text.write("zip: " + err + "\n")
  @env.exit(1)
}
