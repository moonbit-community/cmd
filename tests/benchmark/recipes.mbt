///|
fn benchmark_recipe_command(recipe : String) -> String? {
  for
    (command, modes) in [
      ("cat", ["copy", "format"]),
      ("wc", ["lines", "words", "bytes"]),
      ("cut", ["bytes", "fields"]),
      ("sed", ["hit", "miss"]),
      ("sort", ["lexical", "numeric", "spill"]),
      ("uniq", ["adjacent", "count"]),
      ("jq", ["identity", "name", "select", "aggregate", "sort", "group"]),
      ("diff", ["equal", "sparse-edit", "distributed-edit"]),
      ("join", ["mixed", "duplicates", "natural-csv"]),
      ("comm", ["mixed", "natural-idsets"]),
      ("csplit", ["boundaries"]),
      ("rg", ["literal-count", "regex-count", "regex-output"]),
      ("grep", ["literal-count", "regex-count", "regex-output"]),
      (
        "gunzip",
        [
          "stored", "fixed-literals", "native-dynamic", "members", "fixed-backref-one",
          "fixed-backref-window",
        ],
      ),
      (
        "zcat",
        [
          "stored", "fixed-literals", "native-dynamic", "members", "fixed-backref-one",
          "fixed-backref-window",
        ],
      ),
      ("rev", ["ascii-records"]),
      ("tac", ["reverse-records"]),
      ("column", ["table", "grid"]),
      ("strings", ["all-bytes"]),
      ("split", ["byte-chunks"]),
      ("nl", ["number-records"]),
      ("paste", ["serial"]),
      ("expand", ["tabs"]),
      ("unexpand", ["spaces"]),
      ("fold", ["width"]),
      ("tail", ["last-records"]),
      ("head", ["early-exit"]),
      ("base64", ["encode"]),
      ("base32", ["encode"]),
      ("cksum", ["crc"]),
      ("md5sum", ["digest"]),
      ("sha1sum", ["digest"]),
      ("sha256sum", ["digest"]),
      ("sha512sum", ["digest"]),
      ("tr", ["uppercase"]),
    ] {
    for mode in modes {
      if recipe == "bench-" + command + "-" + mode {
        return Some(command)
      }
    }
  }
  None
}

///|
fn benchmark_recipe_args(recipe : String) -> Array[String] raise {
  match recipe {
    "bench-cat-copy" => []
    "bench-cat-format" => ["-b", "-s", "-A"]
    "bench-wc-lines" => ["-l"]
    "bench-wc-words" => ["-w"]
    "bench-wc-bytes" => ["-c"]
    "bench-cut-bytes" => ["-b", "1-8"]
    "bench-cut-fields" => ["-d", " ", "-f", "1,3"]
    "bench-sed-hit" => ["s/needle/NEEDLE/g"]
    "bench-sed-miss" => ["s/IMPOSSIBLE_MARKER_987/REPLACED/g"]
    "bench-sort-lexical" => []
    "bench-sort-numeric" => ["-n"]
    "bench-sort-spill" => ["-S", "4M"]
    "bench-uniq-adjacent" => []
    "bench-uniq-count" => ["-c"]
    "bench-jq-identity" => ["-c", "."]
    "bench-jq-name" => ["-c", ".name"]
    "bench-jq-select" => ["-c", "select(.active == true)"]
    "bench-jq-aggregate" => ["-s", "[.[] | .items | length] | add"]
    "bench-jq-sort" => ["-s", "-c", "sort_by(.id)"]
    "bench-jq-group" => ["-s", "-c", "group_by(.active) | map(length)"]
    "bench-diff-equal"
    | "bench-diff-sparse-edit"
    | "bench-diff-distributed-edit" =>
      ["--label", "left", "--label", "right", "-u", "left", "right"]
    "bench-join-mixed" => ["-a1", "-a2", "left", "right"]
    "bench-join-duplicates" => ["left", "right"]
    "bench-join-natural-csv" =>
      ["-t", ",", "-1", "1", "-2", "4", "-a1", "-a2", "left", "right"]
    "bench-comm-mixed" | "bench-comm-natural-idsets" => ["left", "right"]
    "bench-csplit-boundaries" =>
      ["-s", "-z", "-n", "6", "-f", "part-", "-", "/^SECTION /", "{*}"]
    "bench-rg-literal-count" => ["-F", "-c", "needle", "-"]
    "bench-rg-regex-count" => ["-c", "[0-9]+.*needle", "-"]
    "bench-rg-regex-output" => ["-n", "[0-9]+.*needle", "-"]
    "bench-grep-literal-count" => ["-F", "-c", "needle"]
    "bench-grep-regex-count" => ["-E", "-c", "[0-9]+.*needle"]
    "bench-grep-regex-output" => ["-E", "-n", "[0-9]+.*needle"]
    "bench-rev-ascii-records" | "bench-tac-reverse-records" => []
    "bench-column-table" => ["-t"]
    "bench-column-grid" => ["-c", "80"]
    "bench-strings-all-bytes" => ["-a"]
    "bench-split-byte-chunks" => ["-b", "1M", "-", "part-"]
    "bench-nl-number-records" => []
    "bench-paste-serial" => ["-s"]
    "bench-expand-tabs" => ["-t", "4"]
    "bench-unexpand-spaces" => ["-a", "-t", "4"]
    "bench-fold-width" => ["-w", "80"]
    "bench-tail-last-records" => ["-n", "10"]
    "bench-head-early-exit" => ["-n", "10"]
    "bench-base64-encode" | "bench-base32-encode" => ["-w0"]
    "bench-tr-uppercase" => ["a-z", "A-Z"]
    "bench-cksum-crc"
    | "bench-md5sum-digest"
    | "bench-sha1sum-digest"
    | "bench-sha256sum-digest"
    | "bench-sha512sum-digest" => []
    _ => {
      guard benchmark_recipe_command(recipe) is Some(command) &&
        ["gunzip", "zcat"].contains(command) else {
        fail("unknown benchmark recipe: " + recipe)
      }
      if command == "gunzip" {
        ["-c"]
      } else {
        []
      }
    }
  }
}

