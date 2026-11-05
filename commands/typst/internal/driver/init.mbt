// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The `init` command (upstream `typst-cli/src/init.rs`). Templates are
// served from the local package directories only (downloading packages is
// not supported by this port).

///|
/// Execute an initialization command.
async fn init_project(command : InitCommand) -> Unit {
  let packages = system_packages(command.package_args)

  // Parse the package specification. If the user didn't specify the
  // version, we try to figure it out automatically by searching the disk.
  let spec = match @syntax.PackageSpec::from_str(command.template) {
    Ok(spec) => spec
    Err(err) => {
      // Try to parse without version, but prefer the error message of the
      // normal package spec parsing if it fails.
      guard @syntax.VersionlessPackageSpec::from_str(command.template)
        is Ok(spec) else {
        raise bail(err)
      }
      let version = packages.latest_version(spec) catch {
        @kit.StrError(msg) => raise bail(msg)
      }
      spec.at(version)
    }
  }

  // Find the package.
  let root = packages.obtain(spec) catch { err => raise bail(err.to_string()) }
  let package_path = root.path()

  // Parse the manifest.
  let manifest = parse_manifest(package_path)
  if manifest.validate(spec) is Err(err) {
    raise bail(err)
  }

  // Ensure that it is indeed a template.
  guard manifest.template is Some(template) else {
    raise bail("package \{spec} is not a template")
  }

  // Determine the directory at which we will create the project.
  let project_dir = command.dir.unwrap_or(manifest.package_.name)

  // Set up the project.
  scaffold_project(project_dir, package_path, template)

  // Print the summary.
  print_summary(spec, project_dir, template)
}

///|
/// Parses the manifest of the package located at `package_path`.
fn parse_manifest(
  package_path : String,
) -> @syntax.PackageManifest raise HintedFailure {
  let toml_path = @platform.join(package_path, "typst.toml")
  let data = @platform.read_file(toml_path) catch {
    err =>
      raise bail(
        "failed to read package manifest (\{@kit.file_error_from_io(err, toml_path)})",
      )
  }
  let string = @utf8.decode(data) catch {
    _ =>
      raise bail(
        "failed to read package manifest (\{@library.FileError::InvalidUtf8})",
      )
  }
  match @syntax.PackageManifest::from_toml(string) {
    Ok(manifest) => manifest
    Err(err) => raise bail("package manifest is malformed (\{err})")
  }
}

///|
/// Creates the project directory with the template's contents.
fn scaffold_project(
  project_dir : String,
  package_path : String,
  template : @syntax.TemplateInfo,
) -> Unit raise HintedFailure {
  if @platform.exists(project_dir) {
    raise bail("project directory already exists (at \{project_dir})")
  }
  let template_dir = @platform.join(package_path, template.path)
  if !@platform.exists(template_dir) {
    raise bail("template directory does not exist (at \{template_dir})")
  }
  copy_dir_contents(template_dir, project_dir) catch {
    err => raise bail("failed to create project directory (\{err})")
  }
}

///|
/// Copies the contents of a directory into a new directory (like
/// `fs_extra::dir::copy` with `content_only`).
fn copy_dir_contents(
  from : String,
  to : String,
) -> Unit raise @platform.IoError {
  @platform.create_dir_all(to)
  for name in @platform.read_dir(from) {
    let src = @platform.join(from, name)
    let dst = @platform.join(to, name)
    match @platform.stat_kind(src) {
      Dir => copy_dir_contents(src, dst)
      _ => @platform.write_file(dst, @platform.read_file(src))
    }
  }
}

///|
/// Prints a summary after successful initialization.
async fn print_summary(
  spec : @syntax.PackageSpec,
  project_dir : String,
  template : @syntax.TemplateInfo,
) -> Unit {
  let gray = @kit.ColorSpec::new().with_fg(White).with_dimmed()
  let out = terminal_out()
  out.writeln("Successfully created new project from \{spec} 🎉")
  out.writeln("To start writing, run:")
  out.set_color(gray)
  out.write("> ")
  out.reset()
  out.writeln("cd \{shell_escape(project_dir)}")
  out.set_color(gray)
  out.write("> ")
  out.reset()
  out.writeln("typst watch \{shell_escape(template.entrypoint)}")
  out.writeln("")
  flush_terminal(out)
}
