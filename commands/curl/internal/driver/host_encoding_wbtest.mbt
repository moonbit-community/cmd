///|
test "URL host locale follows LC_ALL LC_CTYPE and LANG precedence" {
  let names = ["LC_ALL", "LC_CTYPE", "LANG"]
  let original = names.map(name => @env.get_env_var(name))
  defer (for index, name in names {
    match original[index] {
      Some(value) => @env.set_env_var(name, value)
      None => @env.unset_env_var(name)
    }
  })
  for
    (all, ctype, lang, expected) in [
      ("C", "C.UTF-8", "en_US.UTF-8", false),
      ("POSIX", "", "C.UTF-8", false),
      ("C.UTF-8", "C", "C", true),
      ("", "zh_CN.UTF-8", "C", true),
      ("", "", "en_US.utf8@modifier", true),
      ("", "", "", false),
      ("en_US.ISO-8859-1", "", "", false),
    ] {
    @env.set_env_var("LC_ALL", all)
    @env.set_env_var("LC_CTYPE", ctype)
    @env.set_env_var("LANG", lang)
    assert_eq(utf8_hosts(), expected)
  }
}
