# Output contracts

Everything the plugin writes, where it writes it, which schema governs it, who
owns it, and what "approved", "stale", and "current" mean for each artifact.

For the process that produces these files see
[migration-methodology.md](migration-methodology.md).

## 1. Output directory

All generated content lands under one directory in the repository being
migrated. The default is `docs/wcf-grpc-migration/`; every stage accepts an
override and states the default it assumed.

```text
docs/wcf-grpc-migration/
├── orchestration-state.json          Orchestrator run state (resumability)
├── migration-status.md               Optional rendered run status
├── inventory.json                    Evidence-backed legacy inventory
├── decision-log.json                 Decisions, options, approvals
├── migration-spec.json               Architecture, contracts, roadmap, work packages
├── issue-set.json                    Issue-ready payloads and publication state
├── assessment.md                     Rendered current-state assessment
├── decisions.md                      Rendered decision view
├── target-architecture.md            Rendered architecture and topology
├── roadmap.md                        Rendered phases, waves, retirement gates
├── contracts/
│   └── <spec-id>.md                  Rendered per-service contract specification
├── work-packages/
│   └── <work-package-id>.md          Rendered implementable work package
├── implementation-reports/
│   ├── <work-package-id>.md          Implementer handoff report
│   ├── <work-package-id>.claim.json  Ownership claim marker
│   └── checkpoint-<phase-id>.md      Integration checkpoint reconciliation
└── validation-reports/
    ├── <scope-key>.md                Validation report (gate matrix, findings)
    ├── <scope-key>.checklist.md      Filled parity checklist
    ├── retirement-readiness.md       Retirement assessment (retirement runs)
    ├── evidence/<scope-key>/<EVD-id>.txt   Redacted command captures
    └── harness/<scope-key>/          Optional permission-gated probe harness
```

Every path is deterministic from the identity of the thing it describes — a
work-package id, a phase id, a scope key — so parallel runs never collide and a
re-run overwrites its own file rather than creating a variant.

## 2. Artifact ownership

Exactly one stage may write each artifact. Every other stage reads it.

| Artifact | Written by | Read by |
|---|---|---|
| `orchestration-state.json` | Orchestrator | Orchestrator, humans |
| `inventory.json` | Specification stage, from the analyst's output | Interview, mapping, architect, validator |
| `decision-log.json` | Interview stage | Mapping, architect, implementer, validator |
| `migration-spec.json` | Architect | Publication, implementer, validator |
| `issue-set.json` | Publication stage | Humans, GitHub |
| `implementation-reports/*` | Implementer | Orchestrator, validator, humans |
| `validation-reports/*` | Validator | Orchestrator, architect, implementer, humans |

Upstream artifacts are never edited by a downstream stage. An implementer that
disagrees with the spec reports a deviation; a validator that finds a defect
raises a finding. Neither rewrites the artifact.

## 3. Schemas

Strict JSON Schema Draft 2020-12, `additionalProperties: false` throughout, in
[`plugins/wcf-to-grpc/schemas/`](../plugins/wcf-to-grpc/schemas/):

| Schema | Governs |
|---|---|
| [`common.schema.json`](../plugins/wcf-to-grpc/schemas/common.schema.json) | Shared vocabulary: stable ids, relative paths, resolved values, generation, approval, citations, trace links, acceptance criteria, validation steps |
| [`inventory.schema.json`](../plugins/wcf-to-grpc/schemas/inventory.schema.json) | `inventory.json` |
| [`decision-log.schema.json`](../plugins/wcf-to-grpc/schemas/decision-log.schema.json) | `decision-log.json` |
| [`migration-spec.schema.json`](../plugins/wcf-to-grpc/schemas/migration-spec.schema.json) | `migration-spec.json` |
| [`issue-set.schema.json`](../plugins/wcf-to-grpc/schemas/issue-set.schema.json) | `issue-set.json` |
| [`orchestration-state.schema.json`](../plugins/wcf-to-grpc/schemas/orchestration-state.schema.json) | `orchestration-state.json` |
| [`fixture-expectations.schema.json`](../plugins/wcf-to-grpc/tests/fixtures/fixture-expectations.schema.json) | Test fixture `expected.json` files |

