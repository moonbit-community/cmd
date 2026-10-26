///|
async fn main {
  let args = @env.args()
  let builder = @ignore.WalkBuilder::new(args[2])
  if args[1] == "visitor" {
    builder
    .threads(40)
    .build_parallel()
    .run(() => {
      _ => {
        println("reached visitor panic")
        abort("oops!")
      }
    })
  } else {
    let mut builds = 0
    builder
    .threads(2)
    .build_parallel()
    .run(() => {
      builds += 1
      if builds == 3 {
        println("reached builder panic")
        abort("builder panic")
      }
      _ => Continue
    })
  }
}
