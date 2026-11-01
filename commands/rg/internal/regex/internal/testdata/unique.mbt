///|
/// One execution represents identical records without discarding corpus names.
pub(all) struct CorpusGroup {
  fixture : TestCase
  names : Array[String]
}

///|
fn corpus_execution_key(tc : TestCase) -> String {
  let key : Json = {
    "regex": tc.regex,
    "haystack": Json(tc.haystack.to_array()),
    "matches": Json(tc.matches),
    "compiles": tc.compiles,
    "anchored": tc.anchored,
    "case_insensitive": tc.case_insensitive,
    "unicode": tc.unicode,
    "utf8": tc.utf8,
    "match_limit": Json(tc.match_limit),
    "bounds": Json(tc.bounds),
    "line_terminator": Json(tc.line_terminator),
    "regex_lite_dialect": tc.name.has_prefix("regex-lite/"),
    "automata_exclusion": Json(exclusion(tc)),
    "meta_exclusion": Json(exclusion(tc, meta=true)),
  }
  key.stringify()
}

///|
/// Retains every semantic field and both engines' name-derived exclusions.
/// The first source record supplies the diagnostic name; all names remain
/// available for failure diagnostics and represented-obligation accounting.
pub fn execution_groups(
  cases : ArrayView[TestCase],
) -> Array[CorpusGroup] raise {
  let indices : Map[String, Int32] = Map([])
  let names : Set[String] = Set([])
  let groups : Array[CorpusGroup] = []
  for tc in cases {
    guard !tc.name.is_empty() && !names.contains(tc.name) else {
      fail("empty or duplicate original corpus name: " + tc.name)
    }
    names.add(tc.name)
    let key = corpus_execution_key(tc)
    match indices.get(key) {
      Some(index) => groups[index].names.push(tc.name)
      None => {
        indices[key] = groups.length()
        groups.push({ fixture: tc, names: [tc.name], })
      }
    }
  }
  groups
}

///|
pub fn alias_count(groups : ArrayView[CorpusGroup]) -> Int32 {
  let mut count = 0
  for group in groups {
    count += group.names.length() - 1
  }
  count
}

///|
pub async fn load_execution_groups() -> Array[CorpusGroup] {
  execution_groups(load())
}
