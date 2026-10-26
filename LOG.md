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

### 13:39–13:45 — mutineer-benchmarks repo
- Cloned github.com/davidteren/mutineer-benchmarks (empty) to
  /workspace/mutineer-benchmarks. Pushed `docs: add README` to main (64a5d6f)
  and the harness to `benchmark/fizzy-harness` (635f1f1). No PR.
- `bin/run` gained per-run gzipped reports (`results/reports/`), load average
  before/after each run, and `tests_glob` for whole-directory cases.

### 13:33–14:29 — Slice benchmark, v1.7.0 vs fixed branch (median of 3)
- **Process:** `/workspace/bench-all.sh` under nohup, serial, nothing else
  benchmarking; v1.7.0 from a detached worktree (ef5f17f), then the branch.
- **Duration:** 56 min (1.7.0: 24 min; branch: 32 min).
- **Outlier:** v1.7.0 redefine iteration 3 took 667.7 s vs ~280 s, with one
  mutant flipping survived -> timeout. Load average was <1 during it. A 10 s
  per-mutant timeout cannot add ~380 s, so every mutant ran slower: VM noise.
  The median ignores it; per-run load average and reports are now recorded so
  the next outlier can be explained.
- **Rows** for the branch were recorded with mutineer_sha 3c5868d (the then
  branch head incl. bench commits). Its lib/ and test/ are byte-identical to
  8b9fb5b (`git diff 3c5868d 8b9fb5b -- lib test` empty), so rows carry
  `mutineer_code_sha: 8b9fb5b` and ref `branch-8b9fb5b`.

### 14:29 — Interruption
- The supervising agent's wait was aborted at ~14:27; the benchmark itself
  was under nohup and finished at 14:29 unaffected. From here on, every long
  run is started with nohup and logs to /workspace/*.log.

### 14:30 — mutineer branch reduced to code fixes only
- A `git rebase --onto` dropping the bench commits conflicted on bench files
  and was aborted. Instead: reset the local branch to e23e4a4 and
  cherry-picked the fix: **8b9fb5b** (was 41d6d96). Not pushed.

### 14:30 — Daemon probe and #349 plan
- `--daemon --jobs 4` on closeable: 25 mutants, 17/5/3, 0 errored, 24 s:
  same verdicts as serial. But Config notes "daemon is whole-file reload
  only", so a redefine run cannot be parallelised.
- **Decision:** run both: `models-all-daemon-reload` (`--daemon --jobs 8`)
  first for a fast whole-app answer, then `models-all-redefine` serial (what
  #349 asks for). Started 14:31 under nohup (`/workspace/bench-long.sh`).

### 14:46 — Daemon run is serial on Fizzy (multi-database)
- **Observed:** `models-all-daemon-reload` with `--jobs 8` ran one daemon
  and one child at a time (load ~1.1).
- **Cause (by design):** `DaemonBackend.prepare_run` drops to one worker when
  the app has more than one database ("Parallel runs support one database").
  Fizzy's test env has two (primary + cable). A feature gap, not a bug; noted
  for David. The run continues as a serial whole-app reload datapoint.

### 14:48 — #349 redefine run sharded across 4 Fizzy copies
- **Why:** #349 needs counts (declined, unplaceable, skipped-invalid,
  attempted, warning), not wall time; serial would take ~1.5 h on top of the
  serial daemon run.
- **How:** `cp -a` Fizzy into /workspace/fizzy-shard1..4 (own SQLite files,
  fresh `db:prepare`), split the 165 `app/models` files into 4 groups of
  ~47 KB by size (`/workspace/shards.rb`), each shard runs
  `mutineer run <files> --test <all 104 test/models files> --rails
  --strategy redefine --operators all --format json` under nohup
  (`/workspace/shard-run.sh`). Summaries are summed afterwards; the
  stderr unrun warning is checked per shard (the threshold is per run, so the
  share is also recomputed on the merged counts).
- The queued serial `models-all-redefine` was cancelled (killed the wrapper
  script; the in-flight daemon run continues).

### 15:00–15:19 — Second interruption
- The supervising agent was interrupted again; all nohup runs (4 shards and
  the daemon run) survived and were not restarted.

### 14:49–15:25 — #349 results (sharded redefine, branch 8b9fb5b)
- Shard walls: 1832.0 / 2278.5 / 1979.9 / 2183.0 s (4 concurrent shards plus
  the serial daemon run on 8 vCPUs; wall times are not comparable to the
  quiet slice runs).
- Merged summary: total 5713, attempted 4652, killed 3485, survived 1085
  (score 76.3%), no_coverage 987, ran_at_load 14, timeout 82, errored 0,
  uncapturable 0, unplaceable 54, skipped_invalid 6, declined 93
  (call_to_receiver 53, chain_link 23, statement_removal 10, return_nil 4,
  range 3).
- Unrun share = (54 + 6) / (4652 + 60) = 1.27%; the stderr warning fired in
  no shard and would not fire on the merged counts (limit 10%).
- **Conclusion for #349:** on a concern-heavy real app the unrun share is
  ~1.3%, an order of magnitude under `UNRUN_SHARE_LIMIT = 0.10`; no evidence
  the limit needs lowering for false alarms, and it would catch a 8x worse
  app. Recommend keeping 10%.
- Raw shard reports: `results/reports/fizzy/*-shard*.json.gz`; shard
  scripts: `bin/shards.rb`, `bin/shard-run.sh` (one-off; hardcoded paths).

### 15:35 — Daemon whole-app reload run
- Still running after 65 min (serial, see 14:46); its row is appended to
  `results/fizzy.jsonl` by `bin/run` when it finishes.

### 15:45 — Daemon whole-app reload run lost
- `bin/run` (pid 572814) exited between 15:35 and 15:45 after ~70 min with
  no mutineer report and no JSONL row. bin/run buffers mutineer's output
  (Open3.capture2e), so the cause is unknown. Likely factor: its parent
  wrapper was killed at 14:46 to cancel the queued redefine run.
- **Follow-up:** have bin/run stream mutineer output to a per-run log file,
  and rerun `--only models-all-daemon-reload` on a quiet machine.
