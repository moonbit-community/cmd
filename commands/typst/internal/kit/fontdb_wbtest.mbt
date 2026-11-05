// Tests of font discovery (`scan`) on directories with good, truncated,
// malformed and non-font files. Discovery reads as little of a file as it
// can, so the reference for every file is what the whole file gives: for
// every index of the collection, fontdb's admission (`admit_face`) and
// `FontInfo::new` on the file's bytes. A file is skipped silently if
// nothing parses, like upstream.
//
// The fonts are the embedded ones: one below the size up to which discovery
// reads a file whole, and one above it.
//
// (What these tests cannot make is checked by hand with the two command
// line programs: files and directories without read permission, links to
// files and directories, dangling ones and cycles.)

///|
fn be16(data : Bytes, at : Int32) -> Int32 {
  (data[at].to_int() << 8) | data[at + 1].to_int()
}

///|
fn be32(data : Bytes, at : Int32) -> UInt32 {
  (data[at].to_uint() << 24) |
  (data[at + 1].to_uint() << 16) |
  (data[at + 2].to_uint() << 8) |
  data[at + 3].to_uint()
}

///|
fn u16(v : Int32) -> Bytes {
  [(v >> 8).to_byte(), v.to_byte()]
}

///|
fn u32(v : UInt32) -> Bytes {
  [(v >> 24).to_byte(), (v >> 16).to_byte(), (v >> 8).to_byte(), v.to_byte()]
}

///|
fn zeros(n : Int32) -> Bytes {
  Bytes::make(n, b'\x00')
}

///|
/// A copy of `data` with the bytes at `at` replaced by `new`.
fn splice(data : Bytes, at : Int32, new : Bytes) -> Bytes {
  data[:at].to_owned() + new + data[at + new.length():].to_owned()
}

///|
/// A table record of a face: where the record is, and what it says.
struct Record {
  at : Int32
  tag : String
  offset : UInt32
  length : UInt32
}

///|
/// The table records of the face whose table directory is at `base`.
fn records(data : Bytes, base : Int32) -> Array[Record] {
  let out = []
  for i in 0..<be16(data, base + 4) {
    let at = base + 12 + 16 * i
    let tag = StringBuilder()
    for k in 0..<4 {
      tag.write_char(data[at + k].to_int().unsafe_to_char())
    }
    out.push({
      at,
      tag: tag.to_string(),
      offset: be32(data, at + 8),
      length: be32(data, at + 12),
    })
  }
  out
}

///|
fn record(data : Bytes, tag : String) -> Record {
  for record in records(data, 0) {
    if record.tag == tag {
      return record
    }
  }
  abort("no table \{tag}")
}

///|
/// A copy of `data` whose record at `at` has this offset and length.
fn patch(data : Bytes, at : Int32, offset : UInt32, length : UInt32) -> Bytes {
  splice(data, at + 8, u32(offset) + u32(length))
}

///|
/// A collection of whole fonts, one after another.
fn ttc(
  fonts : Array[Bytes],
  count? : UInt32,
  offsets? : Array[UInt32],
) -> Bytes {
  let mut pos = 12 + 4 * fonts.length()
  let starts = []
  let mut body = b""
  for font in fonts {
    starts.push(pos.reinterpret_as_uint())
    let mut moved = font
    for record in records(font, 0) {
      moved = patch(
        moved,
        record.at,
        record.offset + pos.reinterpret_as_uint(),
        record.length,
      )
    }
    body = body + moved
    pos += font.length()
  }
  let mut header = b"ttcf\x00\x01\x00\x00" +
    u32(count.unwrap_or(fonts.length().reinterpret_as_uint()))
  for start in offsets.unwrap_or(starts) {
    header = header + u32(start)
  }
  header + body
}

///|
/// The embedded font files that the tests use: one that discovery reads
/// whole, one that it reads in ranges, and an OpenType font with CFF
/// outlines of that kind.
fn test_fonts() -> (Bytes, Bytes, Bytes) {
  let mut small = b""
  let mut large = b""
  let mut otf = b""
  for font in @assets_fonts.fonts() {
    let truetype = be32(font, 0) == 0x00010000U
    if truetype && font.length() <= 262144 && small.length() == 0 {
      small = font
    }
    if truetype && font.length() > 262144 && large.length() == 0 {
      large = font
    }
    if !truetype && font.length() > 262144 && otf.length() == 0 {
      otf = font
    }
  }
  guard small.length() > 0 && large.length() > 0 && otf.length() > 0 else {
    abort("the embedded fonts changed")
  }
  (small, large, otf)
}

