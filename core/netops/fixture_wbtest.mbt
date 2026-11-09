///|
async fn serve_raw_response(
  group : @async.TaskGroup[Unit],
  response : String,
) -> @socket.TcpServer {
  serve_raw_bytes_response(group, @utf8.encode(response))
}

///|
async fn serve_raw_bytes_response(
  group : @async.TaskGroup[Unit],
  response : Bytes,
  requests? : Array[String],
) -> @socket.TcpServer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  group.add_defer(() => server.close())
  group.spawn_bg(no_wait=true, () => {
    server.run_forever((connection, _) => {
      let request = StringBuilder()
      while connection.read_until("\r\n") is Some(line) && line != "" {
        request.write_string(line + "\r\n")
      }
      if requests is Some(requests) {
        requests.push(request.to_string())
      }
      if !response.is_empty() {
        connection.write(response)
      }
    })
  })
  server
}
