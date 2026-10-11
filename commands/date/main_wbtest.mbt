///|
test "date formats the Unix epoch in UTC" {
  let value = @time.unix(0L, zone=@time.utc_zone)
  assert_eq(
    format_date(value, "%Y-%m-%d %H:%M:%S %s %z"),
    "1970-01-01 00:00:00 0 +0000",
  )
}

///|
test "date normalizes ISO option spellings" {
  assert_eq(normalize_args(["-u", "-Iseconds"]), ["-u", "--iso=seconds"])
  assert_eq(normalize_args(["--iso-8601=date"]), ["--iso=date"])
}
