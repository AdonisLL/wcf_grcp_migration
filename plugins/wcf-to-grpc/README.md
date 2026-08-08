# wcf-to-grpc

Copilot CLI plugin that takes a legacy .NET WCF codebase to **gRPC for
.NET**: evidence-backed analysis, an explicit decision record, a
reviewable specification, and gated implementation ending with an affected
solution build, repository-local tests, and a structured code handoff.

Stage 0 records whether gRPC augments the existing solution or is created in
an isolated solution that references WCF read-only, contains an immutable WCF
test fixture, or contains only gRPC projects. WCF remains unchanged throughout.
Deployment,
environment provisioning, production/protected traffic, runtime parity
validation, cutover, live rollback, and WCF retirement are out-of-scope
offline activities — guidance for those activities is in
[migration-methodology.md](../../docs/migration-methodology.md).

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
  dependency-ordered implementation waves, and integration checkpoints ending
  with an affected solution build, repository-local tests, and a structured
  code handoff. It enforces every approval and artifact-state gate, keeps
  resumable run state in `orchestration-state.json`, and directly delegates
  each machine-owned stage to its owning custom agent.
  It writes no artifact but its own state, executes no commands, approves
  nothing, and cannot invoke `/fleet`, `/tasks`, or any other slash command.
  Parity validation, cutover, and retirement are out-of-scope offline
  activities not orchestrated by this agent.
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
  telemetry/health, streaming/state/transaction redesign, and repository-local
  tests — respecting fleet waves and bounded file ownership, keeping WCF
  runnable, and reporting spec deviations instead of guessing. It never edits
  migration artifacts or performs deployment, routing, cutover, live rollback,
  or WCF retirement work.
- [`agents/grpc-code-handoff-author.agent.md`](agents/grpc-code-handoff-author.agent.md)
  is the terminal code-only stage. It reconciles the approved specification,
  every implementation report, and the final repository-local build/test
  checkpoint into schema-valid `code-handoff.json` and `code-handoff.md`
  artifacts. It records exact local evidence, marks every operational obligation
  (`deployment`, `environment-parity-validation`, `consumer-cutover`,
  `live-rollback`, `wcf-retirement`, and more) as `not-executed` with an owner
  role and next action, and states explicitly that WCF remains active and
  unchanged. It never changes product code, executes commands, deploys, claims
  runtime parity, or authorizes an operational action.
- [`agents/grpc-parity-validator.agent.md`](agents/grpc-parity-validator.agent.md)
  independently decides whether a migrated gRPC service is a faithful,
  operable replacement for the WCF service it replaces. It executes builds,
  tests, contract-compatibility checks, and behavioral/security/streaming/
  performance probes across thirteen parity gates, produces blocking and
  non-blocking findings with stable IDs, evidence, trace links, confidence,
  and remediation, and assesses WCF retirement readiness. It is read-only
  with respect to application code, never fixes what it finds, writes only
  validation artifacts, and never approves retirement. **Invoke this agent
  manually after deploying to a test environment; it is not an orchestrated
  stage.**

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
- [`skills/finalize-code-handoff/`](skills/finalize-code-handoff/SKILL.md) defines
  the terminal handoff procedure: input validation rules, required coverage
  (deliverables, local validation results, code gaps, code rollback, and twelve
  categories of offline obligation), schema use guidance for
  [`schemas/code-handoff.schema.json`](schemas/code-handoff.schema.json), and
  output contract for `code-handoff.json` and `code-handoff.md`.
- [`skills/validate-grpc-parity/`](skills/validate-grpc-parity/) defines the
  independent parity-validation workflow for **optional manual use after
  deployment to a test environment**. It is not an orchestrated stage. Includes
  the thirteen-gate
  [parity checklist](skills/validate-grpc-parity/references/parity-checklist.md);
  [evidence, findings, and run-status rules](skills/validate-grpc-parity/references/evidence-and-findings.md);
  [safety controls](skills/validate-grpc-parity/references/golden-traffic-and-safety.md);
  the [WCF retirement gate](skills/validate-grpc-parity/references/retirement-gate.md);
  the [validation handoff contract](skills/validate-grpc-parity/references/validation-handoff.md);
  report/checklist/retirement templates; and a worked
  [example validation report](skills/validate-grpc-parity/examples/validation-report.example.md).

## Schemas, tests, and tooling

- [`schemas/`](schemas/) contains strict JSON Schema Draft 2020-12 contracts
  for inventory, decisions, persisted mappings, migration reviews,
  specifications/work packages, issue previews, orchestration run state, the
  code handoff (`code-handoff.schema.json`), and the
  [shared vocabulary](schemas/common.schema.json).
- [`tests/`](tests/) contains static legacy WCF fixture repositories, expected
  analysis/mapping/specification assertions, local validation instructions,
  and the authenticated Copilot CLI installation smoke test.
- [`scripts/Validate-Plugin.ps1`](scripts/Validate-Plugin.ps1) is the
  dependency-free validator used locally and by CI, with a
  [POSIX wrapper](scripts/validate-plugin.sh).
- [`scripts/Semantic-Digest.ps1`](scripts/Semantic-Digest.ps1) and
  [`scripts/semantic-digest-rules.v1.json`](scripts/semantic-digest-rules.v1.json)
  provide one versioned semantic-digest implementation for every stage.
  [`scripts/Validate-Artifact.ps1`](scripts/Validate-Artifact.ps1) provides
  machine-observed Draft 2020-12 validation for generated artifacts.

## Non-negotiable guarantees

- **gRPC for .NET is the fixed target.** No stage retargets to REST,
  CoreWCF, or messaging; constructs gRPC cannot express become explicit
  redesign risks and recorded decisions.
- **No implementation before an approved specification**, and no GitHub label,
  issue, or dependency mutation before the complete preview is confirmed by a
  human against its digest.
- **No parallel batch with overlapping or shared file ownership.** Shared and
  schema infrastructure is sequential and single-owner. Waves are computed
  from dependencies and checkpoint barriers, not assigned optimistically.
- **WCF is immutable.** Inventory-time content hashes protect WCF source,
  projects, configuration, activation, endpoints, and generated proxies even
  when files are initially untracked.
- **Approval is atomic and lifecycle-safe.** The reviewed semantic digest
  excludes mutable approval/execution state; approval records and promotes all
  scoped packages in one update.
- **Orchestration ends at code handoff.** The affected solution must build
  clean and repository-local tests must pass before the orchestrator declares
  the workflow complete. Deployment, production/protected traffic, runtime
  parity validation, cutover, live rollback, and WCF retirement are out-of-scope
  offline activities.
- **No secret value is ever written** into an artifact, report, evidence
  capture, or test, and no agent can invoke a Copilot CLI slash command.