Implementation and validation reports are Markdown rendered from checked-in
templates rather than schema-validated JSON; their contracts are documented in
[`handoff-report-contract.md`](../plugins/wcf-to-grpc/skills/implement-grpc-migration/references/handoff-report-contract.md)
and
[`validation-handoff.md`](../plugins/wcf-to-grpc/skills/validate-grpc-parity/references/validation-handoff.md).

## 4. Resolved values: known, unknown, not-applicable

Optional scalars are never bare. They are objects that say which of three
things is true:

```json
{ "state": "known", "value": "wsHttpBinding" }
{ "state": "unknown", "reason": "No binding configuration was found for this endpoint.",
  "questionIds": ["QST-order-endpoint-binding"] }
{ "state": "not-applicable", "reason": "The repository is client-only." }
```

`"TBD"`, `""`, `0`, and `null` are never substitutes for an unknown. This is
what makes "we do not know yet" survive every downstream stage instead of
silently becoming a fact.

## 5. Stable identifiers

Identifiers are semantic and permanent. Grammar:
`PREFIX-lowercase-kebab-segments`. Once emitted, an id is immutable — it
survives moves, renames, and regeneration.

| Prefix | Meaning |
|---|---|
| `INV-`, `DLOG-`, `MSPEC-`, `ISET-` | The four core artifacts |
| `ORUN-` | Orchestration run |
| `REPO-`, `SOL-`, `PRJ-`, `HOST-` | Repository topology |
| `SVC-`, `OP-`, `DC-`, `FLD-` | WCF service, operation, data contract, field |
| `END-`, `CON-`, `DEP-` | Endpoint, consumer, external dependency |
| `EVD-` | Evidence citation |
| `RSK-`, `QST-` | Risk, open question |
| `DEC-`, `OPT-`, `APV-` | Decision, option, approval record |
| `SPEC-`, `RPC-`, `MSG-`, `PF-` | Contract specification, RPC, message, proto file |
| `PHS-`, `WP-` | Roadmap phase, work package |
| `AC-`, `VAL-` | Acceptance criterion, validation step |
| `ISSUE-`, `LBL-` | Issue payload, label |
| `IMP-` | Implementation record |
| `VRPT-`, `VF-` | Validation report, validation finding |
| `TRC-` | Trace link |
| `BLK-`, `OBS-` | Orchestrator blocking item, observation |
| `FIX-` | Test fixture expectation |

On a genuine collision, append the first eight lowercase hex characters of a
SHA-256 digest of the canonical identity. Never renumber to resolve a
collision.

## 6. Traceability

```text
EVD-* ─▶ RSK-*/QST-* ─▶ DEC-* ─▶ SPEC-*/architecture section ─▶ WP-*/AC-*/VAL-*
      ─▶ ISSUE-* ─▶ implementation report ─▶ VRPT-*/VF-* ─▶ retirementCriteria
```

- Every legacy-system claim cites at least one `EVD-*` with a
  repository-relative locator (`path#Lstart-Lend`), an optional symbol, a kind,
  and a confidence of `high`, `medium`, or `low`.
- Every redesign links the `RSK-*` that forced it and the `DEC-*` that
  authorized it.
- Every work package names its source, spec, decision, and risk ids.
- Every acceptance claim names the `AC-*` and the `VAL-*` evidence proving it.
- A missing downstream artifact is an **unresolved link**, never an invented
  id.

The validator enforces the identifier grammar and checks that work-package and
issue dependency graphs are acyclic.

## 7. Approval semantics

The `approval` object has exactly four shapes, defined in `common.schema.json`:

| State | Required fields | Meaning |
|---|---|---|
| `draft` | — | Generated, not submitted for review |
| `review-requested` | `requestedAt`, `requestedFrom` | Awaiting a named reviewer |
| `approved` | `approvedAt`, `approvedBy` | A human accepted it |
| `rejected` | `rejectedAt`, `rejectedBy`, `reason` | A human rejected it, with a reason |

Rules that hold everywhere:

- **No agent ever writes `approved`.** Approval is recorded from an explicit
  human act, with the approver named. An approver is never inferred.
