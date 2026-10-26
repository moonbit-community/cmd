///|
/// A reader over `data` that returns chunks whose sizes cycle through
/// `sizes`, to exercise sequences split across chunk boundaries.
struct ChunkReader {
  data : Bytes
  sizes : Array[Int32]
  mut pos : Int32
  mut turn : Int32
}

///|
fn ChunkReader::new(data : Bytes, sizes : Array[Int32]) -> ChunkReader {
  { data, sizes, pos: 0, turn: 0, }
}

///|
impl Reader for ChunkReader with fn read(self, buf, start, len) {
  let size = self.sizes[self.turn % self.sizes.length()]
  self.turn += 1
  let mut n = self.data.length() - self.pos
  if n > len {
    n = len
  }
  if n > size {
    n = size
  }
  for i in 0..<n {
    buf[start + i] = self.data[self.pos + i]
  }
  self.pos += n
  n
}

///|
/// Decodes `data` with the encoding named by `label` (without BOM
/// sniffing), reading the input in chunks of the given sizes.
async fn decode_chunked(
  label : String,
  data : Bytes,
  sizes : Array[Int32],
  bom_sniffing~ : Bool = false,
) -> Bytes {
  let enc = Encoding::new(label)
  let rdr = DecodeReader::new(
    ChunkReader::new(data, sizes),
    Some(enc.kind),
    bom_sniffing,
  )
  let out = Buffer()
  let buf = FixedArray::make(1000, b'\x00')
  for ;; {
    let n = Reader::read(rdr, buf, 0, buf.length())
    if n == 0 {
      break
    }
    for i in 0..<n {
      out.write_byte(buf[i])
    }
  }
  out.to_bytes()
}

///|
/// Decodes `data` with the decoder for `label` directly (like encoding_rs's
/// `decode_to_utf8` on consecutive chunks, the last one flagged as last),
/// feeding it chunks of the given sizes.
fn decode_direct(
  label : String,
  data : Bytes,
  sizes : Array[Int32],
) -> Bytes raise {
  let dec = LegacyDecoder::new(Encoding::new(label).kind)
  let raw = data.to_fixedarray()
  let out = Buffer()
  let mut pos = 0
  let mut turn = 0
  while pos < raw.length() {
    let size = sizes[turn % sizes.length()]
    turn += 1
    let end = if pos + size < raw.length() { pos + size } else { raw.length() }
    dec.feed(raw, pos, end, out)
    pos = end
  }
  dec.finish(out)
  out.to_bytes()
}

///|
/// Decodes `data` both in one go and one byte at a time, checks that the
/// results agree, and returns the decoded string.
fn decode_str(label : String, data : Bytes) -> String raise {
  let whole = decode_direct(label, data, [1 << 20])
  let bytewise = decode_direct(label, data, [1])
  assert_eq(whole, bytewise)
  @utf8.decode(whole)
}

///|
fn hex_bytes(s : String) -> Bytes {
  let out = Buffer()
  for part in s.split(" ") {
    if part.length() == 0 {
      continue
    }
    let mut v = 0
    for c in part {
      let d = match c {
        '0'..<='9' => c.to_int() - '0'.to_int()
        'A'..<='F' => c.to_int() - 'A'.to_int() + 10
        'a'..<='f' => c.to_int() - 'a'.to_int() + 10
        _ => abort("bad hex")
      }
      v = v * 16 + d
    }
    out.write_byte(v.to_byte())
  }
  out.to_bytes()
}

///|
fn label_name(label : String) -> String {
  Encoding::new(label).name() catch {
    e => "error: \{e}"
  }
}

