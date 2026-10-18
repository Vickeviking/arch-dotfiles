# Python tooling

## Projects with uv

| Command | Does |
| ------- | ---- |
| `uv init app` | new project with `pyproject.toml` |
| `uv add requests` / `uv add --dev pytest` | add a dependency |
| `uv run app.py` / `uv run pytest` | run inside the project's venv (made on demand) |
| `uv sync` | install exactly what the lockfile says |
| `uv python install 3.13` | install a Python version |
| `uvx ruff check` | run a tool without installing it |

Without uv: `python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`.

## Formatting and linting (wired into nvim)

| Tool | Does | In nvim |
| ---- | ---- | ------- |
| `ruff check --fix` | lint and auto-fix (replaces flake8, isort, pyupgrade) | diagnostics |
| `ruff format` / `black` | format | on save via conform |
| `basedpyright` | type checking, go-to-definition, hover | the LSP |

## pytest

```python
import pytest

def test_parse():
    assert parse("1+2") == 3

@pytest.mark.parametrize("text, expected", [("1", 1), ("2+2", 4)])
def test_many(text, expected):
    assert parse(text) == expected

def test_raises():
    with pytest.raises(ValueError, match="empty"):
        parse("")

@pytest.fixture
def db(tmp_path):
    return Database(tmp_path / "test.db")
```

| Command | Does |
| ------- | ---- |
| `pytest -x` | stop at the first failure |
| `pytest -k parse` | only tests matching `parse` |
| `pytest --lf` | rerun the last failures |
| `pytest -s` | show `print` output |
| `pytest --pdb` | drop into the debugger on failure |

## Debugging

```python
breakpoint()        # stops here in pdb: n next, s step, c continue, p expr, l list, q quit
```

`python -m pdb script.py` from the start; `python -X importtime app.py` to see slow imports.

In nvim: the same keys as Rust and C (debugpy). `Space db` breakpoint, `Space dd` start (*file*, *file:args*, …),
`F10` / `F11` / `F12` step, `Space dk` value, `Space dv` view.

## Profiling

| Tool | For |
| ---- | --- |
| `python -m cProfile -s cumtime app.py` | which functions take time |
| `py-spy top --pid N` / `py-spy record -o out.svg -- python app.py` | sampling profiler, flamegraph, no code changes |
| `python -m timeit "sum(range(1000))"` | micro-benchmarks |
| `tracemalloc` | where memory is allocated |

## Handy standard library

| Module | For |
| ------ | --- |
| `pathlib` | `Path("a") / "b.txt"`, `.read_text()`, `.glob("*.py")` |
| `itertools` | `chain`, `groupby`, `islice`, `product`, `pairwise`, `batched` (3.12+) |
| `functools` | `cache`, `partial`, `reduce` |
| `argparse` | command-line options |
| `logging` | levels, handlers, instead of `print` |
| `subprocess.run([...], check=True, capture_output=True, text=True)` | run commands |
| `json`, `csv`, `tomllib`, `sqlite3` | data formats and a database, built in |
