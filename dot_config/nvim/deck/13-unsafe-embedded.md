# Unsafe & embedded

## What `unsafe` unlocks (and nothing else)

1. Dereference a raw pointer.
2. Call an `unsafe fn` (including FFI).
3. Access a `static mut`, or implement an `unsafe trait` (`Send`, `Sync`).
4. Access a `union` field.

The borrow checker still runs inside `unsafe`. You promise the compiler the invariants it can't check.
Write a `// SAFETY:` comment above every `unsafe` block saying why it holds.

## Undefined behavior to never cause

- a dangling, unaligned or null reference (even if never read)
- two `&mut` to the same memory alive at once, or a `&mut` while a `&` is in use
- reading uninitialized memory as a value (use `MaybeUninit`)
- an invalid value: `bool` that isn't 0/1, an enum with a wrong tag, a `&str` that isn't UTF-8
- a data race
- `transmute` between types whose layouts aren't guaranteed to match

Run `cargo +nightly miri test` on anything with `unsafe` in it.

## Raw pointers

```rust
let p: *const u32 = &x;            // making a raw pointer is safe
let q = &raw mut buf[0];           // without creating a reference first
unsafe {
    let v = *p;                    // dereferencing is not
    q.add(1).write(7);             // pointer arithmetic in units of T
    let n = NonNull::new(q).unwrap();
}
ptr::read(p) / ptr::write(q, v)    // move bits without running Drop
ptr::copy_nonoverlapping(src, dst, n)
slice::from_raw_parts(ptr, len)    // you promise: valid, aligned, initialized, not mutated meanwhile
```

## MaybeUninit

```rust
let mut buf: [MaybeUninit<u8>; 64] = [const { MaybeUninit::uninit() }; 64];
buf[0].write(1);
let init: u8 = unsafe { buf[0].assume_init() };   // only after writing it
```

## FFI

```rust
#[repr(C)]
struct Point { x: i32, y: i32 }

unsafe extern "C" {
    fn abs(x: i32) -> i32;
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_add(a: i32, b: i32) -> i32 { a + b }
```

`CStr` / `CString` for C strings, `bindgen` to generate bindings from headers, `cbindgen` for the other way.

## Embedded (no_std)

```rust
#![no_std]
#![no_main]

use embassy_executor::Spawner;
use embassy_time::Timer;
use {defmt_rtt as _, panic_probe as _};

#[embassy_executor::main]
async fn main(_spawner: Spawner) {
    let p = embassy_rp::init(Default::default());
    let mut led = embassy_rp::gpio::Output::new(p.PIN_25, embassy_rp::gpio::Level::Low);
    loop {
        led.toggle();
        Timer::after_millis(500).await;
        defmt::info!("blink");
    }
}
```

| Piece | Role |
| ----- | ---- |
| `#![no_std]` | only `core` (and `alloc` if you add an allocator) |
| PAC → HAL → BSP | register access → safe drivers → board pin names |
| `embedded-hal` traits | drivers that work on any chip |
| Embassy | async executor, timers and HALs (rp, stm32, nrf) |
| RTIC | interrupt-driven tasks with static priorities |
| `probe-rs` | flash and debug over SWD (`cargo run` with it as the runner), has a DAP server for nvim |
| `defmt` | tiny logging: format strings stay on the host |
| `heapless` | `Vec`, `String`, queues with fixed capacity, no allocator |

## Hardware-shaped Rust

| Need | Use |
| ---- | --- |
| a register layout | `#[repr(C)]` struct, or a PAC generated from the SVD |
| a register read/write the compiler must not drop | `ptr::read_volatile` / `write_volatile` (PACs wrap this) |
| state shared with an interrupt | `critical_section::Mutex<RefCell<T>>`, or atomics |
| a DMA buffer | `'static` buffer, aligned, not moved while the transfer runs |
| bit fields | `bitfield` / `modular-bitfield`, or masks and shifts |
| no panics in the binary | `panic-halt`, and check with `cargo bloat` |