///|
test "encoding labels" {
  inspect(label_name("utf-8"), content="UTF-8")
  inspect(label_name("UTF8"), content="UTF-8")
  inspect(label_name("sjis"), content="Shift_JIS")
  inspect(label_name("ms_kanji"), content="Shift_JIS")
  inspect(label_name("windows-31j"), content="Shift_JIS")
  inspect(label_name("euc-jp"), content="EUC-JP")
  inspect(label_name("x-euc-jp"), content="EUC-JP")
  inspect(label_name("csiso2022jp"), content="ISO-2022-JP")
  inspect(label_name("euc-kr"), content="EUC-KR")
  inspect(label_name("windows-949"), content="EUC-KR")
  inspect(label_name("gb2312"), content="GBK")
  inspect(label_name("x-gbk"), content="GBK")
  inspect(label_name("gb18030"), content="gb18030")
  inspect(label_name("big5-hkscs"), content="Big5")
  inspect(label_name("cn-big5"), content="Big5")
  inspect(label_name("latin1"), content="windows-1252")
  inspect(label_name("ascii"), content="windows-1252")
  inspect(label_name("iso-8859-1"), content="windows-1252")
  inspect(label_name("latin2"), content="ISO-8859-2")
  inspect(label_name("iso-ir-138"), content="ISO-8859-8")
  inspect(label_name("logical"), content="ISO-8859-8-I")
  inspect(label_name("iso-8859-8-i"), content="ISO-8859-8-I")
  inspect(label_name("iso-8859-16"), content="ISO-8859-16")
  inspect(label_name("koi"), content="KOI8-R")
  inspect(label_name("koi8-ru"), content="KOI8-U")
  inspect(label_name("mac"), content="macintosh")
  inspect(label_name("x-mac-ukrainian"), content="x-mac-cyrillic")
  inspect(label_name("tis-620"), content="windows-874")
  inspect(label_name("cp1250"), content="windows-1250")
  inspect(label_name("latin5"), content="windows-1254")
  inspect(label_name("x-cp1258"), content="windows-1258")
  inspect(label_name("866"), content="IBM866")
  inspect(label_name("utf-16"), content="UTF-16LE")
  inspect(label_name("ucs-2"), content="UTF-16LE")
  inspect(label_name("utf-16be"), content="UTF-16BE")
  inspect(label_name("unicodefffe"), content="UTF-16BE")
  inspect(label_name("x-user-defined"), content="x-user-defined")
}

///|
test "encoding labels: case and whitespace" {
  inspect(label_name("  Shift_JIS\t"), content="Shift_JIS")
  inspect(label_name("\n\r\u{0C} EUC-JP \n"), content="EUC-JP")
  inspect(label_name("ISO-2022-jp"), content="ISO-2022-JP")
  inspect(label_name("X-USER-DEFINED"), content="x-user-defined")
}

///|
test "encoding labels: replacement and unknown labels are rejected" {
  for
    label in [
      "csiso2022kr", "hz-gb-2312", "iso-2022-cn", "iso-2022-cn-ext", "iso-2022-kr",
      "replacement", "foo", "utf-32", "shift-jis2", "UTF-7", "",
      // Only ASCII whitespace is trimmed, and only at the ends.
       "\u{A0}sjis", "\u{0B}sjis", "s jis", "sjis\u{3000}",
      // Only ASCII letters are case-folded (U+212A KELVIN SIGN lowercases to k).
       "\u{212A}oi8-r",
    ] {
    let msg = Encoding::new(label).name() catch {
      ConfigError(msg) => msg
      e => "\{e}"
    }
    assert_eq(msg, "grep config error: unknown encoding: \{label}")
  }
}

///|
test "decode Shift_JIS" {
  inspect(
    decode_str(
      "sjis", b"\x84Y\x84u\x84\x82\x84|\x84\x80\x84{ \x84V\x84\x80\x84|\x84}\x84\x83",
    ),
    content="Шерлок Холмс",
  )
  // Expected outputs below are from encoding_rs 0.8.35.
  assert_eq(
    decode_str("Shift_JIS", hex_bytes("82 A0 81 20 A0 80 F0 40 81 FF FD B1 81")),
    "\u{3042}\u{FFFD} \u{FFFD}\u{80}\u{E000}\u{FFFD}\u{FFFD}\u{FF71}\u{FFFD}",
  )
}

