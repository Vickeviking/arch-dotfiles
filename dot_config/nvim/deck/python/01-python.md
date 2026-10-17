# Python

## Built-in collections

| Type | Literal | Mutable | Note |
| ---- | ------- | ------- | ---- |
| `list` | `[1, 2]` | yes | `append`, `pop`, slicing `a[1:3]`, `a[::-1]` |
| `tuple` | `(1, 2)` | no | hashable if its items are |
| `dict` | `{"a": 1}` | yes | keeps insertion order; `get(k, default)` |
| `set` | `{1, 2}` | yes | union, `&` intersection, `-` difference (examples below) |
| `str` | `"text"` | no | Unicode; `bytes` for raw data |

```python
evens | odds, evens & primes, evens - primes   # set union, intersection, difference
```

`collections`: `defaultdict(list)`, `Counter(words).most_common(3)`, `deque` (fast both ends), `namedtuple`.

## Comprehensions and generators

```python
squares = [x * x for x in range(10) if x % 2 == 0]
index = {name: i for i, name in enumerate(names)}
unique = {w.lower() for w in words}
total = sum(x * x for x in range(10**6))      # generator: no list in memory

def read_lines(path):
    with open(path) as f:
        for line in f:
            yield line.rstrip("\n")
```

## Functions

```python
def connect(host: str, port: int = 5432, *, timeout: float = 1.0) -> Conn:   # after *: keyword-only
    ...
def log(*args, **kwargs): ...          # any positional / keyword arguments
```

Never use a mutable default (`def f(items=[])`): it's shared between calls. Use `None` and create it inside.

## Classes

```python
from dataclasses import dataclass, field

@dataclass(frozen=True, slots=True)
class Point:
    x: float
    y: float
    tags: list[str] = field(default_factory=list)

class Stack:
    def __init__(self) -> None:
        self._items: list[int] = []
    def __len__(self) -> int:             # len(stack)
        return len(self._items)
    def __repr__(self) -> str:            # what the REPL shows
        return f"Stack({self._items})"
```

## Typing

| Hint | Means |
| ---- | ----- |
| `list[int]`, `dict[str, float]` | built-in generics (3.9+) |
| `Optional[int]` | may be `None`; newer spelling below the table |
| `Callable[[int], str]` | function type (`collections.abc`) |
| `Iterable[T]`, `Sequence[T]`, `Mapping[K, V]` | accept the broadest thing you need |
| `TypeVar` / `def f[T](x: T) -> T` | generics (new syntax 3.12+) |
| `Protocol` | structural interface (duck typing, checked) |
| `Literal["r", "w"]`, `TypedDict`, `Final` | precise types |

```python
def find(name: str) -> int | None: ...   # 3.10+: the bar spells a union, same as Optional[int]
```

basedpyright checks these in nvim as you type.

## Errors and resources

```python
try:
    data = json.loads(text)
except json.JSONDecodeError as e:
    raise ConfigError(f"bad config: {e}") from e
else:
    ...                     # ran only if nothing was raised
finally:
    ...                     # always runs

with open(path, encoding="utf-8") as f, lock:   # context managers close and release
    ...
```

## Pattern matching (3.10+)

```python
match command.split():
    case ["go", direction]:
        move(direction)
    case ["quit" | "exit"]:
        stop()
    case _:
        print("unknown")
```

## Concurrency

| Work is | Use |
| ------- | --- |
| waiting on network / disk | `asyncio` (`async def`, `await`, `asyncio.gather`) or threads |
| CPU-heavy | `multiprocessing` / `concurrent.futures.ProcessPoolExecutor` |
| simple parallel map | `ThreadPoolExecutor().map(f, items)` |

The GIL lets one thread run Python bytecode at a time; free-threaded builds (3.13+, `python3.13t`) lift that.
