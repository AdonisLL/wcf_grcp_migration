# wcf-to-grpc

Copilot CLI plugin that takes a legacy .NET WCF codebase to **gRPC for
.NET**: evidence-backed analysis, an explicit decision record, a
reviewable specification, gated implementation, and independent parity
validation ending at a WCF retirement gate that will not open without proof.

Installation, quick-start prompts, troubleshooting, and the safety model live
in the [repository README](../../README.md). Deeper documentation:
[architecture](../../docs/architecture.md),
[migration methodology](../../docs/migration-methodology.md),
[output contracts](../../docs/output-contracts.md),
[contributing](../../docs/contributing.md).

## Agents

- [`agents/wcf-migration-orchestrator.agent.md`](agents/wcf-migration-orchestrator.agent.md)
  coordinates the whole migration: scope and target-runtime intake, read-only
  inventory, targeted interview, mapping, architecture and specification, the
  human approval gate, optional confirmation-gated issue publication,
  dependency-ordered implementation waves, integration checkpoints, independent
  parity validation, and the retirement gate. It enforces every approval and
  artifact-state gate, keeps resumable run state in `orchestration-state.json`,
  and directly delegates each machine-owned stage to its owning custom agent.
  It writes no artifact but its own state, executes no commands, approves
  nothing, and cannot invoke `/fleet`, `/tasks`, or any other slash command.
- [`agents/wcf-codebase-analyst.agent.md`](agents/wcf-codebase-analyst.agent.md)
  is read-only with respect to application code and writes only its validated
  inventory artifact.
- [`agents/wcf-migration-decision-interviewer.agent.md`](agents/wcf-migration-decision-interviewer.agent.md)
  batch-proposes safe evidence-backed recommendations, asks only irreducible
  focused blockers, and records exact-digest bundle approvals.
- [`agents/wcf-to-grpc-mapper.agent.md`](agents/wcf-to-grpc-mapper.agent.md)
  produces a deterministic, complete mapping artifact from the inventory and
  decision log.
- [`agents/grpc-migration-architect.agent.md`](agents/grpc-migration-architect.agent.md)
  turns validated evidence and proposed decisions into the target architecture,
  Protobuf contract specifications, migration roadmap, fleet-ready work
  packages, and consolidated review bundle. It writes migration artifacts only.
- [`agents/grpc-migration-issue-publisher.agent.md`](agents/grpc-migration-issue-publisher.agent.md)
  renders the full issue preview and performs duplicate-safe GitHub publication
  only after exact digest confirmation and explicit mutation permission.
- [`agents/grpc-migration-implementer.agent.md`](agents/grpc-migration-implementer.agent.md)
  implements exactly one approved, fleet-ready work package at a time from an
  approved `migration-spec.json` — `.proto`/codegen, gRPC for .NET
  hosting, adapters to existing business logic, clients, auth/authz,
  interceptors/errors, deadlines/cancellation/retries/idempotency,
  telemetry/health, streaming/state/transaction redesign, tests, and
  deployment — respecting fleet waves and bounded file ownership, preserving
  coexistence/rollback, and reporting spec deviations instead of guessing. It
  never edits migration artifacts and never retires WCF.
- [`agents/grpc-parity-validator.agent.md`](agents/grpc-parity-validator.agent.md)
  independently decides whether a migrated gRPC service is a faithful,
  operable replacement for the WCF service it replaces. It executes builds,
  tests, contract-compatibility checks, and behavioral/security/streaming/
  performance probes across thirteen parity gates, produces blocking and
  non-blocking findings with stable IDs, evidence, trace links, confidence,
  and remediation, and assesses WCF retirement readiness. It is read-only
  with respect to application code, never fixes what it finds, writes only
  validation artifacts, and never approves retirement.

## Skills

- [`skills/inventory-wcf-codebase/`](skills/inventory-wcf-codebase/) defines the
  evidence-backed, read-only WCF inventory workflow (staged discovery/tracing
  procedure, completion checklist, discovery patterns, and schema-use guidance)
  that emits output conforming to [`schemas/inventory.schema.json`](schemas/inventory.schema.json).
- [`skills/interview-migration-decisions/`](skills/interview-migration-decisions/)
  conducts a focused, evidence-driven architecture interview and persists
  stable, traceable decisions conforming to
  [`schemas/decision-log.schema.json`](schemas/decision-log.schema.json).