///|
test "decode EUC-JP" {
  inspect(
    decode_str(
      "euc-jp", b"\xa7\xba\xa7\xd6\xa7\xe2\xa7\xdd\xa7\xe0\xa7\xdc \xa7\xb7\xa7\xe0\xa7\xdd\xa7\xde\xa7\xe3",
    ),
    content="Шерлок Холмс",
  )
  assert_eq(
    decode_str(
      "EUC-JP",
      hex_bytes("A4 A2 8E A6 8F B0 A1 A4 41 8E E0 8F A1 41 FF 8F A1"),
    ),
    "\u{3042}\u{FF66}\u{4E02}\u{FFFD}A\u{FFFD}\u{FFFD}A\u{FFFD}\u{FFFD}",
  )
}

///|
test "decode EUC-KR" {
  assert_eq(
    decode_str("EUC-KR", hex_bytes("B0 A1 81 41 B0 20 FF 80 C9 A1 B0")),
    "\u{AC00}\u{AC02}\u{FFFD} \u{FFFD}\u{FFFD}\u{FFFD}\u{FFFD}",
  )
}

///|
test "decode Big5" {
  assert_eq(
    decode_str(
      "Big5",
      hex_bytes("A4 A4 88 62 88 64 87 40 A4 20 80 FF 87 45 A4"),
    ),
    "\u{4E2D}\u{CA}\u{304}\u{CA}\u{30C}\u{43F0}\u{FFFD} \u{FFFD}\u{FFFD}\u{27267}\u{FFFD}",
  )
}

///|
test "decode gb18030 and GBK" {
  let input = hex_bytes(
    "D6 D0 80 81 30 81 30 84 31 A4 39 90 30 81 30 E3 32 9A 35 E3 32 9A 36 81 35 F4 37 84 31 A5 30 81 30 20 81 30 81 20 A1 A1 FF 81 30 81",
  )
  let expected = "\u{4E2D}\u{20AC}\u{80}\u{FFFF}\u{10000}\u{10FFFF}\u{FFFD}\u{E7C7}\u{FFFD}\u{FFFD}0 \u{FFFD}0\u{FFFD} \u{3000}\u{FFFD}\u{FFFD}"
  assert_eq(decode_str("gb18030", input), expected)
  // The GBK decoder is the gb18030 decoder.
  assert_eq(decode_str("GBK", input), expected)
  assert_eq(
    decode_str("gbk", hex_bytes("D6 D0 80 A3 A0 FE 51")),
    "\u{4E2D}\u{20AC}\u{3000}\u{E816}",
  )
}

///|
test "decode ISO-2022-JP" {
  assert_eq(
    decode_str(
      "ISO-2022-JP",
      hex_bytes(
        "41 1B 24 42 3B 33 1B 28 42 42 1B 28 49 21 5F 1B 28 4A 5C 7E 1B 28 42 5C 7E",
      ),
    ),
    "A\u{5C71}B\u{FF61}\u{FF9F}\u{A5}\u{203E}\\~",
  )
  assert_eq(
    decode_str(
      "ISO-2022-JP",
      hex_bytes(
        "1B 24 42 1B 28 42 41 1B 41 1B 24 41 0E 1B 24 42 30 1B 28 42 41 80",
      ),
    ),
    "\u{FFFD}A\u{FFFD}A\u{FFFD}$A\u{FFFD}\u{FFFD}A\u{FFFD}",
  )
  assert_eq(decode_str("ISO-2022-JP", hex_bytes("1B 24 42 30")), "\u{FFFD}")
  assert_eq(decode_str("ISO-2022-JP", hex_bytes("1B")), "\u{FFFD}")
  assert_eq(decode_str("ISO-2022-JP", hex_bytes("1B 24")), "\u{FFFD}$")
  assert_eq(
    decode_str("ISO-2022-JP", hex_bytes("1B 28 49 60 41")),
    "\u{FFFD}\u{FF81}",
  )
}

