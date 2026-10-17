# Types & layout

Sizes are for x86-64 (8-byte pointers), checked with `size_of` on rustc 1.99.
`print-type-sizes` shows any type of yours: `cargo +nightly rustc -- -Zprint-type-sizes`.

## Sizes worth knowing

| Type | Size | Why |
| ---- | ---- | --- |
| `()`, `struct S;`, `PhantomData<T>` | 0 | zero-sized: no bytes at all |
| `bool`, `u8`, `Option<bool>` | 1 | `Option<bool>` uses the spare value 2 for `None` |
| `char` | 4 | a Unicode scalar value, not a byte |
| `usize`, `&T`, `Box<T>`, `*const T` | 8 | one pointer (T sized) |
| `Option<&T>`, `Option<Box<T>>`, `Option<NonZeroU64>` | 8 | **niche**: null / 0 means `None` |
| `Option<u64>` | 16 | no spare bit pattern, so a separate tag plus padding |
| `&[T]`, `&str`, `Box<[T]>` | 16 | fat pointer: ptr + length |
| `&dyn Trait`, `Box<dyn Trait>` | 16 | fat pointer: ptr + vtable |
| `Vec<T>`, `String` | 24 | ptr + capacity + length |
| `Option<Vec<T>>`, `Option<String>` | 24 | niche in the capacity (never above `isize::MAX`) |
| `Rc<T>`, `Arc<T>` | 8 | pointer to { strong, weak, value } |
| `Cell<u64>` | 8 | no overhead |
| `RefCell<u64>` | 16 | borrow counter + value |
| `std::sync::Mutex<u64>` | 16 | futex word + poison flag + value |
| `parking_lot::Mutex<()>` | 1 | one state byte |

## Rules of layout

- **Size is a multiple of alignment.** `(u64, u8)` is 16 bytes: 9 of data, 7 of padding.
- **`repr(Rust)`** (the default) may reorder fields to cut padding. Field order in memory is not your source order.
- **`repr(C)`** keeps source order with C padding rules: required for FFI and hardware registers.
- **`repr(transparent)`**: same layout as the single non-zero-sized field.
- **`repr(u8)` / `repr(i32)`** on an enum fixes the tag type.
- **`repr(packed)`**: no padding, unaligned fields. Taking `&field` is an error; read with `{ s.field }` or `ptr::read_unaligned`.
- **`repr(align(64))`**: at least 64-byte aligned, e.g. to keep two atomics on separate cache lines.

## Example from your hashmap

```rust
struct Node<String, u64> { hash: u64, key: String, value: Atomic<u64>, next: Atomic<Node>, lock: Mutex<()> }
// measured: 56 bytes, align 8
// offset  0  key   (24)   ← moved first by the compiler
// offset 24  hash  (8)
// offset 32  value (8)
// offset 40  next  (8)
// offset 48  lock  (1) + 7 bytes padding
// BinEntry<String, u64> is also 56: the tag hides in String's capacity niche.
// BinEntry<u64, u64> is 48 vs Node's 40: no niche, so a whole word for the tag.
```

## Enums

```rust
enum E { A(u32), B(u64), C }    // 16: 8 for the largest payload + tag, rounded to align 8
enum Never {}                   // 0, and no value can exist: a function returning it never returns
```

A tag can live inside a field's impossible values (a niche): null pointers,
`bool` values above 1, `char` above `0x10FFFF`, `NonZero*` zero, capacities above `isize::MAX`.

## Dynamically sized types

`str`, `[T]` and `dyn Trait` have no size known at compile time (`!Sized`). They always live behind
a pointer that carries the missing piece: the length or the vtable.
Generic parameters are `Sized` by default; write `T: ?Sized` to accept them.

```rust
fn show<T: ?Sized + Debug>(x: &T) { … }    // works for &str, &[u8], &dyn Debug too
```

## Conversions

| Want | Use |
| ---- | --- |
| lossless number conversion | `u64::from(x)`, `x.into()` |
| checked narrowing | `u8::try_from(x)?` |
| truncating / wrapping cast | `x as u8` (silent) |
| bytes ↔ integer | `u32::from_le_bytes(b)`, `x.to_be_bytes()` |
| `&str` ↔ `String` | `s.to_owned()` / `s.as_str()` / `&s[..]` |
| `&[u8]` → `&str` | `std::str::from_utf8(b)?` |
| reinterpret bits | `f32::to_bits`, `bytemuck::cast` (safe); `transmute` only with matching `repr` |
