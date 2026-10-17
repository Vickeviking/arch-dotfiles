# SQL

Examples are PostgreSQL (Arcturon's database); most of it is standard SQL.

## The query shape

```sql
SELECT   u.name, count(o.id) AS orders        -- 5. pick columns
FROM     users u                              -- 1. tables
JOIN     orders o ON o.user_id = u.id         -- 2. join
WHERE    o.created_at > now() - interval '30 days'   -- 3. filter rows
GROUP BY u.name                               -- 4. group
HAVING   count(o.id) > 3                      -- 6. filter groups
ORDER BY orders DESC                          -- 7. sort
LIMIT    10;                                  -- 8. cut
```

The numbers are the logical order: why `WHERE` can't use the alias `orders` but `ORDER BY` can.

## Joins

| Join | Keeps |
| ---- | ----- |
| `JOIN` (inner) | only rows that match on both sides |
| `LEFT JOIN` | every left row; right columns `NULL` when no match |
| `RIGHT JOIN` | the mirror |
| `FULL JOIN` | everything from both |
| `CROSS JOIN` | every combination |

Rows without a match: `LEFT JOIN … WHERE right.id IS NULL`.

## Changing data

```sql
INSERT INTO users (name, email) VALUES ('Li', 'li@example.com') RETURNING id;
UPDATE users SET name = 'Viktor' WHERE id = 1;          -- always with a WHERE
DELETE FROM sessions WHERE expires_at < now();
INSERT INTO stats (day, hits) VALUES (current_date, 1)
ON CONFLICT (day) DO UPDATE SET hits = stats.hits + 1;  -- upsert
```

Wrap risky changes: `BEGIN;` … check with `SELECT` … `COMMIT;` or `ROLLBACK;`.

## NULL rules

- `NULL = NULL` is not true: use `IS NULL` / `IS NOT NULL` / `IS DISTINCT FROM`.
- `count(*)` counts rows; `count(col)` skips NULLs.
- `coalesce(a, b, 0)` picks the first non-NULL.
- `NOT IN (subquery)` returns nothing if the subquery contains a NULL: use `NOT EXISTS`.

## Window functions

```sql
SELECT name, score,
       rank()       OVER (ORDER BY score DESC)                 AS place,
       sum(score)   OVER (PARTITION BY team)                   AS team_total,
       lag(score)   OVER (PARTITION BY team ORDER BY played)   AS previous
FROM results;
```

Unlike `GROUP BY`, windows keep every row.

## CTEs

```sql
WITH recent AS (
    SELECT * FROM orders WHERE created_at > now() - interval '7 days'
)
SELECT user_id, count(*) FROM recent GROUP BY user_id;
```

`WITH RECURSIVE` walks trees and graphs (categories, org charts).

## Schema

```sql
CREATE TABLE users (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON orders (user_id, created_at DESC);
ALTER TABLE users ADD COLUMN bio text;
```

## Speed

| Tool | Does |
| ---- | ---- |
| `EXPLAIN ANALYZE <query>` | the real plan with timings: look for `Seq Scan` on big tables |
| an index on `WHERE` / `JOIN` / `ORDER BY` columns | turns scans into lookups |
| `pg_stat_statements` | the slowest queries over time |

## psql

| Command | Does |
| ------- | ---- |
| `\l` / `\c db` | list databases / connect |
| `\dt` / `\d table` | list tables / describe one |
| `\x` | expanded rows (wide tables) |
| `\timing` | show query time |
| `\e` | edit the query in `$EDITOR` (nvim) |

sqls runs as the LSP for `.sql` files in nvim.