///|
test "decode single-byte encodings and x-user-defined" {
  assert_eq(
    decode_str("x-user-defined", hex_bytes("41 80 FF")),
    "A\u{F780}\u{F7FF}",
  )
  assert_eq(
    decode_str("windows-1252", hex_bytes("80 81 9F A0 FF")),
    "\u{20AC}\u{81}\u{178}\u{A0}\u{FF}",
  )
  assert_eq(decode_str("koi8-r", hex_bytes("E1 C2 D7")), "Абв")
  assert_eq(decode_str("ISO-8859-3", hex_bytes("A5 A6")), "\u{FFFD}\u{124}")
  assert_eq(decode_str("windows-874", hex_bytes("DB A1")), "\u{FFFD}\u{E01}")
  assert_eq(decode_str("ISO-8859-8-I", hex_bytes("E0 FB")), "\u{5D0}\u{FFFD}")
  assert_eq(decode_str("macintosh", hex_bytes("80 A5")), "\u{C4}\u{2022}")
}

///|
test "decode UTF-16" {
  assert_eq(
    decode_str("UTF-16LE", hex_bytes("41 00 3D D8 00 DE 00 D8 41 00 00 DC 42")),
    "A\u{1F600}\u{FFFD}A\u{FFFD}\u{FFFD}",
  )
  assert_eq(
    decode_str("UTF-16BE", hex_bytes("00 41 D8 3D DE 00 D8 00")),
    "A\u{1F600}\u{FFFD}",
  )
}

///|
async test "decode: a UTF-16 BOM overrides the configured encoding" {
  // Like encoding_rs_io with UTF-8 passthrough (as ripgrep configures it),
  // a UTF-8 BOM is stripped but keeps the configured decoder.
  let utf8 = decode_chunked(
    "sjis",
    b"\xEF\xBB\xBF\x84Y",
    [1],
    bom_sniffing=true,
  )
  assert_eq(@utf8.decode(utf8), "Ш")
  let utf16 = decode_chunked(
    "euc-jp",
    b"\xFF\xFEA\x00",
    [1 << 20],
    bom_sniffing=true,
  )
  assert_eq(utf16, b"A")
  let sjis = decode_chunked("sjis", b"\x84Y", [1], bom_sniffing=true)
  assert_eq(@utf8.decode(sjis), "Ш")
}

///|
async test "search Shift_JIS and EUC-JP" {
  let cases : Array[(String, Bytes)] = [
    (
      "sjis", b"\x84Y\x84u\x84\x82\x84|\x84\x80\x84{ \x84V\x84\x80\x84|\x84}\x84\x83\n",
    ),
    (
      "euc-jp", b"\xa7\xba\xa7\xd6\xa7\xe2\xa7\xdd\xa7\xe0\xa7\xdc \xa7\xb7\xa7\xe0\xa7\xdd\xa7\xde\xa7\xe3\n",
    ),
  ]
  for case in cases {
    let (label, haystack) = case
    let matcher = TestMatcher::new("Шерлок Холмс")
    let sink = KitchenSink::new()
    let searcher = SearcherBuilder::new()
      .encoding(Some(Encoding::new(label)))
      .build()
    searcher.search_reader(matcher, SliceReader::from_bytes(haystack), sink)
    assert_eq(
      sink.as_string(),
      "1:0:Шерлок Холмс\n\nbyte count:24\n",
    )
    let sink = KitchenSink::new()
    let buf = haystack.to_fixedarray()
    searcher.search_slice(matcher, buf, buf.length(), sink)
    assert_eq(
      sink.as_string(),
      "1:0:Шерлок Холмс\n\nbyte count:24\n",
    )
  }
}

///|
fn fnv1a(data : Bytes) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
/// The corpora must match those of scripts/encoding_rs_ref.rs.
fn corpus_pairs() -> Bytes {
  let out = Buffer()
  for a in 0..<256 {
    for b in 0..<256 {
      out.write_byte(a.to_byte())
      out.write_byte(b.to_byte())
      out.write_byte(b'A')
    }
  }
  out.to_bytes()
}