///|
/// What the whole file gives: the faces by index. Nothing for a file
/// without one of fontdb's extensions.
fn reference(name : String, data : Bytes) -> Array[(UInt32, @library.FontInfo)] {
  let out = []
  let file_name = match name.rev_find("/") {
    Some(i) => name[i + 1:].to_owned()
    None => name
  }
  // (Rust's `Path::extension`: a name that starts with its only dot has
  // none.)
  let extension = match file_name.rev_find(".") {
    Some(i) if i > 0 => file_name[i + 1:].to_owned()
    _ => ""
  }
  guard ["ttf", "ttc", "TTF", "TTC", "otf", "otc", "OTF", "OTC"].contains(
    extension,
  ) else {
    return out
  }
  let count = match @otf.fonts_in_collection(data[:]) {
    Some(count) => {
      // No face parses if the offsets of the faces are not all there. (A
      // count of 2^32 - 1 would also take a while.)
      if count.to_int64() * 4L > data.length().to_int64() - 12L {
        return out
      }
      count
    }
    None => 1U
  }
  for index in 0U..<count {
    if admit_face(data, index) &&
      @library.FontInfo::new(data, index) is Some(info) {
      out.push((index, info))
    }
  }
  out
}

///|
/// Writes the files into a directory of their own, scans it, checks every
/// file against the reference and gives the indices of the faces found per
/// file (`-` for none).
async fn scanned(name : String, files : Array[(String, Bytes)]) -> String {
  let dir = "_build/kit_fonts_test/\{name}"
  for file in files {
    let path = @platform.join(dir, file.0)
    @platform.create_dir_all(@platform.parent(path).unwrap())
    @platform.write_file(path, file.1)
  }
  let found : Map[String, Array[(UInt32, @library.FontInfo)]] = Map([])
  for entry in scan(dir) {
    guard entry.0 is Path(path~, index~) else { continue }
    let file = path[dir.length() + 1:].to_owned()
    match found.get(file) {
      Some(faces) => faces.push((index, entry.1))
      None => found[file] = [(index, entry.1)]
    }
  }
  let lines = []
  for file in files {
    let faces = found.get(file.0).unwrap_or([])
    if faces != reference(file.0, file.1) {
      fail("\{file.0}: not what the whole file gives")
    }
    let indices = if faces.is_empty() {
      "-"
    } else {
      faces.map(face => face.0.to_string()).join(" ")
    }
    lines.push("\{file.0}: \{indices}")
  }
  lines.join("\n")
}

///|
async test "scan: extensions, subdirectories, files that are not fonts" {
  let (small, large, otf) = test_fonts()
  let noise = Bytes::makei(300000, i => (i * 7919 + (i >> 8) * 31).to_byte())
  inspect(
    scanned("plain", [
      ("small.ttf", small),
      ("large.ttf", large),
      ("cff.otf", otf),
      ("upper.TTF", large),
      ("mixed.Ttf", large),
      ("other.ttx", large),
      ("text.txt", large),
      ("noext", large),
      (".ttf", large),
      (".hidden.otf", otf),
      ("sub/deeper/inside.OTF", otf),
      ("dir.ttf/inside.ttf", small),
      ("text.ttf", b"this is not a font\n"),
      ("empty.otf", b""),
      ("three.ttf", b"\x00\x01\x00"),
      ("zeros-small.ttf", zeros(5000)),
      ("zeros-large.ttf", zeros(400000)),
      ("noise-large.otf", noise),
      ("woff-small.ttf", splice(small, 0, b"wOFF")),
      ("woff-large.ttf", splice(large, 0, b"wOFF")),
      ("true-large.ttf", splice(large, 0, b"true")),
    ]),
    content=(
      #|small.ttf: 0
      #|large.ttf: 0
      #|cff.otf: 0
      #|upper.TTF: 0
      #|mixed.Ttf: -
      #|other.ttx: -
      #|text.txt: -
      #|noext: -
      #|.ttf: -
      #|.hidden.otf: 0
      #|sub/deeper/inside.OTF: 0
      #|dir.ttf/inside.ttf: 0
      #|text.ttf: -
      #|empty.otf: -
      #|three.ttf: -
      #|zeros-small.ttf: -
      #|zeros-large.ttf: -
      #|noise-large.otf: -
      #|woff-small.ttf: -
      #|woff-large.ttf: -
      #|true-large.ttf: 0
    ),
  )
}

