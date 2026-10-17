# Modern C++

## Ownership with smart pointers

| Type | Means | Rust cousin |
| ---- | ----- | ----------- |
| `std::unique_ptr<T>` | one owner, moved not copied | `Box<T>` |
| `std::shared_ptr<T>` | shared owner, atomic refcount | `Arc<T>` |
| `std::weak_ptr<T>` | doesn't keep alive, `.lock()` to use | `Weak<T>` |
| `T&` / `const T&` | borrow (never null) | `&mut T` / `&T` |
| `T*` | non-owning, nullable | `Option<&T>` (unchecked) |
| `std::optional<T>` | maybe a value | `Option<T>` |
| `std::variant<A, B>` | one of several types | `enum` |
| `std::span<T>` / `std::string_view` | view into contiguous data | `&[T]` / `&str` |

```cpp
auto p = std::make_unique<Node>(1);
auto q = std::move(p);                 // p is now null
auto s = std::make_shared<Cache>();
```

## RAII and the rule of zero

Resources are released in destructors, so scope exit cleans up, even on exceptions.
Let members (vector, string, unique_ptr) manage resources and write **none** of the five special members.
If you write one of destructor / copy ctor / copy assign / move ctor / move assign, think about all five.

## Move semantics

```cpp
std::vector<std::string> v;
std::string s = "long text";
v.push_back(std::move(s));     // steals the buffer; s is valid but unspecified (usually empty)
void take(std::string s);      // by value: caller chooses copy or move
void look(const std::string& s);
```

Unlike Rust, a moved-from object is still alive and its destructor still runs. Using it compiles fine.

## Containers

| Need | Use |
| ---- | --- |
| growable array | `std::vector<T>` (`reserve`, `emplace_back`) |
| fixed array | `std::array<T, N>` |
| hash map / set | `std::unordered_map` / `std::unordered_set` |
| ordered map | `std::map` (red-black tree) |
| queue / deque | `std::queue`, `std::deque` |
| priority queue | `std::priority_queue` (max first) |

Iterator invalidation: `push_back` may reallocate and invalidate every pointer and iterator into a vector.

## Handy modern syntax

```cpp
for (const auto& [key, value] : map) { … }        // structured bindings (C++17)
if (auto it = m.find(k); it != m.end()) { … }     // if with initializer
auto add = [&total](int x) { total += x; };       // lambda capturing by reference
constexpr int square(int x) { return x * x; }     // computed at compile time when possible
template <typename T> concept Number = std::is_arithmetic_v<T>;   // C++20 concepts
std::ranges::sort(v);                             // ranges (C++20)
auto r = v | std::views::filter(is_even) | std::views::transform(sq);
```

## Concurrency

```cpp
std::jthread t([] { work(); });            // joins in its destructor (C++20)
std::mutex m;
{ std::scoped_lock lock(m); /* … */ }      // RAII lock, several mutexes without deadlock
std::atomic<int> n{0};
n.fetch_add(1, std::memory_order_relaxed);
auto f = std::async(std::launch::async, compute);
int r = f.get();
```

Memory orders mean the same as in Rust: Rust copied the C++20 model.
