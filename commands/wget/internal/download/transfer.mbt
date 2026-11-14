///|
fn transport_for(options : Options) -> @netops.Transport raise TransferError {
  let proxy = options.proxy_url.map(url => {
    @netops.parse_absolute_url(url).for_transfer(utf8_hosts=options.utf8_hosts) catch {
      @netops.TransferError(message~, ..) =>
        raise transfer_error(
          ProxyFailure,
          message,
          context=failure_context(Connection),
        )
    }
  })
  {
    proxy,
    verify_tls: options.verify_tls,
    connect_timeout_ms: options.connect_timeout_ms,
    idle_timeout_ms: options.idle_timeout_ms,
    deadline_ms: None,
  }
}

///|
async fn emit(
  observer : (async (TransferEvent) -> Unit)?,
  event : TransferEvent,
) -> Unit {
  match observer {
    Some(callback) => callback(event)
    None => ()
  }
}

///|
pub async fn transfer(
  url : String,
  output : TransferOutput,
  options : Options,
  observer? : async (TransferEvent) -> Unit,
) -> TransferResult {
  validate_options(options)
  @netops.validate_headers(options.headers)
  let requested_url = url
  let mut parsed = @netops.parse_absolute_url(url).for_transfer(
    utf8_hosts=options.utf8_hosts,
  )
  let mut request_method = options.request_method
  let mut body = options.body
  let mut headers = options.headers.copy()
  let seen : Map[(String, String?, String), Bool] = Map([])
  let mut redirect_count = 0
  let mut url_challenged = false
  for ;; {
    let origin = parsed.origin_key()
    let send_basic = options.basic_preemptive ||
      url_challenged ||
      (
        parsed.user_info is None &&
        options.basic_challenged_hosts.contains(parsed.host.to_lower())
      )
    let credentials = parsed.basic_credentials(options)
    let key = (origin, parsed.user_info, parsed.request_target())
    if seen.contains(key) {
      raise transfer_error(
        RedirectFailure,
        "redirect loop detected at \{parsed.to_url()}",
      )
    }
    seen[key] = true
    let length = body_length(body)
    let prepared_headers = request_headers(headers, length, options.resume_from)
    let persistent = prepared_headers.persistent
    let per_request = prepared_headers.per_request
    if send_basic &&
      credentials is Some(credentials) &&
      !prepared_headers.authorization_supplied {
      let remaining = per_request.fields.copy()
      per_request.fields.clear()
      per_request.fields.push(
        @netops.http_header(
          "Authorization",
          "Basic " + @base64.encode(@utf8.encode(credentials)),
        ),
      )
      per_request.fields.append(remaining)
    }
    let stored = match options.cookie_jar {
      Some(jar) => jar.header_octets(parsed, @fsops.current_timestamp().seconds)
      None => None
    }
    if !per_request.contains("Cookie") && stored is Some(value) {
      per_request.fields.push(
        @netops.http_header_bytes("Cookie", cookie_bytes(value)),
      )
    }
    let transport = transport_for(options)
    let header_truncated = Ref(false)
    let pending_header : Ref[Bytes?] = Ref(None)
    let result = @netops.with_response(
      {
        target: parsed,
        host: parsed.request_host(),
        request_method,
        headers: persistent.fields + per_request.fields,
        body,
        chunked: length is None && !(body is EmptyBody),
      },
      transport,
      receive_header=event => {
        receive_header(event, pending_header, header_truncated)
      },
      client => {
        let head = client.head()
        if !head.complete && head.code != 200 {
          raise transfer_error(
            ReceiveFailure,
            "response headers ended before completion",
            context=failure_context(ResponseHeaders),
          )
        }
        let response : Response = {
          code: head.code,
          reason: head.reason,
          headers: Map([]),
          cookies: [],
        }
        for field in head.fields {
          if field.name.to_lower() == "set-cookie" {
            if parse_cookie_octets(cookie_text(field.bytes())) is Some(cookie) {
              response.cookies.push(cookie)
            }
          } else {
            let key = @http.CaseInsensitiveString(field.name)
            response.headers[key] = match response.headers.get(key) {
              None => field.value
              Some(previous) => previous + "," + field.value
            }
          }
        }
        if options.cookie_jar is Some(jar) {
          jar.receive(
            parsed,
            response.cookies,
            @fsops.current_timestamp().seconds,
          )
        }
        let total = response_content_length(response)
        let visible_headers = head.fields
        emit(
          observer,
          ResponseStarted(
            url=parsed.to_url(),
            status=response.code,
            reason=response.reason,
            headers=visible_headers,
            content_length=total,
          ),
        )
        let basic_challenge = response.code == 401 &&
          visible_headers.any(header => {
            header.name.to_lower() == "www-authenticate" &&
            has_basic_challenge(header.value)
          })
        if basic_challenge && !send_basic && credentials is Some(_) {
          if body is StdinBody {
            client.close()
            raise transfer_error(
              InputFailure,
              "cannot replay standard input after an authentication challenge",
            )
          }
          url_challenged = true
          if parsed.user_info is None {
            options.basic_challenged_hosts[parsed.host.to_lower()] = true
          }
          seen.remove(key)
          client.close()
          return None
        }
        if is_redirect(response.code) &&
          response.headers.get("Location") is Some(location) &&
          options.redirects is FollowRedirects(limit) {
          if redirect_count >= limit {
            client.close()
            raise transfer_error(
              RedirectFailure,
              "maximum redirects (\{limit}) exceeded",
              status=response.code,
            )
          }
          let next = @netops.resolve_location(parsed, location).for_transfer(
            utf8_hosts=options.utf8_hosts,
          ) catch {
            @netops.TransferError(message~, ..) => {
              client.close()
              raise transfer_error(
                RedirectFailure,
                "invalid redirect target: \{message}",
                status=response.code,
              )
            }
          }
          emit(
            observer,
            Redirected(
              status=response.code,
              from=parsed.to_url(),
              to=next.to_url(),
            ),
          )
          let cross_origin = parsed.origin_key() != next.origin_key()
          let (next_method, next_body, strip_entity) = rewritten_request(
            response.code,
            request_method,
            body,
          )
          headers = filtered_headers(
            headers,
            cross_origin,
            strip_entity,
            keep_cookie=true,
          )
          request_method = next_method
          body = next_body
          parsed = next
          url_challenged = false
          redirect_count += 1
          client.close()
          return None
        }
        if request_method == Head &&
          response.code == 206 &&
          !per_request.contains("Range") {
          raise transfer_error(
            ReceiveFailure,
            "unexpected partial response during filename discovery",
            status=response.code,
          )
        }
        if response.code == 416 {
          client.close()
          emit(observer, Completed(received=0L, content_length=total))
          return Some({
            requested_url,
            effective_url: parsed.to_url(),
            status: response.code,
            reason: response.reason,
            headers: visible_headers,
            received: 0L,
            output_path: output_path(output, response),
            redirects: redirect_count,
          })
        }
        if (options.fail_on_http_error && response.code >= 400) ||
          options.http_error_statuses.contains(response.code) {
          client.close()
          raise transfer_error(
            if response.code == 401 ||
              (
                basic_challenge &&
                per_request.fields.any(header => {
                  header.name.to_lower() == "authorization" &&
                  uses_basic_authentication(header.value)
                })
              ) {
              AuthenticationFailure
            } else {
              HttpStatusFailure
            },
            "server returned HTTP status \{response.code} \{response.reason}",
            status=response.code,
          )
        }
        let (response_offset, response_span) = resumed_response_range(
          response,
          options.resume_from,
        ) catch {
          @netops.TransferError(kind~, message~, status~, context~) as error => {
            if kind == ProtocolFailure {
              raise @netops.TransferError(
                kind=ReceiveFailure,
                message~,
                status~,
                context~,
              )
            }
            raise error
          }
        }
        if options.resume_from is Some(offset) && offset > 0L {
          match output {
            FileOutput(path~, ..) if output_path(output, response) != Some(path) =>
              raise transfer_error(
                ProtocolFailure,
                "cannot resume into a different Content-Disposition output path",
              )
            _ => ()
          }
        }
        let skip_existing = if response.code == 200 &&
          response_has_body(response.code, request_method) {
          options.resume_from.unwrap_or(0L)
        } else {
          0L
        }
        if options.resume_from is Some(offset) && offset > 0L {
          match output {
            FileOutput(mode=Truncate | Unique, ..) =>
              raise transfer_error(
                ProtocolFailure,
                "retaining a resumed prefix requires append output",
              )
            _ => ()
          }
        }
        let effective_output = if options.keep_output_on_not_modified &&
          response.code == 304 {
          DiscardOutput
        } else {
          match (options.resume_from, response.code, output) {
            (
              Some(offset),
              200,
              FileOutput(path~, content_disposition~, remove_on_error~, ..),
            ) if offset > 0L && !true =>
              FileOutput(
                path~,
                mode=Truncate,
                content_disposition~,
                remove_on_error~,
              )
            _ => output
          }
        }
        let sink = TransferSink::new(effective_output, response) catch {
          @netops.TransferError(..) as error =>
            raise with_failure_context(
              error,
              failure_context(
                ResponseBody,
                framing=response_framing(response, request_method),
              ),
            )
          error => raise error
        }
        let mut count = 0L
        let framing = response_framing(response, request_method)
        let received = sink.with_scope(() => {
          try {
            sink.start(observer, response_offset)
            let mut skip_remaining = skip_existing
            for ;; {
              let chunk = match client.read(max_len=65536) {
                Data(bytes) => bytes
                End => break
                Incomplete(boundary) => {
                  if boundary is (ChunkPayload | TrailerFields) {
                    break
                  }
                  raise response_body_eof(response, request_method, count)
                }
              }
              let skipped = skip_remaining
                .min(chunk.length().to_int64())
                .to_int()
              skip_remaining -= skipped.to_int64()
              count += chunk.length().to_int64()
              if skipped < chunk.length() {
                sink.start(observer, response_offset)
                sink.write(
                  if skipped == 0 {
                    chunk
                  } else {
                    chunk[skipped:].to_owned()
                  },
                )
              }
              emit(observer, Progress(received=count, content_length=total))
            }
            let expected_body_length = match response_span {
              Some(_) => response_span
              None => total
            }
            if response_has_body(response.code, request_method) &&
              expected_body_length is Some(expected) &&
              count != expected {
              raise transfer_error(
                PartialBodyFailure,
                "response body ended after \{count} of \{expected} bytes",
              )
            }
            let completed_shorter_response = response.code == 200 &&
              total == Some(count)
            if skip_remaining > 0L && !completed_shorter_response {
              raise transfer_error(
                PartialBodyFailure,
                "response ended before the already written prefix",
              )
            }
            sink.start(observer, response_offset)
            count
          } catch {
            @netops.TransferError(..) as transfer_failure => {
              sink.close()
              sink.cleanup_after_error() catch {
                _ => ()
              }
              client.close()
              raise response_body_failure(
                transfer_failure,
                framing,
                received_bytes=count,
                committed_bytes=sink.committed,
                write_outcome_uncertain=sink.write_uncertain,
              )
            }
            err => {
              sink.close()
              sink.cleanup_after_error() catch {
                _ => ()
              }
              client.close()
              raise transfer_error(
                ReceiveFailure,
                "response transfer failed: \{err}",
                context=failure_context(
                  ResponseBody,
                  framing~,
                  received_bytes=count,
                  committed_bytes=sink.committed,
                  write_outcome_uncertain=sink.write_uncertain,
                ),
              )
            }
          }
        })
        sink.close()
        client.close()
        emit(observer, Completed(received~, content_length=total))
        return Some({
          requested_url,
          effective_url: parsed.to_url(),
          status: response.code,
          reason: response.reason,
          headers: visible_headers,
          received,
          output_path: sink.path(),
          redirects: redirect_count,
        })
      },
    )
    if result is Some(result) {
      return result
    }
  }
}
