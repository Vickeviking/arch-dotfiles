# Debugger

nvim-dap + nvim-dap-view + codelldb (from mason), with X-ray in between to show memory. The view opens by itself when a session starts. rustaceanvim knows how to start it.
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
| `Space dx` | X-ray: the full memory map (stack, heap, who points where) |
| `Space dm` | X-ray sidebar show / hide |
| `Space dW` | X-ray window open / close (opens by itself on a second monitor) |
| `Space dX` | X-ray off for this nvim (inline notes, sidebar, Why not? hints); on again next start |

Inside dap-view: the letters in its top bar switch sections, `g?` lists its keys.
Values appear at the end of each `let` line and update on every step: X-ray's notes when it runs (Rust), dap-view's otherwise.

## X-ray

`xray-dap` sits between nvim-dap and codelldb and snapshots memory at every stop. Every Rust session goes through it.

At the end of each `let` line you see what it holds and where it points:

```text
let v = vec![7, 8, 9];       [7, 8, 9] ─▶ heap [u32; 3] · 12 B  len 3 · cap 3
let r = &v;                  ─▷ v
let alias = Rc::clone(&c);   strong 2 · weak 1 ═▶ *c  borrowed mut
let words = vec![…];         ↷ moved into taken
```

| Mark | Means |
| ---- | ----- |
| `─▶` | owns: a Vec/String buffer, a Box |
| `═▶` | shares: an Rc / Arc (the box holds the counts) |
| `┄▶` | weak: a Weak, doesn't keep it alive |
| `─▷` | borrows: `&T`, `Ref` |
| `━▶` | borrows mut: `&mut T`, `RefMut`, `MutexGuard` |
| `✱` | changed since the last stop (`was …` after it) |
| `⚠` | a Vec reallocated: references into the old buffer would dangle |
| `↷` | moved from: both names hold the bits, only the new one counts |
| `░` | spare capacity in a buffer |

On a wide screen the **sidebar** opens by itself at the first stop: the memory map in a split on the right, following every step without taking focus. `q` in it hides it for the session, Enter opens the full panel.

Crates read the way you'd say them, not as their internals:

| Crate | Shows |
| ----- | ----- |
| parking_lot | `locked · threads parked`, `2 readers`, guards as borrows |
| crossbeam-epoch | `Atomic`/`Shared`/`Owned` followed to their target, `tag 1` |
| tokio | `task worker · idle on recv`, mpsc `1/8 queued`, oneshot, Mutex, Notify |
| serde_json / ron | the value as JSON / RON |
| anyhow | `saving config.toml ← disk full` |
| tracing | `span "request" · INFO`, levels |
| http, hyper, reqwest, url, bytes | `404 Not Found`, `GET /health`, headers, URL parts |
| axum, sqlx, rayon | routes, `0/5 connections`, worker threads |
| uuid, chrono, rand | `550e8400-…`, `2026-10-17 20:43:12 UTC`, `1h 30m 5s` |
| ConcurrentHashMap ports | bins, entries, `Moved` forwarding mid-resize |

Any other crate reads as its fields, tidied. For your own types add a lens in `~/.config/xray/lenses.toml` (examples inside); it's read at every stop.

**The window** (`xray-window`) is the memory map drawn properly: frames as cards, heap blocks in columns by depth, curved arrows, a timeline of stops. With a second monitor connected it opens there by itself at the first stop and leaves focus in nvim. Its keys: `h`/`l` stops, `j`/`k` scroll, `f` follow live, `d` changes on/off, `?` keys, `q` close.

`Space dx` opens the full panel. Its tabs:
- **Memory**: frames as cards on the left, heap blocks as boxes on the right, arrows between them. Boxes that point at each other name each other by letter.
- **Frames**: every thread, and what the others are waiting on.
- **Heap**: each block's address, size, contents and who points at it.
- **Changes**: what this step did and why it matters.

Enter jumps to the declaration or frame. `[` / `]` step back and forward through every stop of the session (a TIMELINE strip on top shows where you are; reallocations are amber); inline notes stay on the live stop. Borrows don't exist at run time (references are plain pointers), so X-ray shows who points where. Why the compiler refuses something is a compile-time question: `Space Rw` on the error (see Ownership).

## A first session

1. Put the cursor in a test, `Space db` on an interesting line.
2. `Space dd` → pick the test. It stops at the breakpoint.
3. `Space dv` to see locals; `F10` / `F11` to walk; `Space dk` on any expression.
4. Stuck on what you see? `Space Space` asks Claude with X-ray's view of the stack and heap attached.

Threads and locks over time (not one stop): `Space ds` opens a labsync recording in Lockscope (see Concurrency).

**Structure movie** (`Space dM`): every stop of the session so far as one animated page in the browser. Lists come out as chains, trees as trees (left/right from the field names), other data in columns by distance from the stack. Nodes slide when links change, new ones grow out of their parent (green), changed ones glow (orange) with what changed in words (`Node 8: next → 9`), freed ones fade (red). ←/→ steps, space plays. From a shell: `xray-movie` (newest session) or `xray-movie DIR` (recorded stops).
5. `Space dq` when done.

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
| `RefCell` with `borrow` | the run-time borrow counter (`-1` = mutably borrowed); the formatter can say `borrow=0` when it isn't, X-ray reads the real field |
| `<optimized out>` | a release build; rebuild in debug |
| closure `{closure_env#0}` | the captured variables are its fields |

## Panics and stepping into std

- A panic stops in `rust_panic` if you set `breakpoint set -n rust_panic`; `bt` shows who called.
- Stepping into std needs `rustup component add rust-src` (installed).
- `F12` (step out) gets you back from deep inside std quickly.
