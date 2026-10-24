///|
test "tagged and untagged checksum records select exact algorithms" {
  let md5 = "0bee89b07a248e27c83fc3d5951213c1"
  let standard : ManifestFormat = {
    reversed: -1,
    label: "MD5",
    sha2_tag: None,
  }
  let tagged = manifest_record(
    " MD5(payload)= " + md5,
    Some(Fixed(Md5)),
    false,
    standard,
  )
  assert_true(
    tagged
    is Some(
      { spec: { algorithm: Fixed(Md5), bits: 128, }, name: "payload", .. }
    ),
  )
  assert_eq(tagged.map(r => hex_digest(r.expected)), Some(md5))
  assert_true(manifest_record(md5 + "  payload", None, true, standard) is None)
  assert_true(
    manifest_record(
      "SHA1 (payload) = " + md5,
      Some(Fixed(Md5)),
      false,
      standard,
    )
    is None,
  )
  let auto : ManifestFormat = { reversed: -1, label: "CRC", sha2_tag: None, }
  let encoded = manifest_record(
    "MD5 (payload) = C+6JsHokjifIP8PVlRITwQ==",
    None,
    true,
    auto,
  )
  assert_eq(encoded.map(r => hex_digest(r.expected)), Some(md5))
  assert_true(
    manifest_record(
      "MD5 (payload) = C+6JsHokjifIP8PVlRITwQ==",
      Some(Fixed(Md5)),
      false,
      standard,
    )
    is None,
  )
  let reversed : ManifestFormat = {
    reversed: -1,
    label: "MD5",
    sha2_tag: None,
  }
  assert_true(
    manifest_record(md5 + " payload", Some(Fixed(Md5)), false, reversed)
    is Some({ name: "payload", .. }),
  )
  assert_true(
    manifest_record(md5 + "  payload", Some(Fixed(Md5)), false, reversed)
    is Some({ name: " payload", .. }),
  )
  let normal : ManifestFormat = { reversed: -1, label: "MD5", sha2_tag: None, }
  assert_true(
    manifest_record(md5 + "  payload", Some(Fixed(Md5)), false, normal)
    is Some(_),
  )
  assert_true(
    manifest_record(md5 + " payload", Some(Fixed(Md5)), false, normal) is None,
  )
  assert_true(
    manifest_record("\\MD5 (a\\\\b\\nc\\r)) = " + md5, None, true, auto)
    is Some({ name: "a\\b\nc\r)", .. }),
  )
  assert_true(
    manifest_record("SHA3-256 (payload) = " + "0".repeat(64), None, true, auto)
    is Some({ spec: { algorithm: Sha3, bits: 256, }, .. }),
  )
  assert_true(
    manifest_record("BLAKE2b-8 (payload) = 2e", None, true, auto)
    is Some({ spec: { algorithm: Blake2b, bits: 8, }, .. }),
  )
  assert_true(
    manifest_record("BLAKE2b-7 (payload) = 2e", None, true, auto) is None,
  )
  let sha2 : ManifestFormat = { reversed: -1, label: "SHA2", sha2_tag: None, }
  assert_true(
    manifest_record(
      "SHA256 (payload) = " + "0".repeat(64),
      Some(Sha2),
      true,
      sha2,
    )
    is Some({ spec: { algorithm: Fixed(Sha256), .. }, .. }),
  )
  assert_true(
    manifest_record(
      "SHA384 (payload) = " + "0".repeat(96),
      Some(Sha2),
      true,
      sha2,
    )
    is None,
  )
}

///|
test "modern checksum output supports tags base64 and escaped records" {
  let spec : DigestSpec = { algorithm: Fixed(Md5), bits: 128, }
  let bytes = @hex.decode("0bee89b07a248e27c83fc3d5951213c1")
  assert_eq(
    output_record(spec, bytes, 4UL, "payload", false, true, false, false, true),
    "MD5 (payload) = C+6JsHokjifIP8PVlRITwQ==\n",
  )
  assert_eq(
    output_record(spec, bytes, 4UL, "a\\b\n", false, true, false, false, false),
    "\\MD5 (a\\\\b\\n) = 0bee89b07a248e27c83fc3d5951213c1\n",
  )
  assert_eq(
    output_record(spec, bytes, 4UL, "a\\b\n", false, true, false, true, false),
    "MD5 (a\\b\n) = 0bee89b07a248e27c83fc3d5951213c1\u0000",
  )
  assert_eq(
    output_record(spec, bytes, 4UL, "payload", false, false, true, false, false),
    "0bee89b07a248e27c83fc3d5951213c1 *payload\n",
  )
}

///|
test "checksum verification uses GNU filename quoting" {
  for
    (name, expected) in [
      ("payload", "payload"),
      ("two words", "'two words'"),
      ("a\\b", "'a\\b'"),
      ("a'b", "\"a'b\""),
      ("a\nb", "'a'$'\\n''b'"),
      ("a\rb", "'a'$'\\r''b'"),
      ("a\tb", "'a'$'\\t''b'"),
      ("[a]", "'[a]'"),
    ] {
    assert_eq(quote_name(name), expected)
  }
}