///|
fn corpus_gb4() -> Bytes {
  let out = Buffer()
  for b1 in [0x81, 0x82, 0x84, 0x85, 0x8F, 0x90, 0x91, 0xE3, 0xE4, 0xFD, 0xFE] {
    for b2 in 0x30..<=0x39 {
      for b3 in 0x81..<=0xFE {
        for b4 in 0x2F..<=0x3A {
          out.write_byte(b1.to_byte())
          out.write_byte(b2.to_byte())
          out.write_byte(b3.to_byte())
          out.write_byte(b4.to_byte())
        }
      }
    }
  }
  out.to_bytes()
}

///|
fn lcg_next(x : UInt64) -> UInt64 {
  x * 6364136223846793005UL + 1442695040888963407UL
}

///|
fn corpus_random(n : Int32) -> Bytes {
  let special : Array[Byte] = [
    0x1B, 0x24, 0x28, 0x42, 0x40, 0x4A, 0x49, 0x0E, 0x0F, 0x5C, 0x7E, 0x8E, 0x8F,
    0x80, 0x30, 0x39,
  ]
  let out = Buffer()
  let mut x = 0x9E3779B97F4A7C15UL
  for _ in 0..<n {
    x = lcg_next(x)
    let sel = (x >> 56).to_int()
    let r = ((x >> 40) & 0xFFFFUL).to_int()
    let b = if sel < 96 {
      r & 0xFF
    } else if sel < 150 {
      r % 0x80
    } else if sel < 190 {
      special[r % 16].to_int()
    } else {
      0x80 + r % 0x80
    }
    out.write_byte(b.to_byte())
  }
  out.to_bytes()
}

///|
fn corpus_iso(n : Int32) -> Bytes {
  let escapes : Array[Bytes] = [
    b"\x1B(B", b"\x1B(J", b"\x1B(I", b"\x1B$@", b"\x1B$B", b"\x1B", b"\x1B$", b"\x1B(",
    b"\x1B$A",
  ]
  let out = Buffer()
  let mut x = 0x2545F4914F6CDD1DUL
  for _ in 0..<n {
    x = lcg_next(x)
    let sel = (x >> 56).to_int()
    let r = ((x >> 40) & 0xFFFFUL).to_int()
    if sel < 30 {
      out.write_bytes(escapes[r % 5])
    } else if sel < 40 {
      out.write_bytes(escapes[5 + r % 4])
    } else if sel < 230 {
      out.write_byte((0x21 + r % 0x5E).to_byte())
    } else {
      out.write_byte((r & 0xFF).to_byte())
    }
  }
  out.to_bytes()
}

