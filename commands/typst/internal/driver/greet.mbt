// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The greeting shown to users who just type `typst` the first time
// (upstream `typst-cli/src/greet.rs`).

///|
/// The greeting, as upstream prints it without colors (wrapped at 80
/// columns by clap).
let greeting : String = [
  "Welcome to Typst, we are glad to have you here! ❤️", "", "If you are new to Typst, start with the tutorial at ",
  "https://typst.app/docs/tutorial/. To get a quick start with your first project, ",
  "choose a template on https://typst.app/universe/.", "", "Here are the most important commands you will be using:",
  "", "- Compile a file once: typst compile file.typ", "- Compile a file on every change: typst watch file.typ",
  "- Set up a project from a template: typst init @preview/<TEMPLATE>", "", "Learn more about these commands by running typst help.",
  "", "If you have a question, we and our community would be glad to help you out on",
  "the Typst Forum at https://forum.typst.app/.", "", "Happy Typsting!", "",
].join("\n")

///|
/// Greets if not yet greeted. Returns whether it greeted (in which case the
/// program exits successfully).
async fn greet() -> Bool {
  guard @kit.data_dir() is Some(data_dir) else { return false }
  let path = @platform.join(@platform.join(data_dir, "typst"), "greeted")
  let version = typst_version
  let prev_greet = @platform.read_file(path) catch { _ => b"" }
  if prev_greet == @utf8.encode(version) {
    return false
  }
  @platform.write_file(path, @utf8.encode(version)) catch {
    _ => ()
  }
  print_out_lossy(greeting)
  true
}