///|
async test "scan: truncated files" {
  let (small, large, otf) = test_fonts()
  inspect(
    scanned("truncated", [
      ("header-small.ttf", small[:8].to_owned()),
      ("directory-small.ttf", small[:100].to_owned()),
      ("tables-small.ttf", small[:20000].to_owned()),
      ("half-small.ttf", small[:small.length() / 2].to_owned()),
      ("tail-small.ttf", small[:small.length() - 1000].to_owned()),
      ("header-large.ttf", large[:8].to_owned() + zeros(300000)),
      ("directory-large.ttf", large[:100].to_owned() + zeros(300000)),
      ("tables-large.ttf", large[:300000].to_owned()),
      ("tail-large.ttf", large[:large.length() - 1000].to_owned()),
      ("last-byte-large.ttf", large[:large.length() - 1].to_owned()),
      ("cff-large.otf", otf[:280000].to_owned()),
    ]),
    content=(
      #|header-small.ttf: -
      #|directory-small.ttf: -
      #|tables-small.ttf: -
      #|half-small.ttf: -
      #|tail-small.ttf: 0
      #|header-large.ttf: -
      #|directory-large.ttf: -
      #|tables-large.ttf: 0
      #|tail-large.ttf: 0
      #|last-byte-large.ttf: 0
      #|cff-large.otf: 0
    ),
  )
}

///|
async test "scan: table records that point elsewhere" {
  let (small, large, _) = test_fonts()
  let files = []
  for font in [("small", small), ("large", large)] {
    let (size, data) = font
    for tag in ["cmap", "name", "OS/2", "head", "post", "maxp", "hhea"] {
      let record = record(data, tag)
      let name = tag.replace(old="/", new="")
      let end = data.length().reinterpret_as_uint()
      files.push(
        (
          "past-end-\{name}-\{size}.ttf",
          patch(data, record.at, end - 10, record.length),
        ),
      )
      files.push(
        (
          "far-\{name}-\{size}.ttf",
          patch(data, record.at, 0xFFFFFF00U, record.length),
        ),
      )
      files.push(
        (
          "huge-\{name}-\{size}.ttf",
          patch(data, record.at, record.offset, 0xFFFFFFFFU),
        ),
      )
      files.push(
        ("empty-\{name}-\{size}.ttf", patch(data, record.at, record.offset, 0)),
      )
      files.push(
        ("short-\{name}-\{size}.ttf", patch(data, record.at, record.offset, 7)),
      )
      files.push(
        ("start-\{name}-\{size}.ttf", patch(data, record.at, 0, record.length)),
      )
    }
  }
  inspect(
    scanned("records", files),
    content=(
      #|past-end-cmap-small.ttf: 0
      #|far-cmap-small.ttf: 0
      #|huge-cmap-small.ttf: 0
      #|empty-cmap-small.ttf: 0
      #|short-cmap-small.ttf: 0
      #|start-cmap-small.ttf: 0
      #|past-end-name-small.ttf: -
      #|far-name-small.ttf: -
      #|huge-name-small.ttf: -
      #|empty-name-small.ttf: -
      #|short-name-small.ttf: -
      #|start-name-small.ttf: -
      #|past-end-OS2-small.ttf: 0
      #|far-OS2-small.ttf: 0
      #|huge-OS2-small.ttf: 0
      #|empty-OS2-small.ttf: 0
      #|short-OS2-small.ttf: 0
      #|start-OS2-small.ttf: 0
      #|past-end-head-small.ttf: -
      #|far-head-small.ttf: -
      #|huge-head-small.ttf: -
      #|empty-head-small.ttf: -
      #|short-head-small.ttf: -
      #|start-head-small.ttf: -
      #|past-end-post-small.ttf: 0
      #|far-post-small.ttf: 0
      #|huge-post-small.ttf: 0
      #|empty-post-small.ttf: 0
      #|short-post-small.ttf: 0
      #|start-post-small.ttf: 0
      #|past-end-maxp-small.ttf: -
      #|far-maxp-small.ttf: -
      #|huge-maxp-small.ttf: -
      #|empty-maxp-small.ttf: -
      #|short-maxp-small.ttf: 0
      #|start-maxp-small.ttf: 0
      #|past-end-hhea-small.ttf: -
      #|far-hhea-small.ttf: -
      #|huge-hhea-small.ttf: -
      #|empty-hhea-small.ttf: -
      #|short-hhea-small.ttf: -
      #|start-hhea-small.ttf: 0
      #|past-end-cmap-large.ttf: 0
      #|far-cmap-large.ttf: 0
      #|huge-cmap-large.ttf: 0
      #|empty-cmap-large.ttf: 0
      #|short-cmap-large.ttf: 0
      #|start-cmap-large.ttf: 0
      #|past-end-name-large.ttf: -
      #|far-name-large.ttf: -
      #|huge-name-large.ttf: -
      #|empty-name-large.ttf: -
      #|short-name-large.ttf: -
      #|start-name-large.ttf: -
      #|past-end-OS2-large.ttf: 0
      #|far-OS2-large.ttf: 0
      #|huge-OS2-large.ttf: 0
      #|empty-OS2-large.ttf: 0
      #|short-OS2-large.ttf: 0
      #|start-OS2-large.ttf: 0
      #|past-end-head-large.ttf: -
      #|far-head-large.ttf: -
      #|huge-head-large.ttf: -
      #|empty-head-large.ttf: -
      #|short-head-large.ttf: -
      #|start-head-large.ttf: -
      #|past-end-post-large.ttf: 0
      #|far-post-large.ttf: 0
      #|huge-post-large.ttf: 0
      #|empty-post-large.ttf: 0
      #|short-post-large.ttf: 0
      #|start-post-large.ttf: 0
      #|past-end-maxp-large.ttf: -
      #|far-maxp-large.ttf: -
      #|huge-maxp-large.ttf: -
      #|empty-maxp-large.ttf: -
      #|short-maxp-large.ttf: 0
      #|start-maxp-large.ttf: 0
      #|past-end-hhea-large.ttf: -
      #|far-hhea-large.ttf: -
      #|huge-hhea-large.ttf: -
      #|empty-hhea-large.ttf: -
      #|short-hhea-large.ttf: -
      #|start-hhea-large.ttf: 0
    ),
  )
}

