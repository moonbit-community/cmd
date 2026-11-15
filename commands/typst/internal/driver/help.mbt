///|
let command_help : String = metadata_help()
  .strip_suffix("\n")
  .unwrap()
  .to_owned()
