///|
test "normal edits retain byte records and missing line terminators" {
  assert_eq(
    normal(edits(lines(b"a"), lines(b"a\n"))),
    b"1c1\n< a\n\\ No newline at end of file\n---\n> a\n",
  )
  assert_eq(normal(edits(lines(b""), lines(b"a\n"))), b"0a1\n> a\n")
  assert_eq(normal(edits(lines(b"a\n"), lines(b""))), b"1d0\n< a\n")
}

///|
test "edit scripts reconstruct both sides with minimum edit count" {
  for mask in 0..<256 {
    let a = Array::makei(4, i => Line::{
      value: if (mask & (1 << i)) == 0 {
        "a"
      } else {
        "b"
      },
      terminated: true,
    })
    let b = Array::makei(4, i => Line::{
      value: if (mask & (1 << (i + 4))) == 0 {
        "a"
      } else {
        "b"
      },
      terminated: true,
    })
    let changes = edits(a, b)
    let left : Array[Line] = []
    let right : Array[Line] = []
    let mut cost = 0
    for change in changes {
      match change {
        Equal(line) => {
          left.push(line)
          right.push(line)
        }
        Remove(line) => {
          left.push(line)
          cost += 1
        }
        Add(line) => {
          right.push(line)
          cost += 1
        }
      }
    }
    assert_eq(left, a)
    assert_eq(right, b)
    let dp = Array::makei(5, _ => Array::make(5, 0))
    for i in 0..<5 {
      dp[i][0] = i
      dp[0][i] = i
    }
    for i in 1..<5 {
      for j in 1..<5 {
        dp[i][j] = if a[i - 1] == b[j - 1] {
          dp[i - 1][j - 1]
        } else {
          1 + Int::min(dp[i - 1][j], dp[i][j - 1])
        }
      }
    }
    assert_eq(cost, dp[4][4])
  }
}
