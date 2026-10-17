# Build & debug

## Compiler flags worth typing

| Flag | Does |
| ---- | ---- |
| `-Wall -Wextra -Wpedantic` | the useful warnings |
| `-Werror` | warnings fail the build |
| `-std=c17` / `-std=c++20` | language version |
| `-g` | debug info (always while developing) |
| `-O0` / `-O2` / `-O3` | no / normal / aggressive optimization |
| `-fsanitize=address,undefined` | ASan + UBSan: overflows, use-after-free, UB at run time |
| `-fsanitize=thread` | TSan: data races (not together with ASan) |
| `-fno-omit-frame-pointer` | better stack traces in sanitizers and perf |
| `-fopenmp` | OpenMP |
| `-lpthread` / `-lm` | link pthreads / the math library |
| `-MMD -MP` | write header dependency files for make |

```sh
gcc -std=c17 -Wall -Wextra -g -fsanitize=address,undefined main.c -o main && ./main
```

## Make

```make
CC      := gcc
CFLAGS  := -std=c17 -Wall -Wextra -g -MMD -MP
SRC     := $(wildcard src/*.c)
OBJ     := $(SRC:src/%.c=build/%.o)

app: $(OBJ)
	$(CC) $(CFLAGS) $^ -o $@

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

build:
	mkdir -p build

-include $(OBJ:.o=.d)
.PHONY: clean
clean:
	rm -rf build app
```

`$@` target · `$<` first prerequisite · `$^` all prerequisites. Recipes need a real tab.

## CMake

```cmake
cmake_minimum_required(VERSION 3.20)
project(app C CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)        # clangd reads compile_commands.json
add_executable(app src/main.cpp)
target_compile_options(app PRIVATE -Wall -Wextra)
```

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j
```

clangd needs `compile_commands.json` in the project root (CMake writes it; for make, `bear -- make`).

## Debugging in nvim

The same keys as Rust: `Space db` breakpoint, `F5` start, `F10` / `F11` / `F12` step, `Space dv` view.
codelldb debugs C and C++; build with `-g -O0`.

## gdb / lldb basics

| gdb | lldb | Does |
| --- | ---- | ---- |
| `b main` / `b file.c:42` | same | breakpoint |
| `r` / `c` | same | run / continue |
| `n` / `s` / `finish` | same | over / into / out |
| `p x` / `p *arr@10` | `p x` / `parray 10 arr` | print, print 10 elements |
| `bt` | same | backtrace |
| `watch x` | `w s v x` | stop when `x` changes |
| `info locals` | `frame variable` | all locals |
| `x/16xb ptr` | `memory read -c16 ptr` | raw bytes |

## Profiling

| Tool | For |
| ---- | --- |
| `perf record ./app` then `perf report` | where time goes |
| `valgrind --tool=callgrind ./app` | instruction-level profile (`kcachegrind` to view) |
| `valgrind --tool=massif ./app` | heap usage over time |
| `time ./app` / `hyperfine ./app` | quick timing |