///|
/// A font with `n` more table records, of empty tables whose tags come
/// after all others.
fn with_more_tables(data : Bytes, n : Int32) -> Bytes {
  let all = records(data, 0)
  let end = 12 + 16 * all.length()
  let mut out = data[:end].to_owned()
  for i in 0..<n {
    // "zz" and two digits.
    let tag = 0x7A7A3030U +
      ((i / 10) << 8).reinterpret_as_uint() +
      (i % 10).reinterpret_as_uint()
    out = out + u32(tag) + zeros(12)
  }
  out = splice(out + data[end:].to_owned(), 4, u16(all.length() + n))
  for record in all {
    out = patch(
      out,
      record.at,
      record.offset + (16 * n).reinterpret_as_uint(),
      record.length,
    )
  }
  out
}

///|
async test "scan: table directories" {
  let (small, large, _) = test_fonts()
  let files = []
  for font in [("small", small), ("large", large)] {
    let (size, data) = font
    let all = records(data, 0)
    // Two records exchanged, all in reverse order, one twice.
    let (a, b) = (all[2], all[5])
    files.push(
      (
        "unsorted-\{size}.ttf",
        splice(
          splice(data, a.at, data[b.at:b.at + 16].to_owned()),
          b.at,
          data[a.at:a.at + 16].to_owned(),
        ),
      ),
    )
    let mut reversed = data
    for i, record in all {
      let other = all[all.length() - 1 - i]
      reversed = splice(
        reversed,
        record.at,
        data[other.at:other.at + 16].to_owned(),
      )
    }
    files.push(("reversed-\{size}.ttf", reversed))
    files.push(
      (
        "twice-\{size}.ttf",
        splice(data, all[4].at, data[all[3].at:all[3].at + 16].to_owned()),
      ),
    )
    // More tables than the file has room for, none.
    files.push(("too-many-\{size}.ttf", splice(data, 4, u16(0xFFFF))))
    files.push(("none-\{size}.ttf", splice(data, 4, u16(0))))
    files.push(("fewer-\{size}.ttf", splice(data, 4, u16(all.length() - 3))))
    // More table records than discovery reads at first (32), and one more.
    files.push(
      ("32-tables-\{size}.ttf", with_more_tables(data, 32 - all.length())),
    )
    files.push(
      ("33-tables-\{size}.ttf", with_more_tables(data, 33 - all.length())),
    )
    files.push(
      ("90-tables-\{size}.ttf", with_more_tables(data, 90 - all.length())),
    )
  }
  inspect(
    scanned("directories", files),
    content=(
      #|unsorted-small.ttf: 0
      #|reversed-small.ttf: -
      #|twice-small.ttf: 0
      #|too-many-small.ttf: -
      #|none-small.ttf: -
      #|fewer-small.ttf: -
      #|32-tables-small.ttf: 0
      #|33-tables-small.ttf: 0
      #|90-tables-small.ttf: 0
      #|unsorted-large.ttf: 0
      #|reversed-large.ttf: -
      #|twice-large.ttf: 0
      #|too-many-large.ttf: -
      #|none-large.ttf: -
      #|fewer-large.ttf: -
      #|32-tables-large.ttf: 0
      #|33-tables-large.ttf: 0
      #|90-tables-large.ttf: 0
    ),
  )
}