- **Artifact approval and item approval are separate.** Publishing an issue
  needs the `migration-spec.json` artifact approved *and* the individual work
  package approved.
- **Retirement approval is separate again** — a distinct decision in the
  decision log referencing the `VRPT-*` report it relies on.
- `draft`, `review-requested`, `rejected`, `superseded`, and absent all mean
  "not approved".

## 8. Freshness and staleness

Every artifact carries a `generation` block: `generator`, `generatorVersion`,
`generatedAt`, `sourceRevision`, `sourceDigest` (`sha256:<64 hex>`), and `mode`
(`full` or `incremental`).

- **Determinism.** Re-running a stage with unchanged inputs produces
  byte-identical output and reports `changed: false`. `generatedAt` is not
  bumped when the source digest and semantics are unchanged.
- **Staleness.** If an upstream artifact's digest changes after a downstream
  artifact was produced, the downstream artifact is `stale`, and any approval
  that depended on it is invalidated. The owning stage must re-run before
  anything downstream advances.
- **Validation evidence must match the deployed revision.** Evidence produced
  against an older revision is `blocked`, never `pass`.

## 9. Orchestration state

`orchestration-state.json` is the orchestrator's only writable artifact and the
single thing needed to resume a migration. It records the run id, scope,
repository kind, resolved target runtime, and permissions; per-stage status
(`not-started`, `in-progress`, `blocked`, `complete`, `stale`, `skipped`) with
owner and result summary; artifact states with path, digest, approval state and
freshness; blocking items (`BLK-*`) with kind, what they block, the ids that
clear them, owner, and next action; the wave plan with each package's dispatch
mode, dispatch state, and report status; validation runs with status and
retirement outcome; approvals **observed** (never granted); observations
(`OBS-*`) including recorded prompt-injection attempts; and the single next
required action with its owner.

On every invocation the orchestrator re-derives gates from the artifacts on
disk rather than trusting the stored status, so a stale or hand-edited state
file cannot unlock a gate.

## 10. Issue set and publication state

`issue-set.json` holds the rendered issue bodies, labels, dependency links, and
the publication record. Its safeguards are contractual:

- The preview covers **every** approved work package in scope and carries a
  `previewDigest`.
- Mutation requires a confirmation object whose digest matches the current
  preview, with explicit `allowLabelCreation`, `allowIssueCreation`, and
  `allowDependencyPatch` flags.
- Issue bodies embed their `ISSUE-*`, `WP-*`, `MSPEC-*`, and `ISET-*` ids in an
  HTML comment header, which is how duplicates are detected on re-run.
- Partial successes persist, so publication resumes instead of double-posting.
- No credential is collected, transformed, or stored.

## 11. Validation reports and evidence

A validation report records all thirteen gate states, blocking findings first,
coverage counts, the mechanically computed run status, assumptions, and the
single next required action. Every gate result and finding cites `EVD-*`
evidence with the exact command, working directory, and a **redacted** capture
stored under `validation-reports/evidence/`, so anyone can re-run it.

Findings use `VF-<gate>-<semantic-key>` and carry kind (`defect` or
`evidence-gap`), severity (`blocking`/`non-blocking`), confidence, affected
ids, observed-versus-expected, evidence, trace links, remediation, owner, and
next action.

## 12. Secrets and personal data

No artifact ever contains a credential value, token, private key, certificate
content, connection string, or `Authorization` header value. Agents cite the
location of a secret and redact the value; redaction happens at write time, not
as a cleanup pass. A secret found exposed in the product is itself a blocking
finding. Golden traffic is masked by default and used only under recorded
permission with stated retention and deletion.

## 13. Checking artifacts yourself

The plugin's own validator checks the plugin, not your generated artifacts. To
check a generated artifact against its schema locally with PowerShell:

```powershell
Test-Json -LiteralPath .\docs\wcf-grpc-migration\migration-spec.json `
          -SchemaFile .\plugins\wcf-to-grpc\schemas\migration-spec.schema.json
```

A schema-valid artifact is not an approved artifact, and an approved artifact
is not a validated migration. Those are three separate gates, in that order.
