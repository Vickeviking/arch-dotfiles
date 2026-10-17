# React & tooling

## Components and props

```tsx
type ButtonProps = { label: string; onClick: () => void; disabled?: boolean };

export function Button({ label, onClick, disabled = false }: ButtonProps) {
  return <button onClick={onClick} disabled={disabled}>{label}</button>;
}
```

Lists need a stable `key`: `items.map(i => <Row key={i.id} item={i} />)`. Not the index if the list reorders.

## Hooks

| Hook | For |
| ---- | --- |
| `useState(initial)` | local state; `setX(prev => prev + 1)` when it depends on the old value |
| `useEffect(fn, [deps])` | sync with something outside React; return a cleanup |
| `useRef(null)` | a DOM node or a value that survives renders without re-rendering |
| `useMemo(fn, [deps])` / `useCallback(fn, [deps])` | cache a value / a function between renders |
| `useContext(Ctx)` | read a value provided higher up |
| `useReducer(reducer, init)` | state with many transitions |

Rules: call hooks at the top level of a component or custom hook, never in loops or conditions.
State is immutable: `setItems([...items, item])`, never `items.push(item)`.

```tsx
useEffect(() => {
  const ctrl = new AbortController();
  fetch(url, { signal: ctrl.signal }).then(r => r.json()).then(setData);
  return () => ctrl.abort();          // cleanup: runs before the next effect and on unmount
}, [url]);
```

## Vue (for the .vue files)

```vue
<script setup lang="ts">
import { ref, computed } from "vue";
const count = ref(0);
const double = computed(() => count.value * 2);
</script>

<template>
  <button @click="count++">{{ count }} → {{ double }}</button>
</template>
```

## Package managers

| npm | pnpm | Does |
| --- | ---- | ---- |
| `npm install` | `pnpm install` | install from the lockfile |
| `npm i zod` | `pnpm add zod` | add a dependency |
| `npm i -D vitest` | `pnpm add -D vitest` | dev dependency |
| `npm run dev` | `pnpm dev` | run a script from `package.json` |
| `npx tsc --noEmit` | `pnpm exec tsc --noEmit` | type-check the project |

## In nvim

| Tool | Does |
| ---- | ---- |
| `ts_ls` | TypeScript LSP: hover, go-to-definition, rename |
| `eslint` LSP / eslint_d | lint diagnostics and fixes |
| prettier / prettierd | format on save (conform) |
| `tailwindcss` LSP | class completion and color previews |
| `vue_ls` | `.vue` files |

## Testing with Vitest

```ts
import { describe, it, expect, vi } from "vitest";

describe("sum", () => {
  it("adds", () => expect(sum(1, 2)).toBe(3));
  it("calls back", () => {
    const fn = vi.fn();
    run(fn);
    expect(fn).toHaveBeenCalledWith(42);
  });
});
```

`pnpm vitest` watches; `pnpm vitest run` once. React components: `@testing-library/react` with `render` and `screen.getByRole`.