- [`skills/map-wcf-to-grpc/`](skills/map-wcf-to-grpc/) contains researched
  WCF-to-gRPC mapping guidance for
  [features](skills/map-wcf-to-grpc/references/feature-mapping.md),
  [Protobuf types](skills/map-wcf-to-grpc/references/protobuf-type-mapping.md),
  [security](skills/map-wcf-to-grpc/references/security-mapping.md),
  [errors and streaming](skills/map-wcf-to-grpc/references/error-and-streaming-mapping.md),
  and [hosting and rollout](skills/map-wcf-to-grpc/references/hosting-and-rollout.md),
  each traceable to the dated
  [source index](skills/map-wcf-to-grpc/references/sources.md).
- [`skills/author-migration-specs/`](skills/author-migration-specs/) defines
  deterministic assessment, decision, architecture, contract, roadmap, and
  work-package authoring, including the
  [architecture design checklist](skills/author-migration-specs/references/architecture-design-checklist.md),
  [work-package and dependency-graph patterns](skills/author-migration-specs/references/work-package-patterns.md),
  the [orchestrator handoff contract](skills/author-migration-specs/references/orchestrator-handoff.md),
  and a schema-valid
  [example specification](skills/author-migration-specs/examples/migration-spec.example.json).
- [`skills/publish-migration-issues/`](skills/publish-migration-issues/)
  defines deterministic issue rendering, full-set preview/approval gating,
  duplicate-safe GitHub publication, resumable dependency patching, and a
  schema-valid
  [example issue set](skills/publish-migration-issues/examples/issue-set.example.json).
- [`skills/implement-grpc-migration/`](skills/implement-grpc-migration/) defines
  the per-work-package implementation workflow, including the
  [implementation checklist](skills/implement-grpc-migration/references/implementation-checklist.md)
  covering `.proto`/codegen, hosting, adapters, clients, auth/authz,
  interceptors/errors, deadlines/retries/idempotency, telemetry/health,
  streaming/state/transaction redesign, tests, and deployment;
  [fleet execution and ownership](skills/implement-grpc-migration/references/fleet-execution-and-ownership.md)
  (including how the orchestrator plans and directly delegates safe waves, with
  Copilot CLI `/fleet` and `/tasks` remaining optional operator controls);
  [validation and gates](skills/implement-grpc-migration/references/validation-and-gates.md);
  and the [handoff report contract](skills/implement-grpc-migration/references/handoff-report-contract.md).
- [`skills/validate-grpc-parity/`](skills/validate-grpc-parity/) defines the
  independent parity-validation workflow, including the thirteen-gate
  [parity checklist](skills/validate-grpc-parity/references/parity-checklist.md);
  [evidence, findings, and run-status rules](skills/validate-grpc-parity/references/evidence-and-findings.md);
  [golden-traffic, privacy, and safety controls](skills/validate-grpc-parity/references/golden-traffic-and-safety.md);
  the [WCF retirement gate](skills/validate-grpc-parity/references/retirement-gate.md);
  the [validation handoff contract](skills/validate-grpc-parity/references/validation-handoff.md);
  report/checklist/retirement templates; and a worked
  [example validation report](skills/validate-grpc-parity/examples/validation-report.example.md).

## Schemas, tests, and tooling

- [`schemas/`](schemas/) contains strict JSON Schema Draft 2020-12 contracts
  for inventory, decisions, persisted mappings, migration reviews,
  specifications/work packages, issue previews, orchestration run state, and the
  [shared vocabulary](schemas/common.schema.json).
- [`tests/`](tests/) contains static legacy WCF fixture repositories, expected
  analysis/mapping/specification assertions, local validation instructions,
  and the authenticated Copilot CLI installation smoke test.
- [`scripts/Validate-Plugin.ps1`](scripts/Validate-Plugin.ps1) is the
  dependency-free validator used locally and by CI, with a
  [POSIX wrapper](scripts/validate-plugin.sh).

## Non-negotiable guarantees

- **gRPC for .NET is the fixed target.** No stage retargets to REST,
  CoreWCF, or messaging; constructs gRPC cannot express become explicit
  redesign risks and recorded decisions.
- **No implementation before an approved specification**, and no GitHub label,
  issue, or dependency mutation before the complete preview is confirmed by a
  human against its digest.
- **No parallel batch with overlapping or shared file ownership.** Shared and
  schema infrastructure is sequential and single-owner.
- **Parity is proven, never inferred.** A green build or an implementer's claim
  is not behavioral evidence.
- **WCF retirement stays blocked** until `validate-grpc-parity` produces a
  current `VRPT-*` report whose retirement outcome is `retirement-ready` for the
  deployed revision *and* a human records the retirement approval in the
  decision log.
- **No secret value is ever written** into an artifact, report, evidence
  capture, or test, and no agent can invoke a Copilot CLI slash command.
