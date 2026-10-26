# Benchmark log

Retrospective log of the benchmark work. Times are Africa/Johannesburg (SAST,
UTC+2). Entries before 13:32 on 2026-10-26 were reconstructed from the session
transcript; their times and durations are approximate (±2 min).

## Machine

Captured by `bench/sysinfo` (also embedded in every JSONL row as `machine`):

```
{"cpu_model":"Intel(R) Xeon(R) Processor","cpus":8,"mem_gb":15.6,"os":"Debian GNU/Linux 13 (trixie)","kernel":"Linux 6.12.94+","arch":"x86_64","ruby":"ruby 4.0.6 (2026-07-14 revision 03b6d3f889) +PRISM [x86_64-linux]","disk_device":"/dev/vdb","disk_size_gb":127.4,"disk_free_gb":115.7,"host":"grok-bot-vm-402995229"}
```

## Entries

### 2026-10-26 ~13:00 — Research: dogfood script, #349, report formats
- **Approach:** fresh clone of davidteren/mutineer in /workspace; read
  `test/fixtures/rails_app/bin/dogfood`, `lib/mutineer/{cli,reporter}.rb`,
  `docs/json-schema.md`, CHANGELOG, issue #349 via the GitHub API.
- **Duration:** ~5 min.
- **Outcome:** dogfood is a contract check (exit codes, a few summary
  counts), not a benchmark. JSON `summary` has every count needed but no
  timing; dry runs print no JSON; the unrun warning is stderr only.
- **Decision:** time runs outside mutineer; parse JSON for runs and the
  summary line for dry runs.

### ~13:08 — Fizzy setup on the box
- **Commands:** `git clone basecamp/fizzy` (HEAD aef43ac); `apt-get install
  libyaml-0-2 libyaml-dev libvips42t64 build-essential pkg-config libssl-dev`;
  `.ruby-version` 4.0.9 -> 4.0.6 (box Ruby); `bundle install`;
  `bin/rails db:prepare`; `bin/rails test test/models`.
- **Duration:** ~6 min (bundle install ~2.5 min across retries).
- **Outcome:** 750 tests, 2272 assertions, 0 failures, 4 skips in 7.05 s.
  SQLite only; no Redis or MySQL needed.
- **Decision:** run on Ruby 4.0.6 rather than build 4.0.9; recorded per row.

### ~13:12 — First mutineer runs on Fizzy (mutineer e23e4a4)
- **Commands:** `mutineer run app/models/card/closeable.rb --test
  test/models/card/closeable_test.rb --rails [--operators all]
  [--strategy reload|redefine] --format json`.
- **Outcome:** default operators 3/3 killed in 6.1 s; all operators 25
  mutants, 17 killed / 5 survived / 3 no_coverage (77.3%) in ~22 s under the
  `--rails` default (redefine). Explicit `--strategy reload`: 22/22 errored
  ("child exited with status 2") yet exit 0.
- **Decision:** treat reload errors as a bug to trace; scaffold harness.

### ~13:20 — Harness scaffold (commit abc2f80)
- bench/run, bench/compare, bench/targets/fizzy.yml, results JSONL.
- Note: an unrelated agent sharing this box created `docs/audit-fixes` from
  this branch in /workspace/mutineer and switched that checkout; the amend
  landed on that branch. Work moved to a separate worktree,
  /workspace/mutineer-bench, and this branch was reset (soft) to abc2f80.
  `docs/audit-fixes` still carries abc2f80 as its base; untouched.

### ~13:25 — Trace reload errors
- **Approach:** read the child's stderr (`--verbose`):
  `ActiveSupport::Concern::MultipleIncludedBlocks`. mutineer already forgets
  stored blocks (#256), so asked why that missed. Hypothesis: concern not
  loaded at fork (lazy test env). Test: `CI=1` (Fizzy sets
  `eager_load = ENV["CI"].present?`) -> 3/3 killed. Confirmed.
- **Fix (41d6d96):** `ConcernBlocks.load_original` autoloads the file's
  constant through each Zeitwerk loader (`cpath_expected_at`) before forget.
  Regression test with a stub loader; full suite 1684 runs green (204 s).
- **Verify:** closeable reload all-operators: 0 errored, 17/5/3, 24.1 s.

### ~13:27 — Exit 0 when every mutant errors
- **Finding:** intended and documented. Reporter prints "Errors are not in
  the score, so they do not fail a run without a positive --threshold"; with
  a threshold, a run where nothing can be scored fails. Not changed. The
  harness records `exit` and `no_verdict`, so a benchmark sees it.

### ~13:30 — Standard slice
- **Approach:** dry-ran every concern with a matching test, 15–80 lines;
  picked 15 across Card/Board/User/Identity/Account, 9–41 mutants each
  (~332 on HEAD with every operator; 309 counted on 1.7.0).
- **Decision:** one mutineer invocation per case over the whole slice
  (boot once, as a user would).

### 13:31 — Daemon probe (interrupted)
- `--daemon --jobs 8` on closeable was interrupted after 15 s before output;
  leftover processes killed. Retry after the slice benchmark.

### 13:33 — Slice benchmark started (commit d554074)
- `/workspace/bench-all.sh`: `bench/run fizzy --repeat 3` for v1.7.0
  (worktree) then branch HEAD; cases slice-all-redefine, slice-all-reload,
  dry runs slice-all-ops and models-all-ops.
- First rows: models dry run 6029 mutations on 1.7.0 (5707 on e23e4a4: #329
  de-duplication and #334 declines landed after 1.7.0).

### 13:38 — Decision: harness moves to its own repo
- **Why (David):** keep benchmarks, logs and results out of the gem.
  Harness, targets, results, README and LOG now live in
  github.com/davidteren/mutineer-benchmarks (`bin/run`, `bin/compare`,
  `bin/sysinfo`, `targets/`, `results/`). main holds only a README; the
  harness is on branch `benchmark/fizzy-harness` (pushed, no PR).
- `bin/run` takes `--mutineer DIR` (local checkout) or `--mutineer-ref REF`
  (clones mutineer into `tmp/mutineer` and adds a worktree per ref).
- mutineer's local `benchmark/fizzy-harness` keeps only code fixes; the
  bench/ commits are dropped there after the in-flight benchmark (which runs
  from that worktree) finishes. mutineer is not pushed.
