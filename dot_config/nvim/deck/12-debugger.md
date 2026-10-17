# Debugger

nvim-dap + nvim-dap-view + codelldb (from mason). The view opens by itself when a session starts. rustaceanvim knows how to start it.
Build without `--release` (or set `debug = true` in the release profile), or variables show as optimized out.

## Keys

| Keys | Does |
| ---- | ---- |
| `Space dd` | pick something to debug: a binary, a test, an example (`:RustLsp debuggables`) |
| `Space dl` | debug the last target again |
| `Space db` / `F9` | toggle a breakpoint on this line |
| `Space dB` | breakpoint with a condition, e.g. `i == 41` |
| `Space dL` | logpoint: print a message instead of stopping (`x is {x}`) |
| `Space dc` / `F5` | start, or continue to the next breakpoint |
| `Space dn` / `F10` | step over the line |
| `Space di` / `F11` | step into the call |
| `Space do` / `F12` | step out of the function |
| `Space dC` | run to the cursor |
| `Space dk` | value of the expression under the cursor in a float |
| `Space dv` | open / close the debug view (scopes, watches, stack, threads, breakpoints, REPL) |
| `Space dw` | add the word under the cursor as a watch |
| `Space dr` | open the REPL |
| `Space dq` | stop debugging |

Inside dap-view: the letters in its top bar switch sections, `g?` lists its keys.
Values appear at the end of each line (dap-view's virtual text) and update on every step.

## A first session

1. Put the cursor in a test, `Space db` on an interesting line.
2. `Space dd` → pick the test. It stops at the breakpoint.
3. `Space dv` to see locals; `F10` / `F11` to walk; `Space dk` on any expression.
4. `Space dq` when done.

## lldb in the REPL

codelldb's REPL takes lldb commands (checked: `v -L` and `bt` work and print into the REPL).

| Command | Does |
| ------- | ---- |
| `bt` / `bt all` | backtrace of this thread / every thread |
| `frame variable` (`v`) | all locals in this frame, `v -L` adds their addresses |
| `v -T node` | a variable with its type |
| `p *node.next.data.p` | follow pointers by hand |
| `memory read -fx -s8 -c4 0x7ffd…` | four 8-byte words of raw memory in hex |
| `x/16xb &v` | 16 bytes at a variable's address |
| `thread list` / `thread select 3` | threads |
| `watchpoint set variable count` | stop when `count` is written |
| `breakpoint set -n rust_panic` | stop on any panic, before unwinding |
| `image lookup -t Node` | the debug info's view of a type |
| `type summary list` | the pretty-printers that are loaded |

## Rust types in the debugger

| You see | It is |
| ------- | ----- |
| `Vec` with `len` and `buf.inner.cap` | expand `[0]…` for the items (Rust's own lldb formatters) |
| `Option` shown as `Some` / `None` | niche-encoded enums are decoded by the formatters |
| `Rc` / `Arc` with `strong` and `weak` | the counts in the heap block |
| `RefCell` with `borrow` | the run-time borrow counter (`-1` = mutably borrowed) |
| `<optimized out>` | a release build; rebuild in debug |
| closure `{closure_env#0}` | the captured variables are its fields |

## Panics and stepping into std

- A panic stops in `rust_panic` if you set `breakpoint set -n rust_panic`; `bt` shows who called.
- Stepping into std needs `rustup component add rust-src` (installed).
- `F12` (step out) gets you back from deep inside std quickly.
