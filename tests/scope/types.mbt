///|
pub(all) struct TreeFile {
  path : String
  mode : String
  blob : String
  content : Bytes
}

///|
pub(all) struct TreeSnapshot {
  tree : String
  files : Array[TreeFile]
}

///|
pub(all) struct GitChange {
  status : String
  old_path : String
  new_path : String
  old_mode : String
  new_mode : String
  old_blob : String
  new_blob : String
} derive(ToJson, FromJson, Eq, Debug)

///|
// A local owner is a repository-relative package directory. External nodes
// retain the resolved module coordinate and have an empty owner.
pub(all) struct DependencyNode {
  id : String
  owner : String
  module_name : String
  version : String
  source : String
  backends : Array[String]
} derive(ToJson, FromJson, Eq, Debug)

///|
pub(all) struct DependencyEdge {
  from : String
  to : String
  import_alias : String
  kinds : Array[String]
  backends : Array[String]
} derive(ToJson, FromJson, Eq, Debug)

///|
pub(all) struct DependencyGraph {
  nodes : Array[DependencyNode]
  edges : Array[DependencyEdge]
  uncertainties : Array[String]
} derive(ToJson, FromJson, Eq, Debug)

///|
pub(all) struct BehaviorRequirement {
  behavior_id : String
  case_id : String
  command : String
  backends : Array[String]
  evidence : Array[String]
  observations : Array[String]
  platforms : Array[String]
  oracle_profile : String
} derive(ToJson, FromJson, Eq, Debug)

///|
pub(all) struct Selection {
  mode : String
  reasons : Array[String]
  changed_paths : Array[String]
  commands : Array[String]
  behaviors : Array[String]
  packages : Array[String]
  core_packages : Array[String]
  build_prerequisites : Array[String]
  case_ids : Array[String]
  published_coordinates : Array[String]
  affected_options : Array[String]
  affected_operands : Array[String]
  requirements : Array[BehaviorRequirement]
} derive(ToJson, FromJson, Eq, Debug)

///|
pub(all) struct HumanExtra {
  reason : String
  commands : Array[String]
  behaviors : Array[String]
  packages : Array[String]
  case_ids : Array[String]
  backends : Array[String]
  evidence : Array[String]
  observations : Array[String]
} derive(ToJson, FromJson, Eq, Debug)

///|
pub fn sorted_strings(values : Array[String]) -> Array[String] {
  values.sort_by((left, right) => left.lexical_compare(right))
  let result : Array[String] = []
  for value in values {
    if result.last() != Some(value) {
      result.push(value)
    }
  }
  result
}
