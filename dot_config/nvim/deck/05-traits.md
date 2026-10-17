# Traits & generics

## Derive these when they make sense

| Trait | Gives you | Derive when |
| ----- | --------- | ----------- |
| `Debug` | `{:?}` | almost always |
| `Clone` | `.clone()` | the type should be duplicable |
| `Copy` | implicit copies | small, plain data, no heap, no `Drop` |
| `PartialEq` / `Eq` | `==` | `Eq` when equality is reflexive (no floats) |
| `PartialOrd` / `Ord` | `<`, sorting | field order defines the ordering |
| `Hash` | `HashMap` keys | together with `Eq`, must agree with it |
| `Default` | `T::default()`, `..Default::default()` | there is an obvious empty value |

## Implement these by hand

| Trait | For |
| ----- | --- |
| `Display` | user-facing `{}` text |
| `From<T>` | conversions; gives you `Into` for free |
| `TryFrom<T>` | conversions that can fail |
| `FromStr` | `"42".parse::<T>()` |
| `AsRef<T>` / `Borrow<T>` | cheap reference conversion (`Borrow` must keep `Hash`/`Eq` the same) |
| `Deref` | smart pointers only, not for "inheritance" |
| `Drop` | cleanup when the value dies |
| `Iterator` | just `type Item` + `fn next` |
| `IntoIterator` | so `for x in &my_type` works |
| `Error` | your error types (`Display` + `Debug` first) |

## Marker traits (auto, the compiler decides)

| Trait | Meaning | Not implemented by |
| ----- | ------- | ------------------ |
| `Send` | may move to another thread | `Rc`, raw pointers, `MutexGuard` |
| `Sync` | `&T` may be shared across threads (`T: Sync` ⇔ `&T: Send`) | `Cell`, `RefCell`, `Rc` |
| `Sized` | size known at compile time | `str`, `[T]`, `dyn Trait` |
| `Unpin` | may be moved after being pinned | self-referential futures |
| `Copy` | bitwise copy is a valid clone | anything with `Drop` or heap ownership |

## Generics: three ways to say it

```rust
fn print_all<T: Display>(items: &[T])                // bound inline
fn print_all<T>(items: &[T]) where T: Display        // where clause, nicer when long
fn print_all(items: &[impl Display])                 // impl Trait in argument position
fn evens() -> impl Iterator<Item = u32>              // impl Trait in return: one hidden concrete type
```

## Static vs dynamic dispatch

| | `impl Trait` / generics | `dyn Trait` |
| - | ----------------------- | ----------- |
| Resolved | at compile time (monomorphized) | at run time through a vtable |
| Code size | one copy per type | one copy |
| Speed | inlinable | indirect call |
| Mixed types in one `Vec` | no | yes: `Vec<Box<dyn Trait>>` |
| Pointer | thin | fat (data + vtable) |

A trait is usable as `dyn` (dyn-compatible) if its methods don't return `Self`, take no generic
type parameters, and the trait doesn't require `Self: Sized`. Add `where Self: Sized` to a method to exclude just that method.

## Associated types vs generic parameters

```rust
trait Iterator { type Item; fn next(&mut self) -> Option<Self::Item>; }   // one Item per type
trait From<T> { fn from(value: T) -> Self; }                              // many T per type
```

Use an associated type when there is exactly one natural choice per implementor.

## Blanket and extension impls

```rust
impl<T: Display> ToString for T { … }        // std: every Display type gets to_string()
trait CamelExt { fn camel(&self) -> String; }
impl CamelExt for str { … }                  // add methods to a foreign type via your trait
```

**Orphan rule:** you may implement a trait for a type only if the trait or the type is defined in your crate.
Wrap the foreign type in a newtype (`struct Meters(f64);`) to get around it.

## Trait objects with lifetimes and bounds

```rust
Box<dyn Fn(u32) -> u32 + Send + 'static>    // a boxed closure you can send to a thread
&'a mut dyn Write                           // a borrowed writer
Arc<dyn Handler + Send + Sync>              // shared across threads
```
