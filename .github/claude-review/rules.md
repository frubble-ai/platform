# Claude code review · run order

`.github/workflows/claude-code-review.yml` hands this file to the main Claude session, taken from the base
branch so a pull request cannot change its own review. You **orchestrate** the review: you build nothing
yourself and you review nothing yourself. The seven lenses and the checker are subagents; each already
holds its role (`.github/claude-review/lenses/<name>.md`), the Review contract
(`.github/claude-review/lenses/contract.md`) and the _Repo rules_ below.

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
  snapshot, minified — reviewed by nobody, readable as evidence), `doc modified by this diff`, or plain;
- the **docs manifest** — every convention and project doc in the repo (`path — what it is — FOUND`),
  including the docs the agent guide links one hop out, each marked `modified by this diff` where it is;
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
- **clean** — the line `Area clean (<lens>) — no findings.`, with its own lens name, anywhere in the
  answer on a line of its own. A note, a `not examined:` line or a short explanation before or after it
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
**candidates** — id, lens, `file:line`, severity, problem, fix, detail — the diff path, the changed files
and the docs manifest, and nothing of the lenses' reasoning. Its answer is one JSON array; parse it as
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

## Repo rules

`frubble-ai/platform`: the infrastructure of every environment of `frubble-ai/app`, written in the
Terraform language and run with OpenTofu (`tofu`, pinned as `TOFU_VERSION` in the workflows). One root
per scope and provider under `terraform/live/{org,dev,stg,prd}`, shared code under `terraform/modules`,
and the GitHub workflows that plan and apply them. Taken from `README.md`, `docs/`, `.github/CODEOWNERS`
and the committed config; each finding cites the file by path. A mistake here changes who can change
production, so every lens reads the trust model first.

### Blockers (🚨, whatever the lens)

- A trust rule loosened: a `principalSet` or binding that matches more than the exact composite
  attribute (`plan_entry`, `apply_entry`, `deploy_entry`) — repository, workflow file, environment and
  branch — a wildcard, or a pin on `workflow_ref` instead of `job_workflow_ref`
  (`docs/ci-authentication.md`, `terraform/live/org/gcp/_setup/wif.tf`).
- `deploy_entry` (any branch, the actor's id appended) used for anything but dev's app deploys
  (`backend-cd.yml` in `backend-dev`, `app-cd.yml` in `app-dev`), or `dev_deployers` gaining anyone who
  is not an organization member: an outside collaborator or a bot (`docs/ci-authentication.md`,
  `terraform/live/dev/gcp/trust.tf`).
- A hub given any permission beyond impersonating its spoke, a spoke reaching outside its own project,
  or a second path to a spoke (`docs/ci-authentication.md`).
- A secret value that reaches state or a plan: a generated value written through anything but a
  write-only attribute (`secret_data_wo`) from an `ephemeral "random_password"`, an outside value
  written by Terraform instead of over the placeholder (`REPLACE_ME_VIA_SECRET_MANAGER`), or an output
  carrying one (`docs/secrets.md`, `terraform/modules/gcp/secret`).
- A role that grants a shell, a key, or a secret value to a human, the developer group made more than
  read-only, or a change to a `_setup` root's IAM deny policy (`docs/human-access.md`,
  `terraform/live/*/gcp/_setup/deny.tf`).
- A workflow that gains `id-token: write`, a wider `permissions:` block, a `pull_request_target`
  trigger, or untrusted input (a PR title, body, branch name) interpolated into `run:` with
  `${{ }}` instead of passed through `env` (`.github/workflows/*.yml`).
- An action not pinned to a full commit SHA, or a downloaded tool not checked against its checksum
  (the pattern every workflow here follows).
- A prd apply switched on (`TF_APPLY_ENABLE_PRD`), or a change under `terraform/live/**/_setup/`,
  without the reason in the PR body (`docs/pipelines.md`, `.github/CODEOWNERS`).
- The stg switch broken: `STG_ENABLED` compared in an Actions expression instead of a shell step, or a
  stg resource that should go when stg is off left without `lifecycle { enabled = var.enabled }`, or a
  read of a disabled module without `var.enabled` or `try()` (`docs/stg-switch.md`).
