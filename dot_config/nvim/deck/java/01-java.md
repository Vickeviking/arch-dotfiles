# Java

## Language features you'll want (Java 17–21+)

```java
var names = new ArrayList<String>();                         // local type inference

record Point(int x, int y) {}                                // immutable data class: equals, hashCode, toString

sealed interface Shape permits Circle, Square {}
record Circle(double r) implements Shape {}
record Square(double side) implements Shape {}

double area(Shape s) {
    return switch (s) {                                      // pattern matching switch (21)
        case Circle c -> Math.PI * c.r() * c.r();
        case Square q -> q.side() * q.side();
    };
}

if (obj instanceof String str && !str.isBlank()) { … }      // instanceof pattern

String json = """
    { "name": "Viktor" }
    """;                                                     // text block
```

## Collections

| Interface | Usual class | Note |
| --------- | ----------- | ---- |
| `List<T>` | `ArrayList` | `List.of(…)` is immutable |
| `Map<K, V>` | `HashMap`, `TreeMap` (sorted) | `getOrDefault`, `computeIfAbsent`, `merge` |
| `Set<T>` | `HashSet`, `TreeSet` | |
| `Deque<T>` | `ArrayDeque` | stack and queue in one |
| `PriorityQueue<T>` | | min-heap by default |

`equals` and `hashCode` must agree for anything used as a key (records do it for you).

## Streams

```java
List<String> top = users.stream()
    .filter(u -> u.age() >= 18)
    .sorted(Comparator.comparing(User::name))
    .map(User::name)
    .limit(10)
    .toList();

Map<String, Long> byCity = users.stream()
    .collect(Collectors.groupingBy(User::city, Collectors.counting()));
```

## Optional and nulls

```java
Optional<User> u = repo.find(id);
String name = u.map(User::name).orElse("unknown");
u.ifPresent(this::greet);
```

Use `Optional` for return values, not fields or parameters. `Objects.requireNonNull(x, "x")` at boundaries.

## Exceptions

```java
try (var in = Files.newBufferedReader(path)) {               // try-with-resources closes it
    return in.readLine();
} catch (IOException e) {
    throw new UncheckedIOException("reading " + path, e);
}
```

Checked exceptions (`IOException`) must be declared or caught; unchecked (`RuntimeException`) need not be.

## Concurrency

```java
try (var exec = Executors.newVirtualThreadPerTaskExecutor()) {    // virtual threads (21)
    var f = exec.submit(() -> fetch(url));
    var body = f.get();
}
var map = new ConcurrentHashMap<String, Integer>();               // the one you're porting to Rust
map.merge(word, 1, Integer::sum);
AtomicLong counter = new AtomicLong();
synchronized (lock) { … }
```

## Build tools

| Maven | Gradle | Does |
| ----- | ------ | ---- |
| `mvn compile` | `./gradlew build` | compile |
| `mvn test` | `./gradlew test` | run tests |
| `mvn package` | `./gradlew jar` | build a jar |
| `mvn dependency:tree` | `./gradlew dependencies` | dependency tree |

jdtls is the LSP in nvim (hover, rename, code actions, organize imports).
