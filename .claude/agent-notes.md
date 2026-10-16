# Agent notes — what earlier Claude sessions learned that the docs do not say

Until 2026-10-16 these lived in Claude's per-machine memory on the owner's Windows PC. That disk is
being wiped (the owner is moving to Linux and to cloud sessions), so they are kept here instead.
`CLAUDE.md` and `docs/` win wherever they disagree.

## Working with the owner

- **Momentum over questions.** Pick sensible defaults, state them in one short block so they are
  easy to veto, and build. Ask only when going either way would waste substantial work. An opening
  questionnaire was once dismissed in favour of "move and be corrected".
- **No combat, ever, in this template.** Confirmed twice (2026-08-23, 2026-09-28). Combat belongs to
  later games built on top. Asked about spells, bosses or status effects, give the non-combat
  version here and keep combat material separate.
- **First-run defaults (SYSTEMS_INVENTORY "Commonly forgotten" #8) are not yet playtested** by the
  owner (as of 2026-09-30). Never record a verdict for them. If the owner reports a default as
  unpleasant, it becomes a playtest-defect row ahead of the queue.

## Why the project is shaped this way

The owner's previous JRPG, Veilbound Chronicles (GitHub `Raiyan-Bashar-29/veilbound-chronicles`),
stalled on four failures this template is built to prevent: god objects (a 3,983-line `main.gd`),
code that never ran (409 green static checks, no rendered frame), ~200 hard-coded strings, and
breadth without depth (11 regions, no proven slice). The answer is mechanical enforcement, not
intentions: budgets, checkers, and the engine running everything.

## Process

- **Serial packages.** Before starting, `gh pr list --state open` and `git worktree list`; if a
  package is in flight, stop and say so. Raise the next package's chip only after the PR merges.
  A defect found mid-package becomes a board row, not a chip.
- **Merging.** `main` requires `Ladder (full checkout)` and `Ladder (stripped template)`, strict,
  no review. Merge with `gh pr merge <n> --merge` once `mergeStateStatus` reads `CLEAN`; a first
  refusal while checks attribute is transient. Never `--admin`. Behind `main`: merge `main` INTO
  the branch (never rebase), re-run the ladder, push, wait.
- **Suite totals move when docs move.** `record_shape_test`, `docs_test`, `version_test` and
  `doc_counts_test` compute their plans from `docs/`. Measure the delta (run with and without the
  doc change, diff the `--- <case>: N/N ---` lines), never predict it. It is a fixpoint: prose
  explaining a gotcha count that spells a tens-word counts itself, so write the prose first,
  measure, then correct only digits, and re-run once to prove it stable.
- **Backslashes.** A Bash heredoc on the Windows machine collapsed `\\` to `\` in GDScript twice.
  Prefer bracket classes in regex (`[*]`, `[.]`) and write files containing backslashes with the
  Write/Edit tools.

## The engine on Linux and in the cloud

`bash tools/cloud_setup.sh` installs the pinned 4.7.2 standard build (same digest as CI) and runs
`--import`. Then use `godot` wherever `CLAUDE.md` says `"$G"`; Linux has no `_console` variant.
Cloud sessions have no GPU, so the windowed capture rung cannot run there: visual claims still need
the owner to run it on their Linux desktop and look at the PNG.
