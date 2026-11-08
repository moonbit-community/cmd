// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The `watch` command (upstream `typst-cli/src/watch.rs`; its `Status` is in
// `watch_status.mbt`), on the targets that can watch files (native, wasm).

///|
/// Execute a watching compilation command.
async fn watch(command : WatchCommand) -> Unit {
  // (Upstream's `Timer`: `--timings` is not supported by this port, see
  // `CompileConfig::new_impl`.)
  let config = CompileConfig::watching(command)
  guard config.output is Path(output) else {
    raise bail("cannot write document to stdout in watch mode")
  }

  // Not upstream: the watcher gets its events from tasks of the CLI's
  // event loop (notify uses a thread of its own).
  let result : Ref[Result[Unit, HintedFailure]] = { val: Ok(()), }
  @watcher.run(group => {
    watching(command, config, output, group) catch {
      HintedFailure(_) as err => result.val = Err(err)
      err => result.val = Err(bail(err.to_string()))
    }
  }) catch {
    err => raise bail(err.to_string())
  }
  match result.val {
    Ok(_) => ()
    Err(err) => raise err
  }
}

///|
/// The body of [`watch`].
async fn watching(
  command : WatchCommand,
  config : CompileConfig,
  output : String,
  group : @watcher.Tasks,
) -> Unit {
  // Create a file system watcher.
  let watcher = @watcher.Watcher::new(Some(output), group)

  // Create the world that serves sources, files, and fonts.
  // Additionally, if any files do not exist, wait until they do.
  let world = for ;; {
    try
      SystemWorld::new(
        Some(command.args.input),
        command.args.world,
        command.args.process,
      )
    catch {
      InputNotFound(path) | RootNotFound(path) as err => {
        watcher.update([path]) catch {
          @kit.StrError(msg) => raise bail(msg)
        }
        Status::Error.print(config)
        print_error("\{err}")
        watcher.wait() catch {
          @kit.StrError(msg) => raise bail(msg)
        }
      }
      err => raise bail("\{err}")
    } noraise {
      world => break world
    }
  }

  // World construction has already awaited font discovery, outside the
  // displayed compilation time.

  // Perform initial compilation.
  compile_once(world, config)

  // Print warning when trying to watch stdin.
  if config.input is Stdin {
    warn_watching_std(world, config)
  }

  // Recompile whenever something relevant happens.
  for ;; {
    // Watch all dependencies of the most recent compilation.
    watcher.update(world.dependencies()) catch {
      @kit.StrError(msg) => raise bail(msg)
    }

    // Wait until anything relevant happens.
    watcher.wait() catch {
      @kit.StrError(msg) => raise bail(msg)
    }

    // Reset all dependencies.
    world.reset()

    // Recompile.
    compile_once(world, config)

    // Evict the cache.
    @library.evict(10)
  }
}

///|
/// Emits a warning when trying to watch stdin.
async fn warn_watching_std(world : SystemWorld, config : CompileConfig) -> Unit {
  let warning = @library.SourceDiagnostic::warning(
      @syntax.DiagSpan::detached(),
      "cannot watch changes for stdin",
    )
    .with_hint("to recompile on changes, watch a regular file instead")
    .with_hint("to compile once and exit, please use `typst compile` instead")
  print_diagnostics(world, [], [warning], config.diagnostic_format) catch {
    err => raise bail("failed to print diagnostics (\{err})")
  }
}
