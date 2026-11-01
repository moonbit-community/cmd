///|
priv struct CorpusCase {
  name : String
  regex : String
  haystack_hex : String
  matches : Array[Array[(Int32, Int32)?]]
  compiles : Bool
  anchored : Bool
  case_insensitive : Bool
  unicode : Bool
  utf8 : Bool
  // Preserve the corpus's standard ToJson option representation. Derived
  // optional struct fields instead interpret an absent key as None.
  match_limit : Json
  bounds : Json
  line_terminator : Json
} derive(FromJson)

///|
/// Repository-owned corpus data; this package is imported only by tests.
/// Moon runs these tests with the cli/rg module as their working directory.
pub async fn load() -> Array[TestCase] {
  let source = @fs.read_file("../../tests/fixtures/rg/regex-corpus.jsonl").text()
  let cases : Array[TestCase] = []
  let names : Set[String] = Set([])
  for line in source.split("\n") {
    if line.trim().is_empty() {
      continue
    }
    let row : CorpusCase = @json.from_json(@json.parse(line.to_owned()))
    guard !row.name.is_empty() && !names.contains(row.name) else {
      fail("empty or duplicate regex corpus case: " + row.name)
    }
    names.add(row.name)
    cases.push({
      name: row.name,
      regex: row.regex,
      haystack: @hex.decode(row.haystack_hex),
      matches: row.matches,
      compiles: row.compiles,
      anchored: row.anchored,
      case_insensitive: row.case_insensitive,
      unicode: row.unicode,
      utf8: row.utf8,
      match_limit: @json.from_json(row.match_limit),
      bounds: @json.from_json(row.bounds),
      line_terminator: @json.from_json(row.line_terminator),
    })
  }
  guard cases.length() == 751 else {
    fail("regex corpus must contain all 751 imported cases")
  }
  cases
}
