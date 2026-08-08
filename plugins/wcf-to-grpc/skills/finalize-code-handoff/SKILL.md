---
name: finalize-code-handoff
description: Produces the terminal code-only migration handoff from approved specifications, complete implementation reports, and successful repository-local build/test evidence. It writes schema-valid code-handoff.json and code-handoff.md only, records exact code deliverables and local results, and transfers deployment, environment parity validation, consumer cutover, live rollback, and WCF retirement as explicit not-executed owner actions without claiming operational readiness.
---

# Finalize code handoff

The authoritative JSON must conform to
[`../../schemas/code-handoff.schema.json`](../../schemas/code-handoff.schema.json).
Render the companion view with
[`templates/code-handoff.md`](templates/code-handoff.md).

## Inputs

1. Current approved `migration-spec.json` and review-bundle digest.
2. Every in-scope implementation report.
3. The final sequential integration-checkpoint report.
4. Repository revision and migration output directory.
5. Out-of-scope decisions, risks, architecture guidance, and offline
   dependencies that must be covered.

## Rules

- Validate all inputs before writing output.
- Do not execute commands or infer results. Copy exact commands, outcomes,
  revision, and evidence from current reports.
- Block when any package is partial/blocked, the final checkpoint did not
  successfully build every affected project/solution, a required
  repository-local test did not pass, or report revisions conflict.
- Write only `code-handoff.json` and `code-handoff.md`.
- Never include secret values. Use configuration keys and secret-store
  references only.
- Every operational obligation uses `executionState: not-executed`.
- Never claim deployment readiness, environment parity, cutover authorization,
  rollback completion, or WCF retirement readiness.
- State explicitly that WCF remains active and unchanged by this workflow.

## Required coverage

Record:

- source revision, approved spec/review digest, and code-completion status;
- projects and files created/modified;
- contract/package locations and local run instructions;
- exact local validation commands and observed outcomes;
- deviations and unresolved code gaps;
- code revert/local compatibility instructions;
- environment configuration and secret references;
- deployment and service-discovery guidance;
- identity, authorization, TLS/certificate, data/state, and external dependency
  obligations;
- observability, health, capacity, and SLO checks;
- environment parity and protected-traffic validation recommendations;
- consumer migration and cutover sequence;
- live rollback runbook;
- WCF retirement prerequisites; and
- owner role, next action, source IDs, and status for every offline obligation.

Use stable `CHOFF-*` and `OBL-*` IDs. Render a concise Markdown view from the
same JSON content; JSON is authoritative.

## Output

Return artifact paths, artifact ID, source revision, source digest, local
validation summary, unresolved code-gap count, offline obligation count, and
schema-validation result. A blocked response contains no success claim.