///|
/// FNV-1a hashes of encoding_rs 0.8.35's output (`decode_to_utf8` without BOM
/// handling) for the corpora pairs, gb4, random(200000), random(20000) and
/// iso(100000), as printed by `encoding_rs_ref hashes` (scripts/encoding_rs_ref.rs).
let encoding_rs_hashes : Array[(String, UInt64, UInt64, UInt64, UInt64, UInt64)] = [
  (
    "IBM866", 0xBACE9A8B944FE4E1UL, 0xF2EE3E0E2AA79FB5UL, 0x7F5794282A23D664UL, 0xC06D98DB73A5A689UL,
    0x78AD20B4D2AB6305UL,
  ),
  (
    "ISO-8859-2", 0x57A2F2917DBB04A5UL, 0x7F29BB6007C6A245UL, 0x6CEAC50196DB1943UL,
    0x447C8A4CEE43D5C7UL, 0x9062DBB3C589BFFCUL,
  ),
  (
    "ISO-8859-3", 0x93D0841AAFB8D533UL, 0xC8485F5029069411UL, 0x13B0EDFCC21696ABUL,
    0x1BA60E024555E153UL, 0xB31E5C9F94A92CB4UL,
  ),
  (
    "ISO-8859-4", 0xFB3A97EEFEF601E5UL, 0xAE012EC49014F4B5UL, 0x9E4D877073E98D8EUL,
    0x8D162370CD4B3534UL, 0x7A8170EA11C1D86EUL,
  ),
  (
    "ISO-8859-5", 0xABA7282D621C8EF3UL, 0x5F4848A12BBC4EE9UL, 0x17EF74EAC4E0BF2CUL,
    0x0E36A94E24891979UL, 0x276A3F691B893956UL,
  ),
  (
    "ISO-8859-6", 0xAFA807F2DF2333D9UL, 0x221C56C06D22FED5UL, 0x9DF8F1915A977FBEUL,
    0x724110402C30162CUL, 0x45DA48B13FD85113UL,
  ),
  (
    "ISO-8859-7", 0xD4ED860C2594E0E9UL, 0x9EF2B2E7B52F99B1UL, 0x4547FCA857CEFFF1UL,
    0xFB293FD59A5AB6AFUL, 0xFF36DC55C2797CBBUL,
  ),
  (
    "ISO-8859-8", 0x46674703D54180B5UL, 0xFC2B2E8E074FA2E5UL, 0x0EB2BEA5423642D0UL,
    0xC755EB6F11B24D09UL, 0xCA758DD8C366AE8CUL,
  ),
  (
    "ISO-8859-8-I", 0x46674703D54180B5UL, 0xFC2B2E8E074FA2E5UL, 0x0EB2BEA5423642D0UL,
    0xC755EB6F11B24D09UL, 0xCA758DD8C366AE8CUL,
  ),
  (
    "ISO-8859-10", 0xD9725E476E6B5255UL, 0x642BE55C86E52A51UL, 0x1F1ED95D4E51FFE2UL,
    0xB5F1C37A0E4CC044UL, 0xC6B2696A69ED4E99UL,
  ),
  (
    "ISO-8859-13", 0xC6F0C10750893C49UL, 0x521A6BE2AB4E8AE9UL, 0x27FA1DC842C4E1B3UL,
    0x6EB3107FA42E3D53UL, 0xA066291D73EC5E29UL,
  ),
  (
    "ISO-8859-14", 0x31FE66A1BD817E1DUL, 0xB873793EB5671B2DUL, 0x98F3CC8615E9D299UL,
    0x0AAC62C5BEC6B7B6UL, 0xAEA1008C6D96E29EUL,
  ),
  (
    "ISO-8859-15", 0x66B59689C3D64C83UL, 0xFB9ECBC3D2236EB9UL, 0x36300D41E07AC42CUL,
    0xD52F2662A6213C7EUL, 0xB96F00DFAC26D0F0UL,
  ),
  (
    "ISO-8859-16", 0x917A1F76C3E4B593UL, 0x88E1A315406558E9UL, 0xFA2479CA63D16836UL,
    0xE4B86732BE3DCDE1UL, 0xF574D851BE299DDBUL,
  ),
  (
    "KOI8-R", 0xB62A1CFAFA509E4DUL, 0x945FE13456434141UL, 0x841428364A5D59E0UL, 0x17F30F2AFFA94157UL,
    0x697341768663BBA1UL,
  ),
  (
    "KOI8-U", 0xCD2A4B7861BB95C1UL, 0x68DA05576E07BB61UL, 0x5749D244D51481CBUL, 0x6C80334C0DD94DA2UL,
    0x0EF853D9BEAD6F7DUL,
  ),
  (
    "macintosh", 0x7804E994EF77E829UL, 0xBE2BC45CB8CF7AE9UL, 0x7CE746EA6710A7A7UL,
    0x4D7DE2C200D7C58BUL, 0xCCD557AECEC62546UL,
  ),
  (
    "windows-874", 0x89CC60B4B8074681UL, 0x83321E26ACA723BDUL, 0x94C6E71F5C9ED953UL,
    0x047171B0DE4E041FUL, 0x8EB19061AD5301A8UL,
  ),
  (
    "windows-1250", 0x955D9E2EA88B7FA5UL, 0x9339E769A48D1AB5UL, 0x0D4E3291983FD75BUL,
    0xE14F497FC65C7A70UL, 0xB1EB8FBBAE9CB9C4UL,
  ),
  (
    "windows-1251", 0x1906B707E21E5FB9UL, 0xB14DF6A6DED9AE4DUL, 0xA290B3E1392A255DUL,
    0x2B6E7605F87D5FD8UL, 0x4CB977D7D32D8140UL,
  ),
  (
    "windows-1252", 0xA427C9654B51D7F3UL, 0xD74BF5CE9BA01385UL, 0x76995AC69CC4A7A8UL,
    0x99CF292BFA715391UL, 0x222B4B9B45BB33BAUL,
  ),
  (
    "windows-1253", 0x0517074A639A6189UL, 0x64E6BAF887A62AE1UL, 0x46CEDB9E21320C8CUL,
    0x70D517F08F54C488UL, 0xC9323BC6E9F335A0UL,
  ),
  (
    "windows-1254", 0x79C480C0FECDE4F5UL, 0xE68C22EFD1CB7765UL, 0x6A9A4A968EA5D47AUL,
    0xE38A1215528034E3UL, 0xE13FAB0C5FFE3CB7UL,
  ),
  (
    "windows-1255", 0xAF13B9102F6AED71UL, 0xC41C237C1616978DUL, 0xCE8F036407286628UL,
    0xFA7408EF9E1723C1UL, 0xA4063E4D9703E077UL,
  ),
  (
    "windows-1256", 0x293EBCF4E2303605UL, 0xFE698F3025BC3D25UL, 0x03C1CD8D18E4267AUL,
    0xB0A016D2FC9B873BUL, 0x02E9477817CD6FDFUL,
  ),
  (
    "windows-1257", 0x474A5EE930C863D1UL, 0x63D04D191BCA6EB5UL, 0xF30AFD37A2AA8E06UL,
    0xD4ECE9B00E0C6CD7UL, 0xFE614B8568F2E6B2UL,
  ),
  (
    "windows-1258", 0x8528410E690C815DUL, 0x1175B4CEFBD49669UL, 0x944DDD13EBB934A6UL,
    0xCA040A40A4620759UL, 0xF0C7C230500F6B1AUL,
  ),
  (
    "x-mac-cyrillic", 0xF96279C043FBA99DUL, 0x16DE41178E4F4541UL, 0x80F5545C796C88CBUL,
    0x94ECFCE839EF9672UL, 0xD36913B09C6DA09DUL,
  ),
  (
    "GBK", 0xFAA1D3918A1C45D2UL, 0x9E4E2C1609910ED3UL, 0x39500DC6A0496638UL, 0xB07BBE4914ADB353UL,
    0x69F7E489E1A559B6UL,
  ),
  (
    "gb18030", 0xFAA1D3918A1C45D2UL, 0x9E4E2C1609910ED3UL, 0x39500DC6A0496638UL,
    0xB07BBE4914ADB353UL, 0x69F7E489E1A559B6UL,
  ),
  (
    "Big5", 0x8D8B0A1E381225B2UL, 0x7D5BCC288349FCD5UL, 0xC39F3DA8458A7416UL, 0xED30DFDD5DD3ECF8UL,
    0x9039F91256A2F8A7UL,
  ),
  (
    "EUC-JP", 0x7049B46E4E25CE53UL, 0x7D5BCC288349FCD5UL, 0xC283A57A6ACF46E3UL, 0x1040B61B7F76673EUL,
    0x9B36880457E122DCUL,
  ),
  (
    "ISO-2022-JP", 0xE00738DAF1EF2F0DUL, 0x7D5BCC288349FCD5UL, 0x570836520152C0E0UL,
    0x29EE806F85BAC39AUL, 0x7B115B50CD73E43BUL,
  ),
  (
    "Shift_JIS", 0x3B6241E3BC9A8CF1UL, 0xB0B407D097A7FE5DUL, 0xD633D78A3F4FA8C3UL,
    0xEDC4622B4AEF2BCBUL, 0x4B34539D3DFC870AUL,
  ),
  (
    "EUC-KR", 0x6FE6C2595C6E82F0UL, 0x7D5BCC288349FCD5UL, 0x115FA05FC7AF14A4UL, 0x7968AB58FA0B1D4CUL,
    0x69D258F3D34ECCE8UL,
  ),
  (
    "UTF-16BE", 0x7C49EA8647F275EDUL, 0x47293F80E8F058BDUL, 0x99E461635F2EB12EUL,
    0x04EFA3ED78E30FE6UL, 0x9799F2B9DA4907F5UL,
  ),
  (
    "UTF-16LE", 0x3A024E5E4B86AAADUL, 0xC9B3B5585F4A8025UL, 0x6CD8C99BC0036B5BUL,
    0x85DAB6C9BBBEE1D6UL, 0xD37C2C3A8D58E9DFUL,
  ),
  (
    "x-user-defined", 0x92761952AC0C6725UL, 0x3A575263BEC69F1DUL, 0x2BF8ECF6E2165761UL,
    0x9C7C698905BBC24BUL, 0x0762975F2CCA57A7UL,
  ),
]

