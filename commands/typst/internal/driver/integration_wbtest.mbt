///|
async test "PDF export preserves two pages and reports failed output" {
  let directory = @test_fs.tmpdir(prefix="cmd-typst-pdf-")
  defer @test_fs.rmdir(directory, recursive=true)
  let input = directory + "/input.typ"
  @test_fs.write_file(input, "First page\n#pagebreak()\nSecond page\n")
  let output = directory + "/output.pdf"
  assert_eq(
    run_main([
      "compile", "--ignore-system-fonts", "--creation-timestamp=0", input, output,
    ]),
    0,
  )
  let bytes = @test_fs.read_file(output).binary()
  let document = @pdf_read.pdf_read_document_from_bytes(bytes)
  assert_eq(@pdf_read.pdf_pages_of_pagetree(document).length(), 2)
  assert_eq(
    run_main([
      "compile",
      "--ignore-system-fonts",
      input,
      directory + "/missing/out.pdf",
    ]),
    1,
  )
  assert_false(@test_fs.exists(directory + "/missing/out.pdf"))
  assert_eq(
    @test_fs.read_file(input).text(),
    "First page\n#pagebreak()\nSecond page\n",
  )
}

///|
async test "PNG export preserves requested physical dimensions and page selection" {
  let directory = @test_fs.tmpdir(prefix="cmd-typst-png-")
  defer @test_fs.rmdir(directory, recursive=true)
  let input = directory + "/input.typ"
  @test_fs.write_file(
    input,
    "#set page(width:20pt,height:10pt,margin:0pt)\n" +
    "#rect(width:20pt,height:10pt,fill:black,stroke:none)\n" +
    "#pagebreak()\n#rect(width:20pt,height:10pt,fill:white,stroke:none)\n",
  )
  assert_eq(
    run_main([
      "compile",
      "--ignore-system-fonts",
      "--ppi=72",
      "--pages=2",
      input,
      directory + "/page-{p}.png",
    ]),
    0,
  )
  assert_false(@test_fs.exists(directory + "/page-1.png"))
  let bytes = @test_fs.read_file(directory + "/page-2.png").binary()
  assert_eq(bytes[:8].to_owned(), b"\x89PNG\r\n\x1a\n")
  assert_eq(bytes[12:24].to_owned(), b"IHDR\x00\x00\x00\x14\x00\x00\x00\x0a")
}
