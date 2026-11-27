///|
fn diagnostic(error : Error) -> String {
  let text = error.to_string()
  // Preserve the command-level source name in existing Failure diagnostics.
  match text.strip_prefix("Failure(internal/driver/") {
    Some(location) => "Failure(" + location.to_owned()
    None => text
  }
}

///|
priv suberror UsageError {
  UsageError(String)
}

///|
let command : @argparse.Command = Command(
  "serve",
  about="Serve regular files and directory index.html documents over HTTP.",
  version="serve " + MODULE_VERSION,
  options=command_options(),
  positionals=[
    PositionArg("directory", about="Directory to serve.", default_values=["."]),
  ],
)

///|
fn options(args : @argparse.Matches) -> (String, @socket.Addr) raise {
  let host = args.values["host"][0]
  let raw_port = args.values["port"][0]
  let port = @string.parse_int(raw_port) catch {
    _ => raise UsageError("invalid port: " + raw_port)
  }
  guard port >= 0 && port <= 65535 else {
    raise UsageError("invalid port: " + raw_port)
  }
  let address = if host.contains(":") {
    "[" + host + "]:" + port.to_string()
  } else {
    host + ":" + port.to_string()
  }
  (args.values["directory"][0], @socket.Addr::parse(address))
}

///|
pub async fn run_main() -> Unit {
  let args = match command.parse_outcome(argv=@env.args()[1:]) {
    Parsed(args) => args
    Help(text) | Version(text) => {
      @stdio.stdout.write(text + "\n")
      return
    }
    Failed(error) => {
      @stdio.stderr.write(diagnostic(error))
      @env.exit(1)
      return
    }
  }
  try {
    let (directory, address) = options(args)
    let root = @fs.realpath(directory)
    guard @fs.kind(root) is Directory else {
      fail("not a directory: " + directory)
    }
    let files = @static_files.Directory::Directory(root)
    let server = @http.Server(address)
    defer server.close()
    @stdio.stderr.write(
      "Serving " + root + " on http://" + server.addr.to_string() + "\n",
    )
    server.run_forever(
      (request, _body, connection) => files.serve(request, connection),
      max_connections=64,
    )
  } catch {
    UsageError(message) => {
      @stdio.stderr.write("serve: " + message + "\n")
      @env.exit(1)
    }
    error => {
      @stdio.stderr.write("serve: " + diagnostic(error) + "\n")
      @env.exit(1)
    }
  }
}
