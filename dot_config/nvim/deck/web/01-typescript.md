# TypeScript

## Types at a glance

| Type | Example |
| ---- | ------- |
| primitives | `string`, `number`, `boolean`, `bigint`, `null`, `undefined` |
| arrays / tuples | `number[]`, `Array<string>`, `[string, number]` |
| object | `{ id: number; name?: string; readonly tags: string[] }` |
| union | one of several types: `Status` just below |
| intersection | `User & { admin: true }` |
| function | `(id: number) => Promise<User>` |
| unknown vs any | `unknown` must be narrowed before use; `any` turns checking off |
| never | a value that can't exist (exhaustiveness checks) |

## type vs interface

```ts
interface User { id: number; name: string }          // extendable, mergeable
interface Admin extends User { level: number }
type Status = "idle" | "loading" | "done";           // a union; unions and computed types need `type`
type Point = { x: number; y: number };
```

## Narrowing

```ts
function show(v: string | number | null) {
  if (v === null) return;
  if (typeof v === "string") v.toUpperCase();        // v: string here
  else v.toFixed(2);                                  // v: number here
}

type Result = { ok: true; value: number } | { ok: false; error: string };   // discriminated union
function handle(r: Result) {
  if (r.ok) use(r.value); else log(r.error);
}

function assertNever(x: never): never { throw new Error(`unexpected ${x}`); }
```

`in`, `instanceof`, and custom guards (`function isUser(x: unknown): x is User`) narrow too.

## Generics

```ts
function first<T>(items: T[]): T | undefined { return items[0]; }
function byId<T extends { id: number }>(items: T[], id: number) { return items.find(i => i.id === id); }
const config = { port: 3000, host: "localhost" } as const;       // literal, readonly types
const user = JSON.parse(text) satisfies User;                     // check without widening
```

## Utility types

| Type | Gives |
| ---- | ----- |
| `Partial<T>` / `Required<T>` | all fields optional / required |
| `Readonly<T>` | all fields readonly |
| `Pick<T, "a">` / `Omit<T, "c">` | some fields / all but some |
| `Record<K, V>` | object with keys K and values V |
| `ReturnType<typeof f>` / `Parameters<typeof f>` | types from a function |
| `Awaited<P>` | what a promise resolves to |
| `NonNullable<T>` | without `null` and `undefined` |

## Async

```ts
async function load(id: number): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return (await res.json()) as User;
}
const [a, b] = await Promise.all([load(1), load(2)]);      // in parallel
const results = await Promise.allSettled(jobs);            // never rejects
```

## Modern JS you'll use daily

| Syntax | Does |
| ------ | ---- |
| `a?.b?.c` | stop at `null` / `undefined` |
| `x ?? fallback` | fallback only for `null` / `undefined` (not `0` or `""`) |
| `const { id, ...rest } = obj` | destructure, collect the rest |
| `[...a, ...b]`, `{ ...o, name }` | spread copies |
| `arr.map / filter / reduce / find / some / every` | array methods (return new arrays) |
| `arr.at(-1)` | last element |
| `structuredClone(obj)` | deep copy |
| `Object.entries(o)` / `Object.fromEntries(pairs)` | object ↔ pairs |
