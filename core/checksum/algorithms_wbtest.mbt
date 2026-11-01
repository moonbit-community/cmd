///|
async test "POSIX CRC-32 vectors include the input length" {
  let spec : DigestSpec = { algorithm: Crc, bits: 32, }
  for
    (input, checksum, length) in [
      (b"", 0xFFFFFFFFU, 0UL),
      (b"hello\n", 3015617425U, 6UL),
      (b"123456789", 930766865U, 9UL),
    ] {
    let reader = @io.MemoryReader(writer => writer.write(input))
    defer reader.close()
    let (digest, actual_length) = digest_reader(spec, reader)
    assert_eq(
      digest,
      Bytes::makei(4, i => (checksum >> ((3 - i) * 8)).to_byte()),
    )
    assert_eq(actual_length, length)
  }
}

///|
test "length bytes are folded from low to high order" {
  assert_eq(crc_length(0U, 0UL), 0xFFFFFFFFU)
  assert_eq(crc_length(0U, 1UL), 4215202376U)
}

///|
test "modern digest vectors include all SHA2 and SHA3 widths" {
  let vectors : Array[(Digest, Int32, String)] = [
    (Fixed(Md5), 128, "0bee89b07a248e27c83fc3d5951213c1"),
    (Fixed(Sha1), 160, "03cfd743661f07975fa2f1220c5194cbaff48451"),
    (
      Blake2b,
      512,
      "426526ad3aa99ac6bbb98555c6c30b5a55189d0d7537d9214053b886f365a84bd7e68c91b544a8f485fa842c0ea9fbc4fb92277290264e685eed9e67b7621fc9",
    ),
    (
      Sm3,
      256,
      "12d4e804e1fcfdc181ed383aa07ba76cc69d8aedcbb7742d6e28ff4fb7776c34",
    ),
    (
      Fixed(Sha256),
      256,
      "edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb",
    ),
    (Sha2, 224, "f5c93b6f06f7c56d7ea720c121e3b1fb6730e5cf5f18d776bf0f2d88"),
    (
      Sha2,
      256,
      "edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb",
    ),
    (
      Sha2,
      384,
      "e8d1420b4ff41c3f12186d894a99e1c4aa681da79c47007e9dadecd9ecb0482ee1e224510e7484078c0289f34396b9c3",
    ),
    (
      Sha2,
      512,
      "4f285d0c0cc77286d8731798b7aae2639e28270d4166f40d769cbbdca5230714d848483d364e2f39fe6cb9083c15229b39a33615ebc6d57605f7c43f6906739d",
    ),
    (Sha3, 224, "631e999b94a9ddcc67f343be0bcead5f050fa0ddafc259fef71154b9"),
    (
      Sha3,
      256,
      "855e77bb9d8fc068ca812a39d07bad50dc012d7f07c346d7e56a4f25075e4070",
    ),
    (
      Sha3,
      384,
      "b727220940c0621e022627c1ff2f577b152f9873fbf33a4de9e5b8110d5bac847ec6cbbe6c54c523e8b9f33629f7aa04",
    ),
    (
      Sha3,
      512,
      "cf37ee58662b428b08d9c11cacad49cd9b3aceec7478ba352d8609d29af0c60a60f453048478ba1d9a1cf1bc17ee1ab000a479adebc35ba9654d8ccca5b39a8b",
    ),
    (Blake2b, 8, "c5"),
    (Blake2b, 128, "63a03738a73b8a2228e0765bd1777429"),
    (
      Blake2b,
      256,
      "6e25640baa7f9d4186663d80e7d62a82d4851651322ab4e68147533260c13d03",
    ),
  ]
  for (algorithm, bits, expected) in vectors {
    let state = make_hasher({ algorithm, bits, })
    (state.update)(b"ab")
    (state.update)(b"c\n")
    assert_eq(@hex.encode((state.finish)()), expected)
  }
  for length in [0, 111, 112, 127, 128, 129, 65537] {
    let input = Bytes::make(length, b'\x00')
    let expected = @crypto.bytes_to_hex_string(@crypto.sha384(input))
    for size in [1, 127, 65536] {
      let state = make_hasher({ algorithm: Sha384, bits: 384, })
      let mut offset = 0
      while offset < length {
        let end = (offset + size).min(length)
        (state.update)(input[offset:end].to_owned())
        offset = end
      }
      assert_eq(@hex.encode((state.finish)()), expected)
    }
  }
}