///|
test "decoders match encoding_rs on generated corpora" {
  let pairs = corpus_pairs()
  let gb4 = corpus_gb4()
  let random = corpus_random(200000)
  let random_small = random[0:20000].to_owned()
  let iso = corpus_iso(100000)
  let odd_sizes = [1, 2, 3, 5, 7, 11, 13, 4096]
  for entry in encoding_rs_hashes {
    let (name, h_pairs, h_gb4, h_random, h_random_small, h_iso) = entry
    assert_eq(Encoding::new(name).name(), name)
    assert_eq(
      (name, fnv1a(decode_direct(name, pairs, [8192]))),
      (name, h_pairs),
    )
    assert_eq((name, fnv1a(decode_direct(name, gb4, [8192]))), (name, h_gb4))
    assert_eq(
      (name, fnv1a(decode_direct(name, random, odd_sizes))),
      (name, h_random),
    )
    assert_eq(
      (name, fnv1a(decode_direct(name, random_small, [1]))),
      (name, h_random_small),
    )
    assert_eq((name, fnv1a(decode_direct(name, iso, odd_sizes))), (name, h_iso))
  }
}

///|
async test "decode: explicit UTF-8 is decoded, not passed through" {
  // Like encoding_rs_io, an explicitly requested UTF-8 decoder replaces
  // invalid sequences (only automatic detection passes UTF-8 through).
  assert_eq(
    @utf8.decode(decode_chunked("utf-8", b"abc\x81", [8192], bom_sniffing=true)),
    "abc\u{FFFD}",
  )
  assert_eq(
    decode_chunked("utf-8", b"\xEF\xBB\xBFx", [8192], bom_sniffing=true),
    b"x",
  )
}

