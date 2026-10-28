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
  options : TransferOptions,
  observer? : async (TransferEvent) -> Unit,
) -> TransferResult {
  validate_transfer_options(options)
  validate_headers(options.headers)
  let started = @async.now()
  let requested_url = url
  let mut parsed = parse_absolute_url(url).for_transfer(options.profile)
  let credential_origin = parsed.origin_key()
  let challenged_origins : Map[String, Bool] = Map([])
  let mut request_method = options.request_method
  let mut body = options.body
  let mut headers = options.headers.copy()
  let cookie_data = options.cookie_data
  let seen : Map[String, Bool] = Map([])
  let mut redirect_count = 0
  for ;; {
    let origin = parsed.origin_key()
    let credentials_allowed = options.basic_credential_scope == AllOrigins ||
      origin == credential_origin
    let send_basic = options.basic_preemptive ||
      challenged_origins.contains(origin)
    let key = parsed.to_url()
    if seen.contains(key) {
      raise transfer_error(RedirectFailure, "redirect loop detected at \{key}")
    }
    seen[key] = true
    let length = body_length(body)
    let prepared_headers = request_header_maps(
      parsed,
      headers,
      length,
      options.resume_from,
    )
    let persistent = prepared_headers.persistent
    let per_request = prepared_headers.per_request
    if credentials_allowed &&
      send_basic &&
      options.basic_credentials is Some(credentials) &&
      !prepared_headers.authorization_supplied {
      per_request["Authorization"] = "Basic " +
        @base64.encode(@utf8.encode(credentials))
    }
    let stored = match options.cookie_jar {
      Some(jar) =>
        jar.header_for(
          parsed,
          @fsops.current_timestamp().seconds,
          profile=options.profile,
        )
      None => None
    }
    if per_request.contains("Cookie") &&
      stored is Some(value) &&
      options.custom_cookie_mode is SeparateFields {
      // The transport serializes persistent headers before request headers. These are two
      // independent maps, so the jar and explicit field retain their wire
      // identity and order without merging values.
      persistent["Cookie"] = value
    }
    if !per_request.contains("Cookie") {
      let literal = if parsed.origin_key() == credential_origin {
        cookie_data
      } else {
        None
      }
      let value = match (stored, literal) {
        (Some(stored), Some(literal)) => Some(stored + "; " + literal)
        (Some(stored), None) => Some(stored)
        (None, Some(literal)) => Some(literal)
        (None, None) => None
      }
      if value is Some(value) {
        per_request["Cookie"] = value
      }
    }
    let client = open_client(parsed, options, started) catch {
      TransferError(..) as error =>
        raise with_failure_context(error, failure_context(Connection))
      error => raise error
    }
    errdefer client.close()
    let response = send_request(
      client, parsed, request_method, persistent, per_request, body, options, started,
    ) catch {
      TransferError(..) as err =>
        raise with_failure_context(err, failure_context(Request))
      err =>
        raise transfer_error(
          ConnectionFailure,
          "HTTP request failed: \{err}",
          context=failure_context(Request),
        )
    }
    if options.cookie_jar is Some(jar) {
      jar.receive(
        parsed,
        response.cookies,
        @fsops.current_timestamp().seconds,
        profile=options.profile,
      )
    }
    let total = response_content_length(response)
    let visible_headers = response_headers(response, client.cookie_fields)
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
    if response.code == 401 &&
      !send_basic &&
      credentials_allowed &&
      options.basic_credentials is Some(_) &&
      response.headers.get("WWW-Authenticate") is Some(challenge) &&
      challenge.to_lower().trim_start().has_prefix("basic") {
      if body is StdinBody {
        client.close()
        raise transfer_error(
          InputFailure,
          "cannot replay standard input after an authentication challenge",
        )
      }
      challenged_origins[origin] = true
      seen.remove(key)
      client.close()
      continue
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
      let next = resolve_location(parsed, location).for_transfer(
        options.profile,
        redirect=true,
      ) catch {
        TransferError(message~, ..) => {
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
        Redirected(status=response.code, from=parsed.to_url(), to=next.to_url()),
      )
      let cross_origin = parsed.origin_key() != next.origin_key()
      let (next_method, next_body, strip_entity) = rewritten_request(
        response.code,
        request_method,
        body,
        options.preserve_method_on_redirect,
      )
      require_replayable_redirect(
        options.profile,
        next_body,
        client.request_payload_bytes,
      )
      headers = filtered_headers(
        headers,
        cross_origin,
        strip_entity,
        keep_cookie=options.custom_cookie_cross_origin,
      )
      request_method = next_method
      body = next_body
      parsed = next
      redirect_count += 1
      client.close()
      continue
    }
    if options.profile == WgetProfile &&
      request_method == Head &&
      response.code == 206 &&
      !per_request.contains("Range") {
      raise transfer_error(
        ReceiveFailure,
        "unexpected partial response during filename discovery",
        status=response.code,
      )
    }
    if options.profile == WgetProfile && response.code == 416 {
      client.close()
      emit(observer, Completed(received=0L, content_length=total))
      return {
        requested_url,
        effective_url: parsed.to_url(),
        status: response.code,
        reason: response.reason,
        headers: visible_headers,
        received: 0L,
        output_path: output_path(output, response),
        redirects: redirect_count,
      }
    }
    if (options.fail_on_http_error && response.code >= 400) ||
      options.http_error_statuses.contains(response.code) {
      client.close()
      raise transfer_error(
        HttpStatusFailure,
        "server returned HTTP status \{response.code} \{response.reason}",
        status=response.code,
      )
    }
    let (response_offset, response_span) = resumed_response_range(
      response,
      options.resume_from,
    ) catch {
      TransferError(kind~, message~, status~, context~) as error => {
        if options.profile == WgetProfile && kind == ProtocolFailure {
          raise TransferError(kind=ReceiveFailure, message~, status~, context~)
        }
        raise error
      }
    }
    if options.resume_from is Some(offset) &&
      offset > 0L &&
      (options.resume_skip_existing || response.code == 206) {
      match output {
        FileOutput(path~, ..) if output_path(output, response) != Some(path) =>
          raise transfer_error(
            ProtocolFailure,
            "cannot resume into a different Content-Disposition output path",
          )
        _ => ()
      }
    }
    let skip_existing = if options.resume_skip_existing &&
      response.code == 200 &&
      response_has_body(response.code, request_method) {
      options.resume_from.unwrap_or(0L)
    } else {
      0L
    }
    if options.resume_skip_existing &&
      options.resume_from is Some(offset) &&
      offset > 0L {
      match output {
        FileOutput(mode=Truncate | Unique, ..) =>
          raise transfer_error(
            ProtocolFailure,
            "retaining a resumed prefix requires append output",
          )
        _ => ()
      }
    }
    if options.profile != WgetProfile &&
      skip_existing > 0L &&
      total is Some(expected) &&
      expected < skip_existing {
      raise transfer_error(
        ProtocolFailure,
        "response is shorter than the already written prefix",
      )
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
        ) if offset > 0L && !options.resume_skip_existing =>
          FileOutput(
            path~,
            mode=Truncate,
            content_disposition~,
            remove_on_error~,
          )
        _ => output
      }
    }
    let sink = TransferSink::new(effective_output, response, options.profile) catch {
      TransferError(..) as error =>
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
        if !sink.deferred_open {
          sink.start(observer, response_offset)
        }
        let mut skip_remaining = skip_existing
        for ;; {
          let timeout = timeout_for(
            options,
            started,
            options.idle_timeout_ms,
            "response body",
          )
          let read_result = @async.with_timeout_opt(timeout, () => {
            client.read_some(max_len=65536, profile=options.profile)
          }) catch {
            @io.ReaderClosed =>
              raise response_body_eof(response, request_method, count)
            TransferError(..) as error => raise error
            err =>
              raise transfer_error(
                ReceiveFailure,
                "response body read failed: \{err}",
              )
          }
          let chunk = match read_result {
            Some(Some(chunk)) => chunk
            Some(None) => break
            None => raise timeout_message("response body", timeout)
          }
          let skipped = skip_remaining.min(chunk.length().to_int64()).to_int()
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
        let completed_shorter_wget_response = options.profile == WgetProfile &&
          response.code == 200 &&
          total == Some(count)
        if skip_remaining > 0L && !completed_shorter_wget_response {
          raise transfer_error(
            PartialBodyFailure,
            "response ended before the already written prefix",
          )
        }
        sink.start(observer, response_offset)
        sink.flush()
        count
      } catch {
        TransferError(..) as transfer_failure => {
          sink.flush_after_failure()
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
          sink.flush_after_failure()
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
    return {
      requested_url,
      effective_url: parsed.to_url(),
      status: response.code,
      reason: response.reason,
      headers: visible_headers,
      received,
      output_path: sink.path(),
      redirects: redirect_count,
    }
  }
}
