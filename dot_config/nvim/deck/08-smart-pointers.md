# Smart pointers & interior mutability

## Pick one

| You need | Use | Thread-safe version |
| -------- | --- | ------------------- |
| one owner, value on the heap (big, recursive, `dyn`) | `Box<T>` | `Box<T>` (if `T: Send`) |
| several owners, read-only | `Rc<T>` | `Arc<T>` |
| several owners, and mutation | `Rc<RefCell<T>>` | `Arc<Mutex<T>>` or `Arc<RwLock<T>>` |
| mutate a `Copy` value through `&` | `Cell<T>` | atomics (`AtomicU64`, …) |
| mutate anything through `&`, checked at run time | `RefCell<T>` | `Mutex<T>` / `RwLock<T>` |
| initialize once, read forever | `OnceCell<T>` | `OnceLock<T>`, `LazyLock<T>` |
| back-pointer that doesn't keep alive | `rc::Weak<T>` | `sync::Weak<T>` |
| owned or borrowed, decided at run time | `Cow<'a, T>` | same |

## Box

```rust
let b = Box::new(5);                          // 8 bytes on the stack, 4 on the heap
enum List { Cons(i32, Box<List>), Nil }       // recursion needs indirection
let shapes: Vec<Box<dyn Shape>> = …;          // different types behind one trait
let leaked: &'static mut T = Box::leak(b);    // never freed, lives forever
```

## Rc and Arc

```rust
let a = Rc::new(vec![1, 2]);
let b = Rc::clone(&a);           // bumps the strong count, no deep copy
Rc::strong_count(&a);            // 2
let w = Rc::downgrade(&a);       // Weak: doesn't keep the value alive
w.upgrade();                     // Some(Rc) while any strong owner exists
Rc::make_mut(&mut a);            // clone-on-write: copies only if shared
Arc::try_unwrap(arc)             // get the T back if you're the last owner
```

Heap block: `{ strong, weak, value }`. `weak` starts at 1, an implicit weak owned by all the
strong owners together. The value drops when `strong` hits 0; the block is freed when `weak` hits 0.
**Cycles of `Rc` leak.** Make the back-edges (child → parent) `Weak`.

`Arc` is the same with atomic counts: clone is `fetch_add(Relaxed)`, the last drop
uses `Release` then an `Acquire` fence before freeing.

## Cell and RefCell (single thread)

```rust
let c = Cell::new(1);
c.set(2); c.get(); c.replace(3); c.take();   // copy in, copy out: never a reference inside

let r = RefCell::new(vec![]);
r.borrow_mut().push(1);          // panics if any other borrow is alive
let len = r.borrow().len();      // shared borrow, ends with the statement
r.try_borrow_mut()               // Err instead of a panic
```

The borrow counter: `0` free, `1, 2, …` shared borrows, `-1` one mutable borrow.
Keep `borrow()` guards short: holding one across a call that borrows mutably panics at run time.

## Mutex and RwLock (threads)

```rust
let m = Arc::new(Mutex::new(0));
{
    let mut g = m.lock().unwrap();   // std: Err if a previous holder panicked (poisoned)
    *g += 1;
}                                    // guard dropped, lock released
let n = *m.lock().unwrap();
```

| | `std::sync` | `parking_lot` |
| - | ----------- | ------------- |
| `lock()` returns | `LockResult<Guard>` | `Guard` directly |
| Poisoning | yes | no |
| `Mutex<()>` size | 8 | 1 byte |
| Extras | | `try_lock_for(dur)`, upgradable read locks, fair unlock |

- Never hold a guard across `.await`: use `tokio::sync::Mutex` there, or drop the guard first.
- Deadlock recipe: two locks taken in different orders. Always lock in one global order.
- `RwLock` helps only when reads dominate and are long; otherwise a `Mutex` is faster.

## Cow

```rust
fn normalize(s: &str) -> Cow<'_, str> {
    if s.contains(' ') { Cow::Owned(s.replace(' ', "_")) } else { Cow::Borrowed(s) }
}
```