///|
test "BLAKE2b incremental state preserves final blocks and output lengths" {
  let vectors : Array[(Int32, Int32, String)] = [
    (0, 8, "2e"),
    (0, 256, "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8"),
    (
      0, 512, "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce",
    ),
    (1, 8, "a1"),
    (1, 256, "03170a2e7597b7b7e3d84c05391d139a62b157e78786d8c082f29dcf4c111314"),
    (
      1, 512, "2fa3f686df876995167e7c2e5d74c4c7b6e48f8068fe0e44208344d480f7904c36963e44115fe3eb2a3ac8694c28bcb4f5a0f3276f2e79487d8219057a506e4b",
    ),
    (127, 8, "6f"),
    (
      127, 256, "0f2dfeb03485c703d0c8584a40d135192ecb150247e9377595ed718d84b08a85",
    ),
    (
      127, 512, "93cac6a4bedd751e1c145f8e76fec88fec246675898475585603bd228f883bcf4ebcc68ead8fa5f27890a243fa938bd7323ad41f9f06048a732cce2070b212c3",
    ),
    (128, 8, "8a"),
    (
      128, 256, "378d0caaaa3855f1b38693c1d6ef004fd118691c95c959d4efa950d6d6fcf7c1",
    ),
    (
      128, 512, "865939e120e6805438478841afb739ae4250cf372653078a065cdcfffca4caf798e6d462b65d658fc165782640eded70963449ae1500fb0f24981d7727e22c41",
    ),
    (129, 8, "4c"),
    (
      129, 256, "baadfb64c3bd2cd187b54accc5e61a0720ed86bf48c28017873536cf9015d1b8",
    ),
    (
      129, 512, "a60edba343e7a6933c14d203d2e535f35e6deb6c8a4f8e624c1a6f6e2612860447cb4c37e5aa11bcf03b7c3eea7228eb8b998f922794f2d1b8f2dc63f03bd3fa",
    ),
    (255, 8, "e5"),
    (
      255, 256, "edaf681c3a829eebe20154d8f2321afe5c491ffbfa28747ad92d4cb72f74025c",
    ),
    (
      255, 512, "fe76e0267f83e08cf023d78f8bdd7a1e7730282e54a64f9bec91ba1ea294441bd046a28fcbaa3bab9300838f04274994aa5dd2bc573c6478eee24584faff3dc7",
    ),
    (256, 8, "6e"),
    (
      256, 256, "2b69702a889248a4d6620475a105dccd5e0d4230aca8a492aaf6510e55d55b02",
    ),
    (
      256, 512, "ec9c6b301a6c98946d742a74710e658f0243e0e6d3525f4afa94dfc2395456fa54ebe5ef0f413b5a9abfe6501dabb4b9a0fbca164d6cd80b1e79dbbed8d4202e",
    ),
    (257, 8, "54"),
    (
      257, 256, "a93d82fe42c85b6eb1dab95d264706993f6bd903aee5a3ca4a01adbe807c4ca3",
    ),
    (
      257, 512, "3e525f99065ae9f9c5568a258a0ec35d783813824520d975f774059aaea895343350b1bc01e537ea95cf369412039c84b05f22a9aaa57fb442ab660ccd45f125",
    ),
    (65535, 8, "e2"),
    (
      65535, 256, "223a24a933c52b5e40718d87ba3d659f8ca31781c3eb7170218680ba8dc928d8",
    ),
    (
      65535, 512, "40e72de96275dd3a79fd27cdf4e8e4b0ec2faaba878eb572a45347090be75bf2fa5708a6af0fa410d694680fe920016d45301e3e558cd68ff668707681800583",
    ),
    (65536, 8, "f1"),
    (
      65536, 256, "df2d0b4e193fce63759c790e6956d5f756861f15d6db64cc1899afa85e1627b9",
    ),
    (
      65536, 512, "224bf59a700688baa36d6ae418d9314d880adeb791ab854ebb697bc853d6f4c2faf9797b9902103ff8aa7b92b7340ec995e64259dcdb2be7ab45d93d04b14cd5",
    ),
    (65537, 8, "0b"),
    (
      65537, 256, "a16f64213781b84f138b13b3778a4b94e9776135137e6cd942f6073636005f36",
    ),
    (
      65537, 512, "c9a1fda5638e9960dd724338f5bf2f464974ab38bdb0f393a66654310a683508089a31339d617b140ffccd74cde7b06cfba91e5897f7277b4346bc29d497571d",
    ),
  ]
  for (length, bits, expected) in vectors {
    let bytes = Bytes::make(length, b'\x00')
    for size in [1, 7, 128, 65536] {
      let state = Blake2bState::new(bits / 8)
      let mut offset = 0
      while offset < length {
        let end = (offset + size).min(length)
        state.update(bytes[offset:end])
        offset = end
      }
      assert_eq(@hex.encode(state.finalize()), expected)
    }
  }
}
