# Pointers & memory

## Where things live

| Region | What | Lifetime |
| ------ | ---- | -------- |
| stack | locals, arguments | until the function returns |
| heap | `malloc` / `new` | until `free` / `delete` |
| static / global | `static` and file-scope variables | the whole program |
| read-only data | string literals, `const` globals | the whole program; writing is UB |

Never return a pointer to a local: it dangles the moment the function returns.

## malloc family

```c
int *a = malloc(n * sizeof *a);          // sizeof *a: stays right if the type changes
if (!a) { perror("malloc"); exit(1); }
int *z = calloc(n, sizeof *z);           // zeroed, and checks n * size for overflow
int *tmp = realloc(a, 2 * n * sizeof *a);
if (!tmp) { free(a); /* handle */ } else a = tmp;   // never a = realloc(a, …)
free(a); a = NULL;                       // free(NULL) is fine; double free is not
```

## Pointer arithmetic

| Expression | Means |
| ---------- | ----- |
| `p + 1` | next element: address + `sizeof *p` bytes |
| `a[i]` | exactly `*(a + i)` |
| `&a[i]` | `a + i` |
| `q - p` | number of elements between (same array only) |
| `(char *)p + n` | move by n bytes |

An array name decays to a pointer to its first element, except in `sizeof a` and `&a`.
So inside a function, `sizeof param` is the pointer size, not the array size: pass the length.

## Ownership by convention

C has no borrow checker, so write the rules down:

- Document who frees: "caller owns the returned buffer" / "borrowed, don't free".
- One owner per allocation; free in the same module that allocated.
- `goto cleanup;` for a single exit path that frees everything in reverse order.

## Alignment and layout

```c
struct s { char c; int i; char d; };   // 12 bytes: 3 + 3 bytes of padding
struct t { int i; char c; char d; };   // 8 bytes: order fields large to small
_Alignof(double)                       // 8
_Alignas(64) char cacheline[64];       // C11
offsetof(struct s, i)                  // 4, from <stddef.h>
```

Unlike Rust, C never reorders fields: the order you write is the order in memory.

## Volatile, restrict, const

| Qualifier | Promise |
| --------- | ------- |
| `const` | you won't write through this name |
| `volatile` | every read and write really happens (hardware registers, signal handlers); not for threads |
| `restrict` | this pointer is the only way to reach that memory here, so the compiler may optimize |

## Common bugs and their tool

| Bug | Finds it |
| --- | -------- |
| leak | `valgrind --leak-check=full ./a.out`, ASan's leak checker |
| use-after-free, overflow | `-fsanitize=address` |
| uninitialized read | `valgrind`, `-fsanitize=memory` (clang) |
| data race | `-fsanitize=thread` |
| off-by-one in a loop | `-fsanitize=address` + a test at the boundary |
