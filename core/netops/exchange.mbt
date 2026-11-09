///|
/// One wire request. Command adapters resolve credentials, cookies, redirects,
/// host spelling and entity headers before entering the transport scope.
pub(all) struct Request {
  target : ParsedUrl
  host : String
  request_method : HttpMethod
  headers : Array[HttpHeader]
  body : RequestBody
}

///|
/// Transport limits share an absolute monotonic deadline across exchanges.
pub(all) struct Transport {
  proxy : ParsedUrl?
  verify_tls : Bool
  connect_timeout_ms : Int32
  idle_timeout_ms : Int32
  deadline_ms : Int64?
}

///|
pub(all) struct ResponseHead {
  code : Int32
  reason : String
  fields : Array[HttpHeader]
  framing : ResponseFraming
  complete : Bool
}

///|
/// Incomplete framing is an observation. A command owns whether any particular
/// EOF position is accepted by its compatibility contract.
pub(all) enum BodyBoundary {
  FixedPayload
  ChunkPayload
  ChunkSizeLine
  ChunkSeparatorBytes
  TrailerFields
}

///|
pub(all) enum BodyRead {
  Data(Bytes)
  End
  Incomplete(BodyBoundary)
}

///|
pub struct ResponseScope {
  priv wire : HttpWire
  priv head : ResponseHead
  priv transport : Transport
  priv mut closed : Bool
  priv mut received_bytes : Int64
}

///|
pub fn ResponseScope::head(self : ResponseScope) -> ResponseHead {
  { ..self.head, fields: self.head.fields.copy(), }
}

///|
pub fn ResponseScope::sent_bytes(self : ResponseScope) -> Int64 {
  self.wire.request_payload_bytes
}

///|
pub fn ResponseScope::close(self : ResponseScope) -> Unit {
  if !self.closed {
    self.closed = true
    self.wire.close()
  }
}

///|
fn Transport::timeout(
  self : Transport,
  limit : Int32,
  phase : String,
) -> Int32 raise TransferError {
  match self.deadline_ms {
    None => limit
    Some(deadline) => {
      let remaining = deadline - @async.now()
      guard remaining > 0L else {
        raise transfer_error(
          TimeoutFailure,
          "operation timed out during \{phase}",
        )
      }
      limit.min(remaining.min(2147483647L).to_int())
    }
  }
}

///|
pub async fn ResponseScope::read(
  self : ResponseScope,
  max_len~ : Int32 = 65536,
) -> BodyRead {
  self.read_body(max_len~) catch {
    TransferError(..) as error =>
      raise with_failure_context(
        error,
        failure_context(
          ResponseBody,
          framing=self.head.framing,
          sent_bytes=self.sent_bytes(),
          received_bytes=self.received_bytes,
        ),
      )
    error => raise error
  }
}

///|
async fn ResponseScope::read_body(
  self : ResponseScope,
  max_len~ : Int32,
) -> BodyRead {
  guard !self.closed && max_len > 0 else {
    raise transfer_error(
      ReceiveFailure,
      "response scope is closed or read bound is invalid",
    )
  }
  let timeout = self.transport.timeout(
    self.transport.idle_timeout_ms,
    "response body",
  )
  let result = @async.with_timeout_opt(timeout, () => {
    self.wire.read_some(max_len~)
  }) catch {
    @io.ReaderClosed =>
      return Incomplete(
        match self.wire.body {
          Fixed(_) => FixedPayload
          ChunkData(_) => ChunkPayload
          ChunkSize => ChunkSizeLine
          ChunkSeparator => ChunkSeparatorBytes
          Trailers => TrailerFields
          _ =>
            raise transfer_error(
              ReceiveFailure,
              "unexpected response EOF state",
            )
        },
      )
    TransferError(..) as error => raise error
    error =>
      raise transfer_error(
        ReceiveFailure,
        "response body read failed: \{error}",
      )
  }
  match result {
    Some(Some(bytes)) => {
      self.received_bytes += bytes.length().to_int64()
      Data(bytes)
    }
    Some(None) => End
    None => raise timeout_error("response body", timeout)
  }
}

///|
pub async fn[T] with_response(
  request : Request,
  transport : Transport,
  consume : async (ResponseScope) -> T,
) -> T {
  guard transport.connect_timeout_ms > 0 && transport.idle_timeout_ms > 0 else {
    raise transfer_error(TimeoutFailure, "timeouts must be greater than zero")
  }
  let wire = open_transport(request.target, transport) catch {
    TransferError(..) as error =>
      raise with_failure_context(error, failure_context(Connection))
    error => raise error
  }
  let closed = Ref(false)
  defer (if !closed.val { wire.close() })
  let response = exchange_request(wire, request, transport)
  let scope = {
    wire,
    head: response,
    transport,
    closed: false,
    received_bytes: 0L,
  }
  defer {
    scope.close()
    closed.val = true
  }
  consume(scope)
}
