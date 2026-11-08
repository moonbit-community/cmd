///|
test "wget cookie observer accepts the oracle default port and retains other ports" {
  assert_eq(
    wget_cookie_observations(
      [
        (
          "GET http://a.example.com/step/0 HTTP/1.1", "", "Host: a.example.com\r\n",
        ),
      ],
      ["a.example.com:80"],
      [0],
    ),
    [""],
  )
  for port in ["8123", "8124", "443"] {
    let host = "a.example.com:" + port
    assert_eq(
      wget_cookie_observations(
        [
          (
            "GET http://" + host + "/step/0 HTTP/1.1",
            "sid=v",
            "Host: " + host + "\r\n",
          ),
        ],
        [host],
        [0],
      ),
      ["sid=v"],
    )
    let omitted_port_accepted = try {
      wget_cookie_observations(
        [
          (
            "GET http://a.example.com/step/0 HTTP/1.1",
            "sid=v",
            "Host: " + host + "\r\n",
          ),
        ],
        [host],
        [0],
      )
      |> ignore
      true
    } catch {
      _ => false
    }
    assert_false(omitted_port_accepted)
  }
}
