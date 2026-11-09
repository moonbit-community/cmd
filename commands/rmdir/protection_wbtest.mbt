///|
test "deletion path protection rejects roots and working-directory ancestors" {
  inspect(protects_working_directory("."), content="true")
  inspect(protects_working_directory("./"), content="true")
  inspect(protects_working_directory(".."), content="true")
  inspect(protects_working_directory("../outside"), content="false")
  inspect(protects_working_directory("/"), content="true")
}

///|
test "deletion path protection permits ordinary descendants" {
  inspect(protects_working_directory("file"), content="false")
  inspect(protects_working_directory("directory/file"), content="false")
  inspect(protects_working_directory("./directory"), content="false")
}
