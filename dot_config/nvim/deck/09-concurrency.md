# Concurrency & atomics

## Threads

```rust
let h = std::thread::spawn(move || work(data));   // needs 'static: move ownership in
let result = h.join().unwrap();                   // Err if the thread panicked

std::thread::scope(|s| {                          // scoped: may borrow locals
    s.spawn(|| sum(&left));
    s.spawn(|| sum(&right));
});                                               // all joined here
```

## Channels

```rust
let (tx, rx) = std::sync::mpsc::channel();        // unbounded, many producers, one consumer
let (tx, rx) = std::sync::mpsc::sync_channel(16); // bounded: send blocks when full
for msg in rx { … }                               // ends when every tx is dropped
```

`crossbeam-channel` adds multi-consumer channels and `select!`.

## Atomics

| Operation | Does |
| --------- | ---- |
| `load(o)` / `store(v, o)` | read / write |
| `swap(v, o)` | write, return the old value |
| `fetch_add(n, o)`, `fetch_sub`, `fetch_or`, `fetch_and`, `fetch_max` | read-modify-write, return the old value |
| `compare_exchange(cur, new, ok, fail)` | write `new` only if the value is `cur`; `Err(actual)` otherwise |
| `compare_exchange_weak(…)` | may fail spuriously; use it inside a retry loop |
| `fetch_update(o1, o2, f)` | CAS loop around a closure |

## Memory orderings

| Ordering | Guarantees | Typical use |
| -------- | ---------- | ----------- |
| `Relaxed` | the operation itself is atomic, no ordering with other memory | counters, statistics, `Arc::clone` |
| `Release` (store) | earlier writes become visible to an `Acquire` load of this value | publishing, unlocking |
| `Acquire` (load) | sees everything the matching `Release` wrote before it | consuming data, locking |
| `AcqRel` | both, for read-modify-write | CAS in lock-free structures |
| `SeqCst` | Acquire/Release plus one global order of all `SeqCst` operations | when in doubt; rare in practice |

**Message passing** (the pattern to remember):

```rust
// thread A                              // thread B
DATA.store(42, Relaxed);                 while !READY.load(Acquire) {}
READY.store(true, Release);              assert_eq!(DATA.load(Relaxed), 42);   // guaranteed
```

**Store buffering**: with `Relaxed` or Acquire/Release, both loads below may read 0. Only `SeqCst` forbids that.

```rust
// thread A: X.store(1); r1 = Y.load();   thread B: Y.store(1); r2 = X.load();
```

## Lock-free building blocks

| Tool | For |
| ---- | --- |
| `crossbeam::epoch` | reclamation: `pin()` a guard, `defer_destroy` instead of `free` |
| `Atomic<T>` · `Shared<'g, T>` · `Owned<T>` | atomic ptr · ptr valid while guarded · unpublished box |
| tag bits | low pointer bits as flags: `shared.tag()`, `with_tag(1)` |
| `crossbeam::utils::CachePadded` | keep hot atomics on separate cache lines (no false sharing) |
| `std::hint::spin_loop()` | tell the CPU you're spinning |
| `loom` | test every interleaving of a concurrent algorithm under the C++ memory model |
| `miri` | catches data races and UB on the paths your tests run |

## Classic hazards

| Hazard | What goes wrong | Defense |
| ------ | --------------- | ------- |
| ABA | CAS succeeds although the value was changed and changed back | epochs / hazard pointers / tagged counters |
| use-after-free | a reader still holds a pointer you freed | epoch reclamation, never free directly |
| deadlock | locks taken in different orders | one global lock order, `try_lock` with backoff |
| wasted spinning | spin loops burn CPU while the holder is descheduled | park after spinning a bit (`parking_lot` does) |
| false sharing | two hot atomics on one cache line | `CachePadded`, `repr(align(64))` |

## See it run: Lockscope

Swap the imports and every lock and atomic gets recorded with its line:

```rust
use labsync::sync::{Arc, Mutex};          // instead of std::sync
use labsync::thread;                      // spawn / spawn_named("worker 1", …)
let _rec = labsync::record("my-run");     // → target/lab/my-run.json
```

| Keys / command | Does |
| ---- | ---- |
| `Space ds` | open a recording from this project in Lockscope (newest first, ✗ = a failing schedule) |
| `lab-view target/lab/x.json` | the same from a shell |
| `labsync::explore("name", 1000, \|\| …)` | try 1000 thread schedules (feature `shuttle`); the first that breaks is saved as `name-failure.json` |
| `LABSYNC_SEED=… cargo run …` | replay exactly that schedule |
| `labsync::note("inserted 5")` | a flag on the thread's lane |

In Lockscope: amber boxes = waiting for a lock, colored bars = holding it, lock rows show who owns it and how long the queue is, atomic rows show every value. Click to pin the cursor, ←/→ steps, space plays.

Examples (`cargo run -p labsync --example …` in genomlysning): `sum` (one shared lock vs local sums), `hand_over_hand` (lock coupling down a list), `racy_counter` and `deadlock` (`--features shuttle`).
