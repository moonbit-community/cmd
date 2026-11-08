///|
priv enum ConnectionKind {
  Plain(@socket.Tcp)
  Secure(@tls.Tls, Connection)
}

///|
priv struct Connection {
  kind : ConnectionKind
}

///|
fn Connection::new(kind : ConnectionKind) -> Connection {
  { kind, }
}

///|
fn Connection::close(self : Connection) -> Unit {
  match self.kind {
    Plain(socket) => socket.close()
    Secure(tls, inner) => {
      tls.close()
      inner.close()
    }
  }
}

///|
async fn Connection::read_some(self : Connection, max_len~ : Int32) -> Bytes? {
  match self.kind {
    Plain(socket) => socket.read_some(max_len~)
    Secure(tls, _) => tls.read_some(max_len~)
  }
}

///|
impl @io.Writer for Connection with fn write_once(self, bytes, offset~, len~) {
  match self.kind {
    Plain(socket) => socket.write_once(bytes, offset~, len~)
    Secure(tls, _) => tls.write_once(bytes, offset~, len~)
  }
}

///|
extend Connection with @io.Writer::{write}

///|
async fn Connection::secure(
  self : Connection,
  host : String,
  trust : @tls.TrustedRoot,
) -> Connection {
  let tls = match self.kind {
    Plain(socket) => @tls.Tls::client(socket, host~, trust~)
    Secure(tls, _) => @tls.Tls::client(tls, host~, trust~)
  }
  Connection::new(Secure(tls, self))
}

///|
fn ParsedUrl::socket_host(self : ParsedUrl) -> String raise TransferError {
  if self.ip_literal {
    let address = self.host[1:self.host.length() - 1].to_owned()
    guard address.contains(":") && !address.contains("%") else {
      raise transfer_error(ConnectionFailure, "invalid bracketed URL host")
    }
    address
  } else {
    self.host
  }
}

///|
fn ParsedUrl::socket_port(self : ParsedUrl) -> Int32 {
  self.port.unwrap_or(if self.scheme == "https" { 443 } else { 80 })
}

///|
async fn connect_endpoint(
  parsed : ParsedUrl,
  proxy : ParsedUrl?,
  trust : @tls.TrustedRoot,
) -> Connection {
  let hostname = parsed.socket_host()
  let base = match proxy {
    None =>
      Connection::new(
        Plain(@socket.Tcp::connect_to_host(hostname, port=parsed.socket_port())),
      )
    Some(proxy) => {
      let connection = connect_endpoint(proxy, None, trust)
      errdefer connection.close()
      // Read only the CONNECT headers here. Extra tunnel bytes must remain
      // in the underlying public TCP/TLS reader for the origin connection.
      let wire = HttpWire::new(connection, read_limit=1)
      let target = parsed.host + ":" + parsed.socket_port().to_string()
      connection.write(
        @utf8.encode(
          "CONNECT " +
          target +
          " HTTP/1.1\r\nHost: " +
          proxy.endpoint +
          "\r\nUser-Agent: moonbit-http-client/1.1\r\nAccept-Encoding: gzip,identity\r\n\r\n",
        ),
      )
      let response = wire.response(Connect)
      guard response.code >= 200 && response.code < 300 else {
        raise transfer_error(ProxyFailure, "proxy connection failed")
      }
      connection
    }
  }
  errdefer base.close()
  if parsed.scheme == "https" {
    base.secure(hostname, trust)
  } else {
    base
  }
}
