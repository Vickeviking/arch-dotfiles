# Ownership & borrowing

## The three rules

1. Every value has exactly **one owner**.
2. When the owner goes out of scope, the value is **dropped** (destructors run, memory is freed).
3. At any moment you may have **either** any number of `&T` **or** exactly one `&mut T`. Never both.

`&T` means *shared*, not "immutable": `Cell`, `RefCell`, `Mutex` and atomics mutate through `&T`.
`&mut T` means *unique*: nobody else can see the value while you hold it.

## Move, copy, clone

| Situation | What happens |
| --------- | ------------ |
| `let b = a;` with `a: String` | **move**: `a` is no longer usable, no bytes are copied on the heap |
| `let b = a;` with `a: i32` | **copy**: the type is `Copy`, both stay usable |
| `let b = a.clone();` | explicit deep copy, both usable |
| `f(a)` | moves `a` into `f` (or copies it if `Copy`) |
| `f(&a)` / `f(&mut a)` | lends it; `a` is yours again after the call |
| a `move` closure | captured variables are moved into the closure |

A type can be `Copy` only if all its fields are `Copy` and it has no `Drop`.

## Borrows end at their last use (NLL)

```rust
let mut v = vec![1, 2, 3];
let first = &v[0];        // shared borrow starts
println!("{first}");      // ...and ends here, its last use
v.push(4);                // fine: no borrow is alive any more
```

Swap the last two lines and it fails: `first` would still be alive during `push`,
and `push` may reallocate, leaving `first` pointing at freed memory.

## The errors you'll meet

| Code | What happened | Usual fix |
| ---- | ------------- | --------- |
| E0382 | used a value after it moved | borrow (`&x`), `.clone()`, or restructure |
| E0499 | two `&mut` alive at once | shorten one, split the borrow, use indices |
| E0502 | a `&` alive while taking `&mut` | finish with the `&` first, or copy the value out |
| E0505 | moved a value that is still borrowed | end the borrow before the move |
| E0506 | wrote to a value that is borrowed | end the borrow first |
| E0597 | a reference outlives its value | own the data, or move the value up a scope |
| E0716 | a temporary dropped while borrowed | bind the temporary to a `let` first |
| E0373 | a thread or task borrows locals | `move` closure, or `thread::scope` |

Rest the cursor on any line of a borrow error and the timeline draws itself: a mark at the end of each line involved (┏ borrow starts, ┗ last use, ✗ the clash) and the story under the error. `Space Rw` (**Why not?**) redraws it as a timeline: a bar per borrow from where it starts to its last use, a bar per value from its `let` to where it's dropped or moved, a ✗ where they clash, then the rule in plain words and ways out. `a` there lists rust-analyzer's fixes (the `.clone()` or `move` rustc suggests).
`Space Rd` renders the full diagnostic, `Space Re` explains the error code.

## Splitting borrows

```rust
let (left, right) = slice.split_at_mut(mid);    // two &mut, no overlap
let Point { x, y } = &mut p;                     // borrow fields separately
std::mem::take(&mut self.buf);                   // move out, leave Default behind
std::mem::replace(&mut self.state, State::Idle); // move out, put something back
std::mem::swap(&mut a, &mut b);
```

Borrowing two fields of `self` in one method is fine; calling a `&mut self`
method while holding a borrow of a field is not. The method borrows *all* of `self`.

## Lifetimes in signatures

```rust
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str   // result lives as long as the shorter input
fn first_word(s: &str) -> &str                      // elided: output tied to the one input
fn name(&self) -> &str                              // elided: output tied to self
struct Parser<'src> { input: &'src str }            // a struct holding a borrow
fn spawn<F: FnOnce() + Send + 'static>(f: F)        // 'static: owns everything it uses
```

`T: 'static` does not mean "lives forever". It means "contains no borrows shorter than `'static`".
A `String` is `'static`; a `&'a str` is not.

## Patterns and references

| Pattern | Binding gets |
| ------- | ------------ |
| `match &opt { Some(x) => … }` | `x: &T` (default binding mode) |
| `if let Some(ref mut x) = opt` | `x: &mut T`, `opt` keeps the value |
| `for x in &v` / `&mut v` / `v` | `&T` / `&mut T` / `T` (consumes `v`) |
| `opt.as_ref()` / `as_mut()` | `Option<&T>` / `Option<&mut T>` without moving |
| `opt.take()` | moves the value out, leaves `None` |

## See it live: RustOwl

Rest the cursor on a variable for half a second and RustOwl underlines its story.
`Space Ro` turns it on and off for the buffer.

| Underline | Means |
| --------- | ----- |
| green | the value is alive here (wavy: alive on some paths only) |
| blue | borrowed with `&` |
| magenta | borrowed with `&mut` |
| orange | moved out here |
| yellow | passed into a call |
| red | a borrow that outlives the value: this is what the error is about |
