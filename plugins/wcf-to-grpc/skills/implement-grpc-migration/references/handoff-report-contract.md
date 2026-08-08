# Handoff Report Contract

The request/response contract between the caller (the
`wcf-migration-orchestrator` agent, or a human operator invoking this stage
directly) and this implementation stage, plus the
completion report every run must produce. This mirrors the discipline of
`author-migration-specs`'s
[`orchestrator-handoff.md`](../../author-migration-specs/references/orchestrator-handoff.md)
for the implementation stage, and extends the "Completion report expected
from implementers" section of
[`work-package-patterns.md`](../../author-migration-specs/references/work-package-patterns.md#completion-report-expected-from-implementers).

## Preconditions the caller must satisfy

1. `migration-spec.json` exists, validates against
   [`migration-spec.schema.json`](../../../schemas/migration-spec.schema.json),
   and the assigned work package(s) are `status: approved` with
   `approval.state: approved`.
2. Every `hard` dependency of the assigned package(s) is `satisfied`.
3. The repository working tree is in a known, clean-enough state to attribute
   changes to this run (uncommitted, unrelated changes should be called out
   if present).
4. Exactly one work package is assigned, or a small explicit set the caller
   asserts is wave-and-ownership safe per `fleetPlan`.

If a precondition fails, this agent returns `status: blocked` in its handoff
report and writes no application file.

## Inbound assignment (what the caller provides)

```json
{
  "stage": "implement-grpc-migration",
  "repositoryRoot": ".",
  "migrationSpecPath": "docs/wcf-grpc-migration/migration-spec.json",
  "workPackageIds": ["WP-order-service-server"],
  "mode": "implement",
  "constraints": {
    "allowNetwork": false
  }
}
```

- `workPackageIds` with more than one entry is only valid when every entry
  shares the same `fleet.wave` and none conflicts with another per
  `conflictsWithWorkPackageIds`.
- `mode` is `implement` (do the work) or `resume` (continue from a prior
  partial report for the same package). Unknown/omitted fields fall back to
  the documented defaults (`migrationSpecPath` =
  `docs/wcf-grpc-migration/migration-spec.json`, `mode` = `implement`).

## Outbound handoff report

Written to
`docs/wcf-grpc-migration/implementation-reports/<work-package-id>.md` using
[`../templates/handoff-report.md`](../templates/handoff-report.md), and
summarized to the caller as short readable text. The report always contains:

| Field | Content |
|---|---|
| `status` | `completed`, `blocked`, or `partial` (see semantics below) |
| Changed projects/files | Every project and file created/modified/deleted, each tagged with its `deliverables` action and ownership mode |
| Commands executed | Exact command, working directory, and result for every `VAL-*` step actually run, plus the final integration checkpoint build/test commands |
| Acceptance evidence | Per `AC-*`: met/not-met, and the concrete evidence observed |
| Assumptions | Anything inferred because the spec did not state it explicitly, flagged for review |
| New risks/decisions discovered | Anything found during re-reading current code that the spec did not anticipate |
| Code gaps / deviations from the package | Any place the implementation could not follow the spec exactly, and why |
| Code rollback | Exact `git revert` or file-removal steps that undo this package's changes; confirmation (via local build result) that reverting leaves WCF and shared projects compilable and runnable |
| Offline dependencies | Every NuGet package reference, SDK version, and tooling version the new projects require, listed for pre-fetch in restricted environments |
| Coexistence state | Confirmation the legacy WCF endpoint is untouched and locally runnable, matching the package's `coexistence` plan |
| Final integration checkpoint result | Build command, test command, working directory, and outcome; explicit statement that this is not runtime parity or deployment-readiness evidence |
| Next required action | The single most important next step for the caller |

### Status semantics

| `status` | Meaning |
|---|---|
| `completed` | Every deliverable's action was performed, every linked `VAL-*` ran and passed, the final integration checkpoint build/tests passed, and every `AC-*` has its required evidence. This status does **not** constitute runtime parity or deployment-readiness evidence. WCF decommissioning is an offline handoff topic; this status has no bearing on it. |
| `partial` | Some deliverables/criteria are done; others are blocked by a named, non-fatal gap (for example a soft dependency still in flight) with an owner or next action. |
| `blocked` | A precondition, ownership conflict, spec deviation, or missing decision prevents the package (or a specific deliverable within it) from proceeding. No unauthorized file was changed. |

A report never sets its own package to `status: approved` in
`migration-spec.json` — this agent does not edit that file at all. Status in
the handoff report is this agent's own claim about what it did; a human or the
orchestrator agent reconciles it with the spec's `workPackage.status`
separately.

## Reporting a spec deviation or blocking gap

Use this shape inside the handoff report's body for each blocking item:

```text
Kind: spec-deviation | missing-decision | ownership-conflict | dependency-not-satisfied | validation-gap
Blocks: <deliverable path or AC-* id>
What was found: <the actual current code/config vs. what the spec assumed>
Why it blocks: <what cannot be safely implemented as a result>
Next action: <the smallest concrete step that unblocks it — e.g. "author-migration-specs must re-run for SPEC-order-service" or "record DEC-* for idempotency key format">
```

Never resolve one of these yourself by picking a plausible answer. Report it
and stop that deliverable; continue with the rest of the package's
deliverables that are unaffected.

## Invariants this stage guarantees

- Only paths inside the assigned package's `exclusive-write`/confirmed
  `integration-owner` ownership are created, modified, or deleted.
- No deployment manifests, IaC, CI/CD pipelines, routing rules, cutover
  steps, live rollback, or WCF changes are made. WCF remains
  untouched and locally runnable; its decommissioning is an offline
  handoff topic outside this skill.
- `inventory.json`, `decision-log.json`, `migration-spec.json`, and
  `issue-set.json` are never edited.
- The handoff report path is deterministic from the work package's own ID,
  so parallel fleet runs never collide on it.
- No validation step is marked `passed` without having actually run.
- The final sequential integration checkpoint (build + repo-local tests) ran
  and its result is recorded; the report explicitly disclaims runtime parity
  and deployment readiness.
- Rollback is documented as code-revert steps with a local build result;
  no live operational steps are included.
- Offline dependencies (packages, SDK versions) are listed.
- WCF decommissioning is an offline handoff topic outside this skill's
  boundary; this implementer has no role in it.
- No secret value appears in the report or in any changed file.

## Downstream consumers of this report

| Consumer | Uses | Not permitted here |
|---|---|---|
| Caller/orchestrator | `status`, blocking items, and next action to decide the next dispatch | This agent does not dispatch other work packages itself |
| [`validate-grpc-parity`](../../validate-grpc-parity/SKILL.md) | Changed files and acceptance evidence as a starting point for independent verification | This agent's own validation is not a substitute for that stage |
| A human reviewer | Deviations and new risks/decisions to fold back into the decision log or spec | This agent does not update the decision log or spec itself |
