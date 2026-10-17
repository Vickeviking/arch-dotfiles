# Errors

## The two kinds

| | Recoverable | Bug |
| - | ----------- | --- |
| Type | `Result<T, E>`, `Option<T>` | panic |
| Use for | files, input, network, parsing | broken invariants, "can't happen" |
| Tools | `?`, combinators, `match` | `unwrap`, `expect("why it holds")`, `assert!`, `unreachable!` |

## The `?` operator

```rust
fn read_port(path: &str) -> Result<u16, Box<dyn Error>> {
    let text = std::fs::read_to_string(path)?;   // on Err: convert with From, return early
    let port = text.trim().parse::<u16>()?;
    Ok(port)
}
```

`?` works on `Result` in functions returning `Result`, and on `Option` in functions returning `Option`.
Mixing them needs a bridge: `opt.ok_or(MyError::Missing)?` or `res.ok()?`.

## Option combinators

| Call | Gives |
| ---- | ----- |
| `map(f)` | `Some(f(x))` or `None` |
| `and_then(f)` | chain another `Option`-returning step |
| `filter(p)` | `None` unless `p(&x)` |
| `unwrap_or(d)` / `unwrap_or_else(f)` / `unwrap_or_default()` | the value or a fallback |
| `ok_or(e)` / `ok_or_else(f)` | `Option` → `Result` |
| `as_ref()` / `as_mut()` / `as_deref()` | borrow inside (`Option<String>` → `Option<&str>` with `as_deref`) |
| `take()` / `replace(x)` | move out of an `&mut Option` |
| `get_or_insert_with(f)` | fill if empty, return `&mut T` |
| `zip(other)` | `Some((a, b))` if both are `Some` |
| `is_some_and(p)` / `is_none_or(p)` | test the inside without unwrapping |

## Result combinators

| Call | Gives |
| ---- | ----- |
| `map(f)` / `map_err(f)` | transform the `Ok` / the `Err` |
| `and_then(f)` | chain a fallible step |
| `or_else(f)` | try a fallback on error |
| `unwrap_or_else(f)` | value or computed fallback |
| `ok()` / `err()` | `Result` → `Option` |
| `inspect_err(f)` | log an error without changing it |
| `is_ok_and(p)` | test the value |

## Pattern matching

```rust
let Some(user) = find(id) else { return Err(NotFound) };   // let-else: bail out early
if let Ok(n) = s.parse::<i32>() { … }
match res { Ok(v) => v, Err(e) if e.kind() == ErrorKind::NotFound => default(), Err(e) => return Err(e.into()) }
```

## Error types

**Libraries: `thiserror`**, an enum callers can match on:

```rust
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("config file missing: {0}")]
    Missing(PathBuf),
    #[error("bad port")]
    Port(#[from] std::num::ParseIntError),   // #[from] makes ? convert automatically
}
```

**Applications: `anyhow`**, one error type with context:

```rust
use anyhow::{Context, Result, bail};
fn load() -> Result<Config> {
    let s = fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    if s.is_empty() { bail!("empty config"); }
    Ok(toml::from_str(&s)?)
}
```

`main` can return `Result<(), anyhow::Error>`: the error and its context chain print on exit.

## Panics

- `RUST_BACKTRACE=1 cargo run` shows where it panicked.
- A panic in a thread surfaces as `Err` from `handle.join()`.
- A panic while holding a `std::sync::Mutex` poisons it (`lock()` returns `Err`); `parking_lot` mutexes don't poison.
- Prefer `expect("the queue is never empty here")` over `unwrap()`: the message documents the invariant.
