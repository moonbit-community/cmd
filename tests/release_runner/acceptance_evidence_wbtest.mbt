///|
test "freeze receipts accept original exact API responses and reject identity drift" {
  let checksum = @testkit.sha256_bytes(b"archive")
  let response : Json = {
    "module": "cli/true",
    "version": "0.2.0",
    "yanked": false,
    "metadata": {
      "name": "cli/true",
      "version": "0.2.0",
      "checksum": Json(checksum),
    },
  }
  assert_eq(
    registry_response_checksum(response.stringify(), "cli/true", "0.2.0"),
    Some(checksum),
  )
  assert_eq(
    registry_response_checksum(response.stringify(), "cli/false", "0.2.0"),
    None,
  )
  assert_eq(
    registry_response_checksum(response.stringify(), "cli/true", "0.2.1"),
    None,
  )
  let yanked : Json = {
    "module": "cli/true",
    "version": "0.2.0",
    "yanked": true,
    "metadata": {
      "name": "cli/true",
      "version": "0.2.0",
      "checksum": Json(checksum),
    },
  }
  assert_eq(
    registry_response_checksum(yanked.stringify(), "cli/true", "0.2.0"),
    None,
  )
  let mismatched_metadata : Json = {
    "module": "cli/true",
    "version": "0.2.0",
    "yanked": false,
    "metadata": {
      "name": "cli/false",
      "version": "0.2.0",
      "checksum": Json(checksum),
    },
  }
  assert_eq(
    registry_response_checksum(
      mismatched_metadata.stringify(),
      "cli/true",
      "0.2.0",
    ),
    None,
  )
}

///|
async test "official archive redirects preserve exact coordinates and stop after one hop" {
  let initial = "https://download.mooncakes.io/user/cli/sh/0.2.0.zip"
  let destination = "https://d15l9c1mnzh3r.cloudfront.net/user/cli/sh/0.2.0.zip"
  let visited : Array[String] = []
  let (status, body) = fetch_official_registry_with(initial, url => {
    visited.push(url)
    if url == initial {
      (302, Some(destination), b"redirect")
    } else {
      (200, None, b"verified-by-caller")
    }
  })
  assert_eq(status, 200)
  assert_eq(body, b"verified-by-caller")
  assert_eq(visited, [initial, destination])
  for
    changed in [
      "http://d15l9c1mnzh3r.cloudfront.net/user/cli/sh/0.2.0.zip", "https://elsewhere.example/user/cli/sh/0.2.0.zip",
      "https://d15l9c1mnzh3r.cloudfront.net/user/cli/sh/0.2.1.zip", "https://d15l9c1mnzh3r.cloudfront.net/user/cli/true/0.2.0.zip",
      "https://d15l9c1mnzh3r.cloudfront.net/user/cli/sh/0.2.0.zip?token=x", "https://user@d15l9c1mnzh3r.cloudfront.net/user/cli/sh/0.2.0.zip",
      "//d15l9c1mnzh3r.cloudfront.net/user/cli/sh/0.2.0.zip", "/user/cli/sh/0.2.0.zip",
    ] {
    let rejected = try {
      ignore(official_archive_redirect(initial, changed))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let second_redirect_rejected = try {
    ignore(
      fetch_official_registry_with(initial, _ => {
        (302, Some(destination), b"redirect")
      }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(second_redirect_rejected)
  let manifest = "https://mooncakes.io/api/v0/manifest/cli/sh@0.2.0"
  let manifest_requests : Array[String] = []
  let (manifest_status, _) = fetch_official_registry_with(manifest, url => {
    manifest_requests.push(url)
    (302, Some(destination), b"redirect")
  })
  assert_eq(manifest_status, 302)
  assert_eq(manifest_requests, [manifest])
}