///|
async test "scan: collections" {
  let (small, large, otf) = test_fonts()
  let two = ttc([small, large])
  let first = be32(two, 12)
  let second = be32(two, 16)
  // Three faces that share all their tables, like the collections of a
  // system; then one whose second face has a shorter `cmap` at the same
  // place and whose third has a shorter `name`.
  let mut shared = ttc([large, large, large])
  let of_first = records(shared, be32(shared, 12).reinterpret_as_int())
  for k in 1..<3 {
    let base = be32(shared, 12 + 4 * k).reinterpret_as_int()
    for i, record in records(shared, base) {
      shared = patch(shared, record.at, of_first[i].offset, of_first[i].length)
    }
  }
  // The collection with the record of a table of its face `k` changed.
  let with_record = (
    data : Bytes,
    k : Int32,
    tag : String,
    change : (Record) -> (UInt32, UInt32),
  ) => {
    let mut out = data
    for record in records(data, be32(data, 12 + 4 * k).reinterpret_as_int()) {
      if record.tag == tag {
        let (offset, length) = change(record)
        out = patch(out, record.at, offset, length)
      }
    }
    out
  }
  let shorter = with_record(
    with_record(shared, 1, "cmap", r => (r.offset, r.length - 4000)),
    2,
    "name",
    r => (r.offset, 30),
  )
  // The first face of a `cmap` has no name (so its coverage is not
  // computed); no face has its `cmap` in the file; the second face has
  // another table as its `cmap`, and no `post` (it is not monospaced).
  let unnamed = with_record(shared, 0, "name", r => (r.offset, 30))
  let mut outside = shared
  for k in 0..<3 {
    outside = with_record(outside, k, "cmap", r => (0xFFFFFF00U, r.length))
  }
  let name = records(shared, be32(shared, 12).reinterpret_as_int()).filter(r => {
      r.tag == "name"
    })[0]
  let other = with_record(
    with_record(shared, 1, "cmap", _ => (name.offset, name.length)),
    1,
    "post",
    r => (r.offset, 0),
  )
  inspect(
    scanned("collections", [
      ("three.ttc", ttc([small, large, large])),
      ("one-small.ttc", ttc([small])),
      ("cff.otc", ttc([otf, otf])),
      ("mixed.TTC", ttc([otf, large])),
      ("shared.ttc", shared),
      ("shared-shorter.ttc", shorter),
      ("shared-unnamed-first.ttc", unnamed),
      ("shared-cmap-outside.ttc", outside),
      ("shared-other-cmap.ttc", other),
      ("count-5.ttc", ttc([small, large], count=5)),
      ("count-0.ttc", ttc([small, large], count=0)),
      ("count-1.ttc", ttc([small, large], count=1)),
      ("count-2-31.ttc", ttc([small, large], count=0x7FFFFFFFU)),
      ("count-2-32.ttc", ttc([small, large], count=0xFFFFFFFFU)),
      ("count-2-32-small.ttc", ttc([small], count=0xFFFFFFFFU)),
      (
        "second-past-end.ttc",
        ttc([small, large], offsets=[
          first,
          two.length().reinterpret_as_uint() + 5,
        ]),
      ),
      ("first-in-header.ttc", ttc([small, large], offsets=[4, second])),
      ("both-second.ttc", ttc([small, large], offsets=[second, second])),
      ("exchanged.ttc", ttc([small, large], offsets=[second, first])),
      ("cut-in-second.ttc", two[:second.reinterpret_as_int() + 200].to_owned()),
      ("cut-small.ttc", two[:5000].to_owned()),
      ("header-only.otc", two[:12].to_owned()),
      ("header-only-large.otc", two[:12].to_owned() + zeros(300000)),
    ]),
    content=(
      #|three.ttc: 0 1 2
      #|one-small.ttc: 0
      #|cff.otc: 0 1
      #|mixed.TTC: 0 1
      #|shared.ttc: 0 1 2
      #|shared-shorter.ttc: 0 1
      #|shared-unnamed-first.ttc: 1 2
      #|shared-cmap-outside.ttc: 0 1 2
      #|shared-other-cmap.ttc: 0 1 2
      #|count-5.ttc: 1
      #|count-0.ttc: -
      #|count-1.ttc: 0
      #|count-2-31.ttc: -
      #|count-2-32.ttc: -
      #|count-2-32-small.ttc: -
      #|second-past-end.ttc: 0
      #|first-in-header.ttc: 1
      #|both-second.ttc: 0 1
      #|exchanged.ttc: 0 1
      #|cut-in-second.ttc: 0
      #|cut-small.ttc: -
      #|header-only.otc: -
      #|header-only-large.otc: -
    ),
  )
}

