# Async & tokio

## The model in four lines

- An `async fn` returns a **future**: a state machine that does nothing until polled.
- `.await` polls it; if it isn't ready, the task yields and the thread runs something else.
- A **runtime** (tokio) owns the threads and polls tasks when their I/O or timers are ready.
- A **task** is a future handed to the runtime with `spawn`. It is the async version of a thread, and much cheaper.

## Starting

```rust
#[tokio::main]                                    // multi-threaded runtime
async fn main() -> anyhow::Result<()> { … }

#[tokio::main(flavor = "current_thread")]         // single thread, no Send needed for local work
#[tokio::test] async fn it_works() { … }
```

## Doing several things

| Want | Use |
| ---- | --- |
| run in the background | `let h = tokio::spawn(fut);` then `h.await?` |
| wait for all, fixed set | `let (a, b) = tokio::join!(fa, fb);` |
| wait for all, fail fast | `tokio::try_join!(fa, fb)?` |
| first one wins, cancel the rest | `tokio::select! { x = fa => …, _ = sleep(d) => … }` |
| many tasks, collect as they finish | `JoinSet::new()`, `set.spawn(f)`, `while let Some(r) = set.join_next().await` |
| a deadline | `tokio::time::timeout(dur, fut).await` |
| blocking or CPU-heavy work | `tokio::task::spawn_blocking(heavy)` |

## Channels and sync

| Type | Shape |
| ---- | ----- |
| `mpsc::channel(n)` | many senders, one receiver, bounded |
| `oneshot::channel()` | one value, once (request → reply) |
| `broadcast::channel(n)` | every receiver gets every message |
| `watch::channel(v)` | latest value only (config, state) |
| `tokio::sync::Mutex` | a lock you may hold across `.await` |
| `Semaphore` | limit concurrency (e.g. 10 requests at a time) |
| `Notify` | wake a waiting task |

## Send and 'static

`tokio::spawn` needs `F: Future + Send + 'static`:

- `'static`: move owned data in (`move` blocks, `Arc`), no borrows of locals.
- `Send`: everything alive **across an `.await`** must be `Send`. An `Rc` or a `std::sync::MutexGuard` held over an await breaks it.

```rust
let n = { let g = state.lock().unwrap(); g.count };   // guard dropped before the await
do_io(n).await;
```

## Cancellation

Dropping a future cancels it at its current `.await`. That happens to the losing branches of `select!`,
on `timeout`, and on `JoinHandle::abort()`.
Code between two awaits always runs to the next await, but a function may stop at any await.
Keep state consistent at each await point.

## Pitfalls

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| everything stalls | a blocking call inside a task (sleep, heavy loop, sync I/O) | `spawn_blocking`, async I/O |
| "future is not Send" | `Rc` or a std guard alive across `.await` | `Arc`, drop guards first |
| task silently dies | panic inside a spawned task | check the `JoinHandle` result |
| nothing happens | future created but never awaited or spawned | `.await` it (the compiler warns: `unused_must_use`) |
| `async fn` in `dyn Trait` | async methods aren't dyn-compatible | generics, or `Pin<Box<dyn Future>>` |

## Seeing inside

`tokio-console` (add `console-subscriber`) shows live tasks, their state and wakeups. The debugger tab covers stepping.
