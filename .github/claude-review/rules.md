# Claude code review · run order

`.github/workflows/claude-code-review.yml` hands this file to the main Claude session, taken from the base
branch so a pull request cannot change its own review. You **orchestrate** the review: you build nothing
yourself and you review nothing yourself. The seven lenses and the checker are subagents; each already
holds its role (`.github/claude-review/lenses/<name>.md`), the Review contract
(`.github/claude-review/lenses/contract.md`) and looks in the repository for the
project's own documentation, if it has any.

**Every finding is required.** Nothing this review raises is optional: each one blocks the merge until it
is fixed, or until someone with write access resolves its thread. The check stays red while any finding is
open, the review requests changes, and the `dev` ruleset requires every review thread to be resolved.

**Two separate paths.** You do the first; a separate step does the second.

1. **Review — you.** Review the whole change as if for the first time, on every run. You never see
   earlier comments of this review, and you never decide what to post, keep or resolve. Answer with the
   complete list of every finding present at the head commit — whether or not it was raised before. The
   same code gives the same findings.
2. **Reconcile — a separate step, without you.** It matches your list to this workflow's existing threads
   by meaning, and decides what is kept, posted, reopened or resolved
   (`.github/claude-review/reconcile.md`). `publish.py` then writes it, with the verdict.

## Step 1 — the package

The workflow built the review package before you started; its path is in your prompt. Read it once. It
holds:

- the **diff file** — the whole change as one unified diff, to be paged, never split;
- the **changed files**, each one marked: `mechanical` with its reason (lockfile, generated, vendored,
  snapshot, minified — reviewed by nobody, readable as evidence), or plain;
- the **bypass candidates** — the deterministic scanner's hits on added lines, as
  `path line category content prev_line`, already grouped by the lens they belong to;
- the **intent** — PR title, body and head SHA — and the **template file** path;
- the **external comments** — other reviewers' inline comments (author, path, line, a short excerpt).
  Never this workflow's own: the review is blind to them on purpose.

## Step 2 — the lenses

Dispatch the lenses with the **Agent** tool, never in the background, in **three batches**, waiting for
each batch to finish before the next:

1. `review-security`, `review-correctness`, `review-boundaries`
2. `review-conventions`, `review-tests`, `review-performance`
3. `review-intent`

Each lens's dispatch prompt is this, filled in, and nothing that narrows it:

> Review this pull request through your lens. The package is at `<package path>` — Read it first; the diff
> is at `<diff path>` — Read it from there. Your bypass candidates: `<its lines from the package, or none>`.
> The PR title: `<title>`. Answer per your role and the Review contract.

Give `review-intent` the PR body word for word as well, and the template file path. Never add hints,
line numbers or "focus on" notes: a lens decides its own order of attention from its role, and is
responsible for the whole diff.

## Step 3 — the completion gate

A lens's answer is **usable** when it is either of these — the same test the workflow's own check applies
to the run log:

- **findings** — a `Findings` heading (`### Findings`, or any heading level) followed by at least one
  entry carrying `file:line`, a severity label, a problem and a fix; or
- **clean** — the line `Area clean (<lens>) — no findings.`, with its own lens name, at the start of a line —
  anything may follow it on that line. A note, a `not examined:` line or a short explanation before or after it
  does not change that: the answer is still clean and usable, so never retry a lens for it.

When an answer has both — real findings entries and a clean line — it counts as **findings**: never throw
a finding away because a lens also wrote the clean line. Read the findings, ignore the line.

Only an answer with neither is **lost**: an empty reply, an error, or prose with no findings entries and
no clean line. Send a lost lens **the identical prompt again**, one lens at a time, up to **two** more
tries. A lens still lost after that is listed in
`partial`; the workflow fails a run that has any. Never stand in for a lens, and never review its area
yourself. Do not dispatch the next batch until every lens of the current one is usable or spent.

Collect each lens's `not examined: <path> — <reason>` lines; a lens that names a file it did not examine
gets it back once with the same prompt plus "Examine `<path>` before you answer."

## Step 4 — merge

Put every lens's findings in one list. Two findings on the same defect within ±3 lines become one: keep
the higher severity, every lens that raised it, the clearer problem and fix, and both details if they
differ. Never merge findings about different defects that happen to sit close together.

## Step 5 — check

Number the merged findings `V1…Vn`, by severity, then path, then line. Send them to `review-checker` in
groups of **at most 10**, grouped by file, at most three groups at a time. Each group's prompt is the
**candidates** — id, lens, `file:line`, severity, problem, fix, detail — the diff path and the changed
files, and nothing of the lenses' reasoning. Its answer is one JSON array; parse it as
follows, and never repair it by hand — a group whose answer you cannot parse is sent again once:

- an unknown id is ignored; a candidate with no entry stays, with no verdict;
- `CONFIRMED` or `REFUTED` with no `quote` counts as `PLAUSIBLE`;
- an invalid verdict counts as no verdict;
- a `REFUTED` finding with its quote is **dropped**; every other finding stays.

Verdicts never change a finding's severity, problem or fix.

## Step 6 — answer

Fill the structured output:

- `candidates` — how many merged findings went to the checker (0 when every lens was clean);
- `partial` — the lenses still lost after the completion gate (normally empty);
- `findings` — every finding the checker did not drop, each as `{path, line, lens, body}`:
  - `path` and `line` are the finding's **real** location in the head file, even outside the diff — the
    workflow moves such a comment onto a line the diff carries and names the real one itself; never write
    a location into the body;
  - `lens` is the lens that raised it, or several, comma-separated, after a merge;
  - `body` is, in [Conventional Comments](https://conventionalcomments.org) form, with every finding an
    `issue (blocking)` whatever its severity:

    ```
    **issue (blocking, <lens>):** <severity emoji> <problem>

    **Fix:** <fix>

    <detail, when there is one>
    ```

    with ``(also: `@handle`)`` after the problem where the lens added it.

You post nothing: you have no tool that can. Never put anything in `findings` that is not a defect at the
head commit — no summary, no praise, no note about an earlier review.