///|
/// A collection of `n` faces that all have the tables of one font, of which
/// it holds one copy.
fn one_body(font : Bytes, n : Int32) -> Bytes {
  let all = records(font, 0)
  let directory = 12 + 16 * all.length()
  let body = 12 + 4 * n + n * directory
  let mut moved = font[:directory].to_owned()
  for record in all {
    moved = patch(
      moved,
      record.at,
      record.offset + body.reinterpret_as_uint(),
      record.length,
    )
  }
  let mut header = b"ttcf\x00\x01\x00\x00" + u32(n.reinterpret_as_uint())
  let mut directories = b""
  for k in 0..<n {
    header = header + u32((12 + 4 * n + k * directory).reinterpret_as_uint())
    directories = directories + moved
  }
  header + directories + font
}

///|
async test "scan: what a collection keeps for its faces is bounded" {
  // The faces of a collection share the tables that discovery has read. A
  // file can be made to have many large tables in little space: here 60
  // faces whose `post` tables are the outlines of the font, each one byte
  // shorter than the one before, 60 tables of the size of the file.
  let (_, large, _) = test_fonts()
  let n = 60
  let mut data = one_body(large, n)
  let outlines = record(large, "glyf")
  guard outlines.length > 100000U else { abort("the embedded fonts changed") }
  // Where the font's bytes are in the collection: after the header and the
  // table directories.
  let directory = (be32(data, 16) - be32(data, 12)).reinterpret_as_int()
  let body = (12 + 4 * n + n * directory).reinterpret_as_uint()
  for k in 0..<n {
    let base = be32(data, 12 + 4 * k).reinterpret_as_int()
    for record in records(data, base) {
      if record.tag == "post" {
        data = patch(
          data,
          record.at,
          outlines.offset + body,
          outlines.length - k.reinterpret_as_uint(),
        )
      }
    }
  }
  let indices = Array::makei(n, k => k.to_string()).join(" ")
  // All faces are found, and they are what the whole file gives.
  inspect(
    scanned("bounded", [("overlapping.ttc", data)]) ==
    "overlapping.ttc: \{indices}",
    content="true",
  )
  // And what was kept for them is no more than the file.
  let file = FontFile::open("_build/kit_fonts_test/bounded/overlapping.ttc")
  defer file.close()
  let mut found = 0
  for index in 0U..<file.fonts_in_collection().unwrap_or(0) {
    if file.probe_face(index) is Some(probe) && file.info(probe) is Some(_) {
      found += 1
    }
  }
  inspect(found, content="60")
  inspect(file.retained <= file.size, content="true")
  // (Not every table was kept: with ranged reads, the second `post` did not
  // fit any more.)
  let kept = file.tables.length()
  inspect(kept == 0 || kept < n, content="true")
}

