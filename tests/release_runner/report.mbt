///|
priv struct CaseReport {
  id : String
  command : String
  version : String
  category : String
  detail : String
} derive(ToJson)

///|
fn report_text(reports : Array[CaseReport]) -> String {
  let output = StringBuilder()
  output.write("# Published-version Runner report\n\n")
  output.write("| Case | Command | Version | Result | Detail |\n")
  output.write("| --- | --- | --- | --- | --- |\n")
  for report in reports {
    output.write(
      "| \{markdown_cell(report.id)} | \{markdown_cell(report.command)} | \{markdown_cell(report.version)} | \{markdown_cell(report.category)} | \{markdown_cell(report.detail)} |\n",
    )
  }
  output.to_string()
}

///|
fn markdown_cell(value : String) -> String {
  value.replace_all(old="|", new="\\|").replace_all(old="\n", new="<br>")
}

///|
async fn write_report(directory : String, reports : Array[CaseReport]) -> Unit {
  if !@fs.exists(directory) {
    @fs.mkdir(directory, recursive=true)
  }
  let json = reports
    .map(report => ToJson::to_json(report).stringify())
    .join("\n") +
    "\n"
  @fs.write_file(
    @path.Path(directory).join(Path("summary.jsonl")).to_string(),
    @utf8.encode(json),
  )
  @fs.write_file(
    @path.Path(directory).join(Path("summary.md")).to_string(),
    @utf8.encode(report_text(reports)),
  )
}
