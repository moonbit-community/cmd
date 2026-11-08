///|
const CommandVersion = "0.1.0"

///|
priv suberror UsageError {
  UsageError(String)
}

///|
const Usage =
  #|Usage: serve [--host ADDRESS] [-p PORT|--port PORT] [DIRECTORY]
  #|Serve regular files over HTTP (default: ., 127.0.0.1:8000).
  #|Directories serve index.html; no directory listing is generated.
  #|  --host ADDRESS  numeric IPv4 or IPv6 listen address
  #|  -p, --port PORT listen port (0 chooses an available port)
  #|  --help          display this help and exit
  #|  --version       display version and exit

///|
fn options(args : ArrayView[String]) -> (String, @socket.Addr) raise {
  let mut host = "127.0.0.1"
  let mut port = 8000
  let mut directory : String? = None
  let mut operands = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if !operands && arg == "--" {
      operands = true
    } else if !operands && (arg == "--host" || arg == "--port" || arg == "-p") {
      i += 1
      guard i < args.length() else {
        raise UsageError("missing value for " + arg)
      }
      if arg == "--host" {
        host = args[i]
      } else {
        port = @string.parse_int(args[i]) catch {
          _ => raise UsageError("invalid port: " + args[i])
        }
        guard port >= 0 && port <= 65535 else {
          raise UsageError("invalid port: " + args[i])
        }
      }
    } else if !operands && arg.has_prefix("-") {
      raise UsageError("unknown option: " + arg)
    } else {
      guard directory is None else {
        raise UsageError("expected at most one directory")
      }
      directory = Some(arg)
    }
    i += 1
  }
  let address = if host.contains(":") {
    "[" + host + "]:" + port.to_string()
  } else {
    host + ":" + port.to_string()
  }
  (directory.unwrap_or("."), @socket.Addr::parse(address))
}

///|
async fn main {
  let args = @env.args()[1:]
  if args is ["--help"] {
    @stdio.stdout.write(Usage + "\n")
    return
  }
  if args is ["--version"] {
    @stdio.stdout.write("serve " + CommandVersion + "\n")
    return
  }
  try {
    let (directory, address) = options(args)
    let root = @fs.realpath(directory)
    guard @fs.kind(root) is Directory else {
      fail("not a directory: " + directory)
    }
    let server = @http.Server(address)
    defer server.close()
    @stdio.stderr.write(
      "Serving " + root + " on http://" + server.addr.to_string() + "\n",
    )
    server.run_forever(
      (request, _body, connection) => serve_file(root, request, connection),
      max_connections=64,
    )
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