///|
/// A font with other character maps: `cmap` tables that do not parse, and
/// subtables of formats 4 and 12 that are not what they should be.
fn cmap_variants(large : Bytes) -> Array[(String, Bytes)] {
  let table = record(large, "cmap")
  let offset = table.offset.reinterpret_as_int()
  let length = table.length.reinterpret_as_int()
  let cmap = large[offset:offset + length].to_owned()
  // The font with another `cmap` of the same length.
  let with_cmap = (new : Bytes) => splice(large, offset, new)
  let count = be16(cmap, 2)
  let files = [
    ("zeros.ttf", with_cmap(zeros(length))),
    ("ones.ttf", with_cmap(Bytes::make(length, b'\xff'))),
    ("too-many-subtables.ttf", with_cmap(splice(cmap, 2, u16(0xFFFF)))),
    ("no-subtables.ttf", with_cmap(splice(cmap, 2, u16(0)))),
  ]
  // All encoding records point to the first subtable, past the table, in
  // reverse order.
  let mut same = cmap
  let mut past = cmap
  let mut reversed = cmap
  for k in 0..<count {
    same = splice(same, 4 + 8 * k + 4, cmap[8:12].to_owned())
    past = splice(past, 4 + 8 * k + 4, u32(table.length + 100))
    let other = 4 + 8 * (count - 1 - k) + 4
    reversed = splice(reversed, 4 + 8 * k + 4, cmap[other:other + 4].to_owned())
  }
  files.push(("same-subtable.ttf", with_cmap(same)))
  files.push(("subtables-past-end.ttf", with_cmap(past)))
  files.push(("subtables-reversed.ttf", with_cmap(reversed)))
  let seen = []
  for k in 0..<count {
    let at = be32(cmap, 4 + 8 * k + 4).reinterpret_as_int()
    if seen.contains(at) {
      continue
    }
    seen.push(at)
    let format = be16(cmap, at)
    if format == 4 {
      let segments = be16(cmap, at + 6) / 2
      let ends = at + 14
      let starts = ends + 2 * segments + 2
      // Two segments exchanged, a start after its end, more segments than
      // there are, the end mark first, a start of 0 after others.
      files.push(
        (
          "format4-unsorted.ttf",
          with_cmap(
            splice(
              splice(cmap, starts, cmap[starts + 2:starts + 4].to_owned()),
              starts + 2,
              cmap[starts:starts + 2].to_owned(),
            ),
          ),
        ),
      )
      files.push(
        ("format4-inverted.ttf", with_cmap(splice(cmap, starts, u16(0xFFFE)))),
      )
      files.push(
        ("format4-count.ttf", with_cmap(splice(cmap, at + 6, u16(0xFFFE)))),
      )
      files.push(
        ("format4-odd-count.ttf", with_cmap(splice(cmap, at + 6, u16(7)))),
      )
      files.push(
        ("format4-count-1.ttf", with_cmap(splice(cmap, at + 6, u16(1)))),
      )
      files.push(
        (
          "format4-end-first.ttf",
          with_cmap(
            splice(splice(cmap, ends, u16(0xFFFF)), starts, u16(0xFFFF)),
          ),
        ),
      )
      files.push(
        (
          "format4-from-0.ttf",
          with_cmap(
            splice(splice(cmap, starts + 6, u16(0)), ends + 6, u16(0xFFFF)),
          ),
        ),
      )
    }
    if format == 12 {
      let groups = at + 16
      // Two groups exchanged, a start after its end, more groups than there
      // are, a group up to the last code, the same groups as format 13.
      files.push(
        (
          "format12-unsorted.ttf",
          with_cmap(
            splice(
              splice(cmap, groups, cmap[groups + 12:groups + 24].to_owned()),
              groups + 12,
              cmap[groups:groups + 12].to_owned(),
            ),
          ),
        ),
      )
      files.push(
        (
          "format12-inverted.ttf",
          with_cmap(splice(cmap, groups, u32(0x00100000U))),
        ),
      )
      files.push(
        (
          "format12-count.ttf",
          with_cmap(splice(cmap, at + 12, u32(0x0FFFFFFFU))),
        ),
      )
      files.push(
        ("format12-no-groups.ttf", with_cmap(splice(cmap, at + 12, u32(0)))),
      )
      files.push(
        (
          "format12-to-the-last.ttf",
          with_cmap(splice(cmap, groups + 4, u32(0xFFFFFFFFU))),
        ),
      )
      files.push(
        (
          "format12-from-0.ttf",
          with_cmap(
            splice(
              splice(cmap, groups + 36, u32(0)),
              groups + 40,
              u32(0x10FFFFU),
            ),
          ),
        ),
      )
      files.push(("format13.ttf", with_cmap(splice(cmap, at, u16(13)))))
    }
    files.push(("format-8-at-\{k}.ttf", with_cmap(splice(cmap, at, u16(8)))))
    files.push(("format-99-at-\{k}.ttf", with_cmap(splice(cmap, at, u16(99)))))
  }
  files
}

///|
async test "scan: character maps" {
  let (_, large, _) = test_fonts()
  inspect(
    scanned("cmaps", cmap_variants(large)),
    content=(
      #|zeros.ttf: 0
      #|ones.ttf: 0
      #|too-many-subtables.ttf: 0
      #|no-subtables.ttf: 0
      #|same-subtable.ttf: 0
      #|subtables-past-end.ttf: 0
      #|subtables-reversed.ttf: 0
      #|format4-unsorted.ttf: 0
      #|format4-inverted.ttf: 0
      #|format4-count.ttf: 0
      #|format4-odd-count.ttf: 0
      #|format4-count-1.ttf: 0
      #|format4-end-first.ttf: 0
      #|format4-from-0.ttf: 0
      #|format-8-at-0.ttf: 0
      #|format-99-at-0.ttf: 0
      #|format12-unsorted.ttf: 0
      #|format12-inverted.ttf: 0
      #|format12-count.ttf: 0
      #|format12-no-groups.ttf: 0
      #|format12-to-the-last.ttf: 0
      #|format12-from-0.ttf: 0
      #|format13.ttf: 0
      #|format-8-at-1.ttf: 0
      #|format-99-at-1.ttf: 0
      #|format-8-at-2.ttf: 0
      #|format-99-at-2.ttf: 0
    ),
  )
}

