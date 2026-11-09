///|
const CommandVersion = "0.1.1"

///|
priv suberror UsageError {
  UsageError(String)
}

///|
let command : @argparse.Command = Command(
  "serve",
  about="Serve regular files and directory index.html documents over HTTP.",
  version="serve " + CommandVersion,
  options=[
    OptionArg(
      "host",
      long="host",
      about="Numeric IPv4 or IPv6 listen address.",
      default_values=["127.0.0.1"],
    ),
    OptionArg(
      "port",
      short='p',
      long="port",
      about="Listen port. Use 0 to choose an available port.",
      default_values=["8000"],
      allow_hyphen_values=true,
    ),
    OptionArg(
      "preview-token",
      long="preview-token",
      about="Serve a loopback preview under a 64-character lowercase hex token until stdin closes. Print the bound port to stdout.",
    ),
  ],
  positionals=[
    PositionArg("directory", about="Directory to serve.", default_values=["."]),
  ],
)

///|
fn options(args : @argparse.Matches) -> (String, @socket.Addr, String?) raise {
  let host = args.values["host"][0]
  let token = args.values.get("preview-token").bind(values => values.get(0))
  if token is Some(token) {
    guard host == "127.0.0.1" else {
      raise UsageError("preview requires host 127.0.0.1")
    }
    guard token.length() == 64 &&
      token.iter().all(c => c is ('0'..<='9' | 'a'..<='f')) else {
      raise UsageError("invalid preview token")
    }
  }
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
  (args.values["directory"][0], @socket.Addr::parse(address), token)
}

///|
async fn main {
  let args = match command.parse_outcome(argv=@env.args()[1:]) {
    Parsed(args) => args
    Help(text) | Version(text) => {
      @stdio.stdout.write(text + "\n")
      return
    }
    Failed(error) => {
      @stdio.stderr.write(error.to_string())
      @sys.exit(1)
      return
    }
  }
  try {
    let (directory, address, token) = options(args)
    let root = @fs.realpath(directory)
    guard @fs.kind(root) is Directory else {
      fail("not a directory: " + directory)
    }
    let server = @http.Server(address)
    defer server.close()
    let port = server.addr.port()
    if token is Some(_) {
      @stdio.stdout.write("\{port}\n")
    } else {
      @stdio.stderr.write(
        "Serving " + root + " on http://" + server.addr.to_string() + "\n",
      )
    }
    @async.with_task_group(group => {
      if token is Some(_) {
        group.spawn_bg(() => {
          while @stdio.stdin.read_some() is Some(_) {

          }
          group.return_immediately(())
        })
      }
      server.run_forever(
        (request, _body, connection) => {
          serve_file(root, request, connection, port~, token?)
        },
        max_connections=64,
      )
    })
  } catch {
    UsageError(message) => {
      @stdio.stderr.write("serve: " + message + "\n")
      @sys.exit(1)
    }
    error => {
      @stdio.stderr.write("serve: " + error.to_string() + "\n")
      @sys.exit(1)
    }
  }
}