///|
fn benchmark_file_recipe(recipe : String?) -> Bool {
  if recipe == Some("real-file-pair") {
    return true
  }
  match recipe {
    Some(value) =>
      value.has_prefix("bench-diff-") ||
      value.has_prefix("bench-join-") ||
      value.has_prefix("bench-comm-")
    None => false
  }
}

///|
async fn copy_recipe_range(
  source : String,
  output : @fs.File,
  start : Int64,
  length : Int64,
) -> Unit {
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  guard start >= 0L && length >= 0L && start + length <= input.size() else {
    fail("invalid recipe source range")
  }
  let mut offset = 0L
  while offset < length {
    let count = (length - offset).min(65536L).to_int()
    output.write(input.read_exactly_at(count, position=start + offset))
    offset += count.to_int64()
  }
}

///|
fn recipe_key(index : Int64) -> String {
  let key = index.to_string()
  "0".repeat((10 - key.length()).max(0)) + key
}

///|
async fn write_recipe_keys(
  path : String,
  groups : Int64,
  side : Int32,
  duplicates : Bool,
  comm : Bool,
  seed~ : Int32 = 0,
) -> Int64 {
  let output = @fs.create(path)
  defer output.close()
  let pending : Array[String] = []
  let mut rows = 0L
  for group = 0L; group < groups; group = group + 1L {
    if !duplicates &&
      (if side == 0 { group % 2L != 0L } else { group % 3L != 0L }) {
      continue
    }
    let repeats = if duplicates { if side == 0 { 4 } else { 3 } } else { 1 }
    for repeat in 0..<repeats {
      pending.push(
        recipe_key(group + seed.to_int64() * 104729L) +
        (if comm {
          "\n"
        } else {
          " " + side.to_string() + ":" + repeat.to_string() + " payload\n"
        }),
      )
      rows += 1L
      if pending.length() >= 1024 {
        output.write(pending.join(""))
        pending.clear()
      }
    }
  }
  if !pending.is_empty() {
    output.write(pending.join(""))
  }
  rows
}

