# Mutineer benchmarks

Repeatable runtime and verdict measurements of mutineer on real apps, recorded
per mutineer version so releases can be compared.

## Approach

- **Pinned target.** Each `targets/<name>.yml` pins an app repo and sha,
  setup commands, a fixed slice of sources and tests, and the cases to run.
  The first target is Basecamp Fizzy (Rails main, Minitest, SQLite).
- **Same app, swappable mutineer.** `bin/run` points the app's Gemfile at a
  mutineer checkout: a local path (`--mutineer DIR`) or a git ref
  (`--mutineer-ref v1.7.0`, checked out into `tmp/mutineer-<ref>`), so a
  release tag and a branch run against the identical app tree.
- **Outside timing.** The JSON report has no duration, so `bin/run` times
  each `mutineer run` with a monotonic clock and computes
  `attempted_per_s = summary.attempted / wall_s`.
- **One JSON line per run** in `results/<name>.jsonl`, with the
  mutineer version and sha, app sha, the full `summary`, the unrun share, if
  the unrun warning fired, and the machine spec from `bin/sysinfo`.
- **Medians.** Run with `--repeat 3`; `bin/compare` reports the median wall
  time per (case, mutineer version, sha).
- **Dry runs** record mutation, skipped-invalid and declined counts (parsed
  from the human summary line; dry runs print no JSON).

## Reproduce

```sh
# system deps on Debian/Ubuntu for Fizzy: build-essential libyaml-dev libvips42
# Fizzy pins Ruby 4.0.9; 4.0.6 works if you edit its .ruby-version (recorded per row).
bin/run fizzy --mutineer-ref v1.7.0 --repeat 3
bin/run fizzy --mutineer ../mutineer --ref my-branch --repeat 3
bin/compare fizzy
```

`--app-dir DIR` reuses an existing app checkout (otherwise `tmp/<name>`).
`--only id1,id2` runs a subset of cases and dry runs.

Run one benchmark at a time on a quiet machine: `--rails` runs are serial
(shared test DB), and wall time is sensitive to other load.

## Fields

| Field | Meaning |
|---|---|
| `wall_s` | Seconds for the whole `mutineer run` (boot, coverage capture, every mutant). |
| `attempted_per_s` | Mutants that ran tests (`summary.attempted`) per wall second. |
| `summary.total` | Mutants generated. |
| `summary.killed` / `survived` | Scored mutants; `score = killed / (killed + survived)`. |
| `summary.no_coverage` | Mutants on lines no selected test runs (not scored). |
| `summary.errored` / `timeout` / `uncapturable` | Attempted, no verdict (`no_verdict`). |
| `summary.declined` | Candidates an operator chose not to mutate (schema 1.9+, absent on 1.7.0). |
| `unrun_share` | `(unplaceable + skipped_invalid) / (attempted + those)`; warns over 10%. |

See `LOG.md` for how the numbers so far were produced and why.
