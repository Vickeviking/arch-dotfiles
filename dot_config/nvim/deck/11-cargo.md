# Cargo & tools

## Everyday

| Command | Does |
| ------- | ---- |
| `cargo check` | type-check only, fastest feedback |
| `cargo build` / `--release` | debug / optimized build into `target/` |
| `cargo run -- args` | build and run, args after `--` |
| `cargo test` / `cargo test name` | all tests / tests whose name contains `name` |
| `cargo test -- --nocapture` | show `println!` from passing tests |
| `cargo nextest run` | faster test runner, one process per test (used by neotest) |
| `cargo clippy -- -W clippy::pedantic` | lints, stricter set |
| `cargo fmt` | format (also on save via conform) |
| `cargo doc --open` | your crate's docs plus dependencies, offline |
| `cargo add serde -F derive` / `cargo rm x` | edit dependencies |
| `cargo tree -i crate` | why is this crate in my build? |
| `cargo update -p crate` | bump one dependency in the lockfile |
| `cargo clean` | wipe `target/` (it gets big: Arcturon's was 186 GB) |

From nvim: `Space ob` build · `Space or` run · `Space ot` test · `Space tn` nearest test · `Space tf` file tests · `Space Rr` runnables · `Space Rt` testables · `Space Rc` open Cargo.toml · `Space Rp` parent module.

## Seeing what the compiler did

| Command | Shows |
| ------- | ----- |
| `cargo expand` | code after macros (install `cargo-expand`; `Space Rm` does one macro in place) |
| `cargo +nightly rustc -- -Zprint-type-sizes` | size, field offsets and padding of every type in the crate |
| `cargo asm crate::path::fn` | assembly for one function (`cargo-show-asm`) |
| `cargo llvm-lines` | which generic functions bloat compile time |
| `cargo build --timings` | an HTML chart of where build time goes |
| `RUSTFLAGS="--emit=mir" cargo build` | MIR, the form the borrow checker works on |

## Correctness tools

| Tool | Finds |
| ---- | ----- |
| `cargo +nightly miri test` | undefined behavior, out-of-bounds, data races, leaks in unsafe code |
| `loom` | bugs in specific interleavings of concurrent code |
| `cargo fuzz run target` | crashes from random inputs (libFuzzer) |
| `proptest` / `quickcheck` | properties over generated inputs |
| `cargo audit` | dependencies with known vulnerabilities |
| `cargo deny check` | licenses, duplicates, banned crates |

## Performance tools

| Tool | For |
| ---- | --- |
| `cargo flamegraph` | where CPU time goes (perf + SVG) |
| `criterion` | statistically sound benchmarks |
| `perf stat -e cache-misses ./target/release/x` | hardware counters |
| `heaptrack` / `dhat` | allocations: who, how many, how big |
| `hyperfine 'cmd a' 'cmd b'` | compare two commands |

## Toolchains

| Command | Does |
| ------- | ---- |
| `rustup update` | update stable and nightly |
| `cargo +nightly …` | one command on nightly |
| `rust-toolchain.toml` | pin a toolchain per project |
| `rustup component add rust-src miri` | std source (go-to-definition into std) and miri |
| `rustup target add thumbv8m.main-none-eabihf` | cross-compile, e.g. for the Pico 2 (RP2350) |
| `rustup doc --std` | std docs offline in the browser |

## Cargo.toml snippets

```toml
[profile.release]
debug = true            # symbols in release builds: flamegraphs and the debugger can read them
lto = "thin"
codegen-units = 1

[profile.dev.package."*"]
opt-level = 2           # optimize dependencies even in debug builds

[features]
default = []
console = ["dep:console-subscriber"]
```