///|
/// Upstream's `CoverageBuilder` (`info.rs`).
priv struct ReferenceBuilder {
  runs : Array[UInt32]
  mut next : UInt32
}

///|
fn ReferenceBuilder::add_codepoint_range(
  self : ReferenceBuilder,
  start : UInt32,
  end : UInt32,
) -> Unit {
  if end <= self.next || start >= end {
    return
  } else if start <= self.next && self.runs.length() > 0 {
    let last = self.runs.length() - 1
    self.runs[last] = self.runs[last] + (end - self.next)
  } else {
    self.runs.push(start - self.next)
    self.runs.push(end - start)
  }
  self.next = end
}

///|
/// Upstream's `Coverage::iter_ranges`.
fn reference_ranges(runs : Array[UInt32]) -> Array[(UInt32, UInt32)] {
  let out = []
  let mut offset = 0U
  for i in 0..<(runs.length() / 2) {
    offset += runs[2 * i]
    let start = offset
    offset += runs[2 * i + 1]
    out.push((start, offset))
  }
  out
}

///|
/// Upstream's `Coverage::union`.
fn reference_union(
  left : Array[UInt32],
  right : Array[UInt32],
) -> Array[UInt32] {
  let builder = ReferenceBuilder::{ runs: [], next: 0, }
  let left = reference_ranges(left)
  let right = reference_ranges(right)
  let mut i = 0
  let mut j = 0
  while i < left.length() && j < right.length() {
    if left[i].0 < right[j].0 {
      builder.add_codepoint_range(left[i].0, left[i].1)
      i += 1
    } else {
      builder.add_codepoint_range(right[j].0, right[j].1)
      j += 1
    }
  }
  for k in i..<left.length() {
    builder.add_codepoint_range(left[k].0, left[k].1)
  }
  for k in j..<right.length() {
    builder.add_codepoint_range(right[k].0, right[k].1)
  }
  builder.runs
}

///|
/// The coverage of a face as upstream's `FontInfo::from_ttf` computes it:
/// every codepoint of every Unicode subtable is added on its own, and the
/// subtables are united.
fn reference_coverage(face : @otf.Face) -> Array[UInt32] {
  let mut coverage : Array[UInt32] = []
  if face.tables().cmap is Some(cmap) {
    for subtable in cmap.subtables.iter() {
      if subtable.is_unicode() {
        let builder = ReferenceBuilder::{ runs: [], next: 0, }
        subtable.codepoints(c => {
          // `c..c.saturating_add(1)`
          let end = if c == 0xFFFFFFFFU { c } else { c + 1 }
          builder.add_codepoint_range(c, end)
        })
        coverage = reference_union(coverage, builder.runs)
      }
    }
  }
  coverage
}

///|
test "coverage: from ranges as from single codepoints" {
  // `FontInfo` adds the segments and groups of a subtable as ranges and
  // unites the subtables without listing their ranges. That must be the
  // encoding that upstream gets codepoint by codepoint.
  let mut faces = 0
  let check = (name : String, data : Bytes) => {
    let count = @otf.fonts_in_collection(data[:]).unwrap_or(1)
    for index in 0U..<count {
      let face = @otf.Face::parse(data[:], index) catch { _ => continue }
      guard @library.FontInfo::from_ttf(face) is Some(info) else { continue }
      guard info.coverage.0 == reference_coverage(face) else {
        fail("\{name}, face \{index}: not upstream's coverage")
      }
      faces += 1
    }
  }
  for i, font in @assets_fonts.fonts() {
    check("embedded font \{i}", font)
  }
  inspect(
    faces,
    content=(
      #|17
    ),
  )
  let (_, large, _) = test_fonts()
  for file in cmap_variants(large) {
    // (A group that ends at 2^32 - 1 takes minutes codepoint by codepoint.)
    if file.0 != "format12-to-the-last.ttf" {
      check(file.0, file.1)
    }
  }
  inspect(
    faces,
    content=(
      #|43
    ),
  )
}
