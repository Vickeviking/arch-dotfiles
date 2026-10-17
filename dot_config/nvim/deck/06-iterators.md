# Iterators & closures

## Getting an iterator

| Call | Yields | Collection afterwards |
| ---- | ------ | --------------------- |
| `v.iter()` / `for x in &v` | `&T` | still yours |
| `v.iter_mut()` / `for x in &mut v` | `&mut T` | still yours |
| `v.into_iter()` / `for x in v` | `T` | consumed |
| `v.drain(..)` | `T` | emptied, keeps its capacity |
| `map.keys()` / `values()` / `values_mut()` | `&K` / `&V` / `&mut V` | still yours |
| `(0..n)`, `(0..=n).rev()`, `(0..n).step_by(2)` | numbers | |
| `s.chars()` / `s.bytes()` / `s.lines()` / `s.split(',')` | pieces of a string | |
| `iter::once(x)`, `iter::repeat(x)`, `iter::from_fn(f)`, `iter::successors(a, f)` | made up on the fly | |

## Adapters (lazy: nothing runs until consumed)

| Adapter | Does |
| ------- | ---- |
| `map(f)` | transform each item |
| `filter(p)` | keep items where `p(&item)` |
| `filter_map(f)` | map to `Option`, drop the `None`s |
| `flat_map(f)` / `flatten()` | map to many, splice them in |
| `enumerate()` | `(index, item)` |
| `zip(other)` | pairs, stops at the shorter |
| `chain(other)` | one after the other |
| `take(n)` / `skip(n)` | first n / all but first n |
| `take_while(p)` / `skip_while(p)` | while the predicate holds |
| `peekable()` | `.peek()` without consuming |
| `windows(n)` / `chunks(n)` | on slices: overlapping / non-overlapping groups |
| `rev()` | backwards (double-ended iterators) |
| `copied()` / `cloned()` | `&T` → `T` |
| `inspect(f)` | look at items, e.g. to debug a chain |
| `scan(state, f)` | running state, like a fold that yields each step |

## Consumers (these run the chain)

| Consumer | Returns |
| -------- | ------- |
| `collect::<Vec<_>>()` | any `FromIterator`: `Vec`, `String`, `HashMap`, `Result<Vec<_>, E>` |
| `sum()` / `product()` / `count()` | numbers |
| `min()` / `max()` / `min_by_key(f)` | `Option<T>` |
| `fold(init, f)` / `reduce(f)` | one value |
| `any(p)` / `all(p)` | `bool`, stop early |
| `find(p)` / `position(p)` | first match / its index |
| `last()` / `nth(n)` | `Option<T>` |
| `for_each(f)` | `()` |
| `partition(p)` | `(Vec<T>, Vec<T>)` |
| `unzip()` | two collections from pairs |

Collecting into `Result` stops at the first error:

```rust
let nums: Result<Vec<i32>, _> = lines.iter().map(|l| l.parse::<i32>()).collect();
```

## Closures

| Trait | Calls | Captures | Example |
| ----- | ----- | -------- | ------- |
| `Fn` | many times, shared | by `&` | reads `offset` |
| `FnMut` | many times, exclusive | by `&mut` | does `count += 1` |
| `FnOnce` | once | by value, consumes it | calls `drop(buf)` |

Every `Fn` is also `FnMut` and `FnOnce`. Accept the loosest bound you can: `FnOnce` if you call it once.

- Closures capture **only what they use**, and only as strongly as needed (since 2021, per field: `self.a` alone, not all of `self`).
- `move` makes them capture **by value**: needed for threads, tasks and returning closures.
- Each closure has its own anonymous type. Store them with generics, `impl Fn`, or `Box<dyn Fn>`.

```rust
fn make_adder(n: i32) -> impl Fn(i32) -> i32 { move |x| x + n }
let callbacks: Vec<Box<dyn Fn() + Send>> = Vec::new();
```

## Writing your own iterator

```rust
struct Countdown(u32);
impl Iterator for Countdown {
    type Item = u32;
    fn next(&mut self) -> Option<u32> {
        if self.0 == 0 { return None; }
        self.0 -= 1;
        Some(self.0 + 1)
    }
}
// every adapter above now works: Countdown(3).map(|x| x * 2).collect::<Vec<_>>()
```