- A committed secret, token, state file, `*.tfvars` or `.envrc.local` (`.gitignore`).

### Conventions (⚠️)

- Layout: one root per scope and provider, one state each; modules hold no state of their own. In a
  root, `main.tf` holds only its wiring; every other resource sits in a sibling file named for what it
  is (`docs/layout.md`).
- Placement: a value one root needs lives in that root; one several roots of an environment agree on
  lives in its `shared/`; a derivation every environment shares lives in `modules/`
  (`docs/shared-values.md`).
- A value one root produces and another needs crosses as a handoff object, never as a repository
  variable (`docs/crossing-roots.md`).
- Secret Manager ids join the four parts with `_`: `frubble_<env>_<domain>_<name>`
  (`terraform/modules/gcp/secret/main.tf`).
- OpenTofu, not Terraform: workflows call `tofu` through `opentofu/setup-opentofu` at `TOFU_VERSION`,
  roots keep `required_version` and lock files on `registry.opentofu.org` (`README.md`,
  `docs/getting-started.md`).
- A required check must always report: no path filter on a workflow whose job is required; a summary
  job when skipped jobs could count as passed (`docs/pipelines.md`, `Code Quality Summary` in
  `.github/workflows/code-quality.yml`).
- An output holding a secret is marked `sensitive`.
- `.tflint.hcl`, `.trivyignore.yaml` and `.yamllint.yaml`: a new ignore or a relaxed rule carries
  its reason; a `.trivyignore.yaml` entry has its id, narrowest path, statement and `expired_at`.
- A change to the bootstrap, the trust model, the pipelines, the stg switch or the variables a
  workflow reads with no matching change to `README.md` or `docs/`.

### Tests

There is no test suite. The checks are `tofu fmt`, `tofu validate`, tflint, actionlint, gitleaks
and trivy in `code-quality`, the title and body check in `pr-template`, and the plans in
`live-plan`. The tests lens checks that a change keeps them meaningful: a stack left out of the
plan, a check that can no longer fail, a scanner rule switched off, a required check renamed
without the ruleset following (`docs/pipelines.md`, _Required checks_).

### Docs per lens

| Lens        | Read                                                                                                                                   |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| security    | `docs/ci-authentication.md`, `docs/secrets.md`, `docs/human-access.md`, `.github/CODEOWNERS`, every changed workflow and `_setup` root |
| conventions | `docs/layout.md`, `docs/shared-values.md`, `.tflint.hcl`, `.yamllint.yaml`, neighbouring roots and modules                             |
| tests       | `.github/workflows/code-quality.yml`, `.github/workflows/live-plan.yml`, `.github/workflows/pr-template.yml`, `lefthook.yml`           |
| boundaries  | `docs/layout.md`, `docs/ci-authentication.md`, `docs/crossing-roots.md`, `terraform/modules` used by the changed roots                 |
| performance | the changed workflows: concurrency, cancellation, jobs that run when they need not                                                     |
| correctness | `docs/pipelines.md`, `docs/stg-switch.md`, `docs/dev-environment.md`, the variables and outputs the changed roots and workflows read   |
| intent      | the PR body, the issue it closes                                                                                                       |

### Leads

`principalSet`, `principal://`, `workflow_ref`, `job_workflow_ref`, `deploy_entry`, `actor_id`,
`roles/`, `members`, `id-token`, `permissions:`, `pull_request_target`, `${{ github.event.`,
`secrets.`, `@v` without a SHA, `curl` without a checksum, `sensitive`, `secret_data`,
`random_password`, `lifecycle`, `enabled`, `try(`, `STG_ENABLED`, `TF_APPLY_ENABLE_`,
`prevent_destroy`, `ignore_changes`, `count = 0`, `tflint-ignore`, `trivy:ignore`,
`# yamllint disable`, `--no-verify`, `TODO`, `FIXME`.

### Already checked elsewhere

`code-quality` runs fmt, validate, tflint, actionlint, gitleaks and trivy; `pr-template` checks the
title and the body's sections; `live-plan` plans every stack. Don't run them again and don't repeat
what they report.
