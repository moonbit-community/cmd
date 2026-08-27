///|
pub(all) suberror NetOpError {
  NetOpError(String)
}

///|
pub async fn fetch(
  url : String,
  output_path : String?,
  fail_on_http_error : Bool,
) -> Unit {
  let (response, body) = @http.get_stream(url)
  defer body.close()
  if fail_on_http_error && response.code >= 400 {
    raise NetOpError("server returned HTTP status \{response.code}")
  }
  match output_path {
    None => @stdio.stdout.write_reader(body)
    Some(path) => {
      let output = @fs.open(path, mode=WriteOnly, create_mode=CreateOrTruncate)
      defer output.close()
      output.write_reader(body)
    }
  }
}