///|
// Setup is outside timing. Equal-input controls use distinct files; join and
// comm inputs have declared overlap/duplicate regimes rather than self-input.
async fn prepare_benchmark_recipe(
  workload : FunctionalWorkload,
  prepared : PreparedCorpus?,
  root : String,
  oracle~ : String = "",
  environment~ : Map[String, String] = Map([]),
  timeout_ms~ : Int32 = 120000,
) -> Unit {
  guard benchmark_file_recipe(workload.recipe) else { return }
  guard prepared is Some(prepared) else {
    fail("file-mode benchmark requires a declared input corpus")
  }
  let recipe = workload.recipe.unwrap()
  if recipe == "real-file-pair" {
    guard workload.other_source is Some(other) else {
      fail("real file pair requires two declared sources")
    }
    let secondary = @path.Path(prepared.source)
      .dirname()
      .join(Path("natural-" + other.sha256 + ".bin"))
      .to_string()
    assert_eq(benchmark_file_sha256(secondary), other.sha256)
    let left = @fs.create(root + "/left")
    copy_recipe_range(prepared.source, left, 0L, @fs.file_size(prepared.source))
    left.close()
    let right = @fs.create(root + "/right")
    copy_recipe_range(secondary, right, 0L, @fs.file_size(secondary))
    right.close()
    write_json(root + "/recipe-features.json", {
      "recipe": recipe,
      "transformation": "distinct complete copies of declared genuine sources; no generated edits",
      "left_sha256": benchmark_file_sha256(root + "/left"),
      "right_sha256": benchmark_file_sha256(root + "/right"),
    })
    return
  }
  if ["bench-join-natural-csv", "bench-comm-natural-idsets"].contains(recipe) {
    prepare_natural_pair(
      workload, prepared, root, oracle, environment, timeout_ms,
    )
    return
  }
  let source = @fs.open(prepared.source, mode=ReadOnly)
  let size = source.size()
  source.close()
  let features : Map[String, Json] = {
    "recipe": Json(recipe),
    "same_file_identity": Json(false),
    "input_transport": "distinct-named-files",
  }
  if recipe.has_prefix("bench-diff-") {
    let left = @fs.create(root + "/left")
    copy_recipe_range(prepared.source, left, 0L, size)
    left.close()
    let right = @fs.create(root + "/right")
    defer right.close()
    if recipe == "bench-diff-equal" {
      copy_recipe_range(prepared.source, right, 0L, size)
      features["edit_regime"] = Json("equal bytes in distinct regular files")
    } else if recipe == "bench-diff-sparse-edit" {
      guard size >= 480L else {
        fail("sparse-edit corpus needs at least six 80-byte records")
      }
      let cut = size / 3L / 80L * 80L
      copy_recipe_range(prepared.source, right, 0L, cut)
      right.write(b"inserted benchmark record\n")
      copy_recipe_range(prepared.source, right, cut + 160L, size - cut - 160L)
      features["edit_regime"] = Json(
        "insert one record and delete 160 interior source bytes (two rows in the registered 80-byte corpus)",
      )
    } else {
      let mut offset = 0L
      let mut blocks = 0
      while offset < size {
        let count = (size - offset).min(65520L)
        let input = @fs.open(prepared.source, mode=ReadOnly)
        let data = input.read_exactly_at(count.to_int(), position=offset)
        input.close()
        let modified = Bytes::makei(data.length(), i => {
          if i == 0 {
            b'X'
          } else {
            data[i]
          }
        })
        if blocks % 3 == 0 {
          right.write(b"inserted distributed record\n")
        }
        right.write(
          modified[:if blocks % 5 == 0 && count > 80L {
            modified.length() - 80
          } else {
            modified.length()
          }],
        )
        offset += count
        blocks += 1
      }
      features["edit_regime"] = Json(
        "distributed replacement, insertion and deletion",
      )
      features["edited_blocks"] = Json(blocks)
    }
  } else {
    features["corpus_role"] = Json(
      "size-budget only; actual inputs are the declared sorted key-file recipe",
    )
    let duplicates = recipe == "bench-join-duplicates"
    let comm = recipe == "bench-comm-mixed"
    let groups = (size / (if duplicates { 512L } else { 64L })).max(12L)
    let left_rows = write_recipe_keys(
      root + "/left",
      groups,
      0,
      duplicates,
      comm,
      seed=workload.seed.unwrap_or(0),
    )
    let right_rows = write_recipe_keys(
      root + "/right",
      groups,
      1,
      duplicates,
      comm,
      seed=workload.seed.unwrap_or(0),
    )
    features["key_groups"] = Json(groups)
    features["variant_seed"] = Json(workload.seed.unwrap_or(0))
    features["left_rows"] = Json(left_rows)
    features["right_rows"] = Json(right_rows)
    features["overlap_regime"] = Json(
      if duplicates {
        "every key has four left rows and three right rows; twelve joined outputs per key"
      } else {
        "left even keys, right multiples of three; shared and unpaired keys on both sides"
      },
    )
  }
  features["left_bytes"] = Json(@fs.file_size(root + "/left"))
  features["right_bytes"] = Json(@fs.file_size(root + "/right"))
  @fs.write_file(
    root + "/recipe-features.json",
    Json(features).stringify(indent=2),
  )
}