///|
test "decode: truncated UTF-16 surrogate and odd byte is one error" {
  assert_eq(
    @utf8.decode(decode_direct("UTF-16BE", b"\xD8\x00\x00", [8192])),
    "\u{FFFD}",
  )
  assert_eq(
    @utf8.decode(decode_direct("UTF-16LE", b"\x00\xD8\x41", [1])),
    "\u{FFFD}",
  )
}

///|
async test "decode: pending lead at the end depends on chunking like encoding_rs_io" {
  // The BOM peeker returns the first 3 bytes on their own. Big5, EUC-KR and
  // Shift_JIS forget a pending lead when called with empty input before the
  // final flush, which only happens if the chunk with the lead produced
  // output.
  let r = (data : Bytes) => {
    decode_chunked("big5", data, [8192], bom_sniffing=true)
  }
  assert_eq(r(b"a\xE8"), b"a")
  assert_eq(@utf8.decode(r(b"abc\xE8")), "abc\u{FFFD}")
  assert_eq(r(b"abcd\xE8"), b"abcd")
  assert_eq(@utf8.decode(r(b"\xE8")), "\u{FFFD}")
  // Other decoders keep the pending sequence.
  assert_eq(
    @utf8.decode(decode_chunked("gbk", b"a\x81", [8192], bom_sniffing=true)),
    "a\u{FFFD}",
  )
}
