///|
struct Space {
  mut decoded : String?
  data : BytesView?
  terminated : Bool
}

///|
fn Space::from_bytes(data : BytesView, terminated : Bool) -> Space {
  { decoded: None, data: Some(data), terminated, }
}

///|
fn Space::from_text(text : String, terminated : Bool) -> Space {
  { decoded: Some(text), data: None, terminated, }
}

///|
// Only the decoded cache mutates. Hold and pattern spaces may share a value;
// every content change creates a fresh space, retaining the immutable bytes.
fn Space::text(self : Space) -> String {
  match self.decoded {
    Some(text) => text
    None => {
      let text = @bytere.text(self.data.unwrap())
      self.decoded = Some(text)
      text
    }
  }
}

///|
fn Space::append(self : Space, other : Space) -> Space {
  Space::from_text(self.text() + "\n" + other.text(), other.terminated)
}
