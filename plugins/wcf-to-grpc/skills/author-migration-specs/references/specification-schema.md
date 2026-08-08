# Migration Artifact Contract Reference

This reference defines the upstream artifacts consumed and the specification
artifacts written by `author-migration-specs`. Normative machine validation is
provided by the JSON Schema Draft 2020-12 files in `../../../schemas/`:

- [`common.schema.json`](../../../schemas/common.schema.json)
- [`inventory.schema.json`](../../../schemas/inventory.schema.json)
- [`decision-log.schema.json`](../../../schemas/decision-log.schema.json)
- [`mapping-result.schema.json`](../../../schemas/mapping-result.schema.json)
- [`migration-spec.schema.json`](../../../schemas/migration-spec.schema.json)

All relative paths in artifacts use `/`, are repository-relative, and must
not contain drive letters, leading slashes, or `..` traversal.

## Default output layout

When no output directory is specified, read the three upstream inputs and write
only the specification outputs shown below:

```text
docs/wcf-grpc-migration/
  inventory.json                    read-only input (analyst-owned)
  decision-log.json                 read-only input (interviewer-owned)
  mapping-result.json               read-only input (mapper-owned)
  migration-spec.json
  assessment.md
  decisions.md
  target-architecture.md
  contracts/
    <service-id>.md
  roadmap.md
  work-packages/
    <work-package-id>.md
```

Lowercase stable IDs are safe filenames, for example
`contracts/spec-order-service.md` and
`work-packages/wp-order-service-server.md`. `issue-set.json` and its previews
are owned and written only by the publication agent and skill.

## Shared envelope

Every structured artifact contains:

| Field | Meaning |
|---|---|
| `schemaVersion` | Contract version. Initially `1.0.0`. |
| `artifactType` | The schema-specific type, including `inventory`, `decision-log`, `mapping-result`, or `migration-spec` for this stage's inputs and outputs. |
| `artifactId` | Stable artifact identifier. |
| `generation` | Generator identity/version, UTC generation time, source revision, canonical source digest, and full/incremental mode. |
| `approval` | Explicit artifact state: draft, review requested, approved, rejected, or superseded. |
| `citations` | Deduplicated evidence records used by the artifact. |
| `traceLinks` | Directed links between stable IDs across the migration lifecycle. |

Unknown repository facts use one of the schema's resolved-value objects:

```json
{ "state": "known", "value": ".NET 10" }
```

```json
{
  "state": "unknown",
  "reason": "No deployment manifest identifies the target runtime.",
  "questionIds": ["QST-target-runtime"]
}
```

Use `not-applicable` only when evidence establishes that the field does not
apply. Never use `"TBD"`, an empty string, `0`, or `null` as a substitute for
an unknown value unless that field's schema explicitly permits `null`.

## Stable identifier formats

IDs use an uppercase prefix and a lowercase kebab-case semantic key. Generate
the key from a canonical identity, not display text or discovery order.

| Prefix | Entity | Canonical identity example |
|---|---|---|
| `INV-` | Inventory artifact | repository identity |
| `DLOG-` | Decision-log artifact | repository identity |
| `MSPEC-` | Migration-spec artifact | repository identity plus target major version when versioned |
| `ISET-` | Issue-set artifact | migration-spec identity |
| `REPO-`, `SOL-`, `PRJ-`, `HOST-` | Repository topology | normalized repository-relative path |
| `SVC-` | WCF service | project path plus fully qualified contract symbol |
| `OP-` | Operation | service ID plus contract method signature |
| `DC-`, `FLD-` | Data contract and field | declaring type/member symbol |
| `END-`, `CON-`, `DEP-` | Endpoint, consumer, dependency | owning ID plus normalized address/name |
| `EVD-` | Evidence | normalized locator plus claim category |
| `RSK-`, `QST-`, `DEC-`, `OPT-` | Risk, question, decision, option | affected IDs plus semantic topic |
| `SPEC-`, `RPC-`, `MSG-`, `PF-` | Contract specification | owning service/message plus semantic name |
| `PHS-`, `WP-` | Roadmap phase and work package | stable purpose, never list position |
| `AC-`, `VAL-` | Acceptance criterion and validation | owning work package plus behavior |
| `ISSUE-`, `LBL-` | Issue payload and label | source work-package ID or label name |
| `VRPT-`, `VF-` | Validation report and validation finding | validated scope identity; finding key is gate slug plus defect semantics |
| `TRC-` | Trace link | from ID, relation, and to ID |

On collisions, append the first 8 lowercase hexadecimal characters of a
SHA-256 digest of the canonical identity. Once emitted, an ID is immutable:
preserve it across moves and renames by consulting the existing artifacts.
Never recycle an ID from a removed entity; mark the old entity or link
superseded instead. Issue IDs remain stable even after GitHub assigns an
issue number.

## Inventory fields

`inventory.schema.json` represents:

- analysis scope and whether the repository is server, client-only, or still
  unknown;
- solutions, projects, target frameworks, WCF references, and hosts;
- services and operations, including request/response/fault contracts,
  streaming shape, sessions, transactions, ordering, deadlines, and
  authorization;
- data/message/fault contracts and serialization-sensitive fields;
- endpoints, bindings, settings, behaviors, quotas, addresses, and security;
- consumers, generated proxies, upgrade control, and external dependencies;
- evidence-backed risks and explicit unknown questions.

Arrays may be empty during incremental discovery. A discovered service,
operation, contract, field, endpoint, consumer, or dependency must carry
evidence IDs. `analysisState: complete` means the declared scope was traced
through configuration and call sites; it does not mean runtime parity was
proved.

## Decision-log fields and approval

Each `DEC-*` records context, options, affected IDs, risks, evidence, owner,
approval events, and exactly one state:

- `unresolved`: no selected option; requires a reason, next action, and at
  least one `QST-*`;
- `proposed`: selected option and rationale exist, but approval is pending;
- `approved`: selected option, decision text, rationale, and an approved
  review record are required;
- `rejected`: records the rejected option and rejection review;
- `superseded`: points to the replacement decision.

An architectural choice is not approved merely because it appears in prose.
The structured decision and containing artifact must both be approved.
Unsupported WCF behavior may not be silently mapped to a non-gRPC target.
A temporary coexistence adapter is allowed only when gRPC remains the
approved destination and the adapter has explicit exit criteria.

## Migration-specification fields

`migration-spec.schema.json` contains four connected surfaces:

The root `solutionLayout` records whether implementation augments the existing
solution or creates an isolated solution that references WCF read-only, copies
an immutable WCF test fixture, or contains only gRPC projects. This field is
semantic and controls ownership and validation commands.

1. `assessment`: scope, complexity, services, dependencies, risks,
   constraints, unresolved questions, and evidence. Its rendered unresolved
   facts explain in plain language why each fact is needed and identify the
   concrete code or offline migration milestone that the fact blocks.
2. `targetArchitecture`: individually approved design sections plus topology
   nodes and edges. The schema requires exactly fifteen sections covering
   runtime, hosting, service boundaries, Protobuf/versioning, data types,
   errors, security, authorization, deadlines/retries, observability,
   health checks, deployment, coexistence, consumer cutover, and retirement.
   Per-topic content requirements are in
   [`architecture-design-checklist.md`](architecture-design-checklist.md).
3. `contracts`: per-service `SPEC-*` records containing RPC shapes, request
   and response messages, error/deadline/idempotency/authorization policies,
   source mappings, Protobuf fields, presence semantics, conversions,
   validation, and reserved field names/numbers.
4. `roadmap` and `workPackages`: ordered phases, dependency edges,
   integration checkpoints, deliverables, ownership, acceptance, validation,
   rollback, and coexistence. Readiness and dependency-graph rules are in
   [`work-package-patterns.md`](work-package-patterns.md).

The Protobuf field number is a resolved positive integer. Numbers 19000–19999
are forbidden. Regeneration must preserve every assigned number. When a
field is removed, copy both its number and name into `reservedNumbers` and
`reservedNames`; never assign them to another field.

## Work-package readiness and fleet suitability

Every `WP-*` defines:

- objective, bounded scope, and explicit non-goals;
- source inventory/spec/decision/risk IDs;
- hard, soft, and integration dependencies with current state;
- deliverable paths and actions;
- acceptance criteria linked to concrete validation steps;
- rollback triggers and ordered recovery steps;
- local side-by-side compatibility plus offline coexistence/routing guidance,
  duration/exit condition, and legacy endpoint status;
- integration checkpoints and evidence expectations.

Fleet suitability is one of:

- `eligible`: safe for a declared parallel wave and group, with bounded
  `exclusive-write`, `shared-read`, or `integration-owner` paths;
- `sequential`: ordered code work, normally shared contracts/infrastructure,
  schema evolution, solution integration, or final local verification;
- `ineligible`: too coupled or risky for parallel execution;
- `unknown`: analysis is incomplete and the package is not executable.

Two fleet-eligible packages must not claim overlapping `exclusive-write`
paths. Shared generated files, solution files, package-management files,
common `.proto` contracts, hosting bootstrap, database migrations, and final
local verification require one integration owner unless the specification proves a
disjoint boundary. Approval does not waive unresolved ownership conflicts.

## Acceptance criteria and validation

Acceptance criteria are observable outcomes, not implementation tasks. Each
`AC-*` states the required evidence and references one or more `VAL-*`
steps. Validation entries specify the kind, exact command when executable,
repository-relative working directory, expected result, status, and evidence.

Use the narrowest existing build/test/lint/compatibility commands that prove
the criterion. Manual checks must state what is inspected and what constitutes
success. Include contract compatibility, authorization, error mapping,
deadline/cancellation, serialization edge cases, local WCF/gRPC compatibility,
and code-revert checks where relevant. A static inspection cannot set runtime validation
to `passed`.

## Rollback and coexistence

Each package has rollback and coexistence objects even when not applicable.
Use explicit `not-applicable` resolved values with a reason rather than
omitting them.

Rollback specifies triggers, ordered steps, data impact, owner, and
validation. During coexistence, keep the WCF endpoint routable until exit
criteria are met. Any database or Protobuf evolution needed during the
coexistence window must be additive and backward compatible. WCF retirement
requires explicit approval and independent parity evidence.

## Evidence citations

Each `EVD-*` has a claim, kind, locator, confidence, and optional symbol or
excerpt digest. Prefer repository-relative locators:

```text
src/Orders/IOrderService.cs#L12-L37
src/Orders/web.config#L80-L104
```

For user-provided facts use `kind: user-statement` and a locator such as
`user-statement:target-runtime-review`. Cite only the smallest useful span.
Do not copy secrets or sensitive payloads into citations. A Markdown claim
uses an inline reference such as `[EVD-order-service-contract]` and the
document's Evidence section resolves that ID to its locator and claim.

## End-to-end trace links

`TRC-*` links use a typed `from`, relation, typed `to`, state, and supporting
evidence IDs. Build this chain wherever applicable:

```text
inventory item
  -> risk or question
  -> approved decision
  -> contract/architecture specification
  -> work package
  -> issue payload
  -> implementation report
  -> validation report
```

Use `raises`, `resolved-by`, `specified-by`, `depends-on`, `published-as`,
`implemented-by`, and `validated-by` consistently. A missing downstream
artifact is represented by an unresolved link or omitted future link, never
by a fabricated ID.

## Issue-set fields

`issue-set.schema.json` carries target repository, label definitions, stable
issue payloads, work-package dependencies, acceptance/validation IDs, fleet
and ownership metadata, and GitHub publication results. Publication states
are `draft`, `previewed`, `approved`, `published`, or `declined`.

The digest approved by the user must match the preview being published.
`github` is `null` until publication succeeds. Creating labels or issues is
outside this skill and requires separate explicit confirmation.

## Deterministic regeneration

1. Treat structured JSON as source of truth; render Markdown from it.
2. Load prior artifacts before generation and preserve IDs, field numbers,
   reserved values, approvals, GitHub numbers, and supersession history.
3. Canonicalize repository paths to `/`; never emit machine-specific absolute
   paths.
4. Sort object keys in JSON. Sort ID-based collections lexicographically;
   sort roadmap phases by `sequence` then ID, Protobuf fields by known number
   then ID, and dependency edges by target ID.
5. Use UTF-8, LF line endings, one trailing newline, and two-space JSON
   indentation.
6. Compute `sourceDigest` from the canonical scoped inputs, citations,
   decisions, and generator version. If the digest and semantic output are
   unchanged, do not rewrite files or update `generatedAt`.
7. If semantics change, regenerate all affected JSON and Markdown together.
   Do not preserve manual Markdown edits; make durable changes in structured
   artifacts or approved decisions.
8. Never overwrite approved content with a contradictory inferred value.
   Mark it stale, add evidence, and open or supersede a decision.
9. Never renumber Protobuf fields or reorder work solely because discovery
   order changed.

Before reporting success, parse every JSON file, validate artifacts against
their schemas when instances exist, check schema self-consistency with an
available Draft 2020-12 validator, and verify every relative Markdown link.

## Related references

- [`architecture-design-checklist.md`](architecture-design-checklist.md) —
  per-topic content requirements and cross-cutting redesigns.
- [`work-package-patterns.md`](work-package-patterns.md) — work-package
  readiness, dependency graph, fleet waves, and validation patterns.
- [`orchestrator-handoff.md`](orchestrator-handoff.md) — request/response
  contract with the orchestrator.
- [`../examples/migration-spec.example.json`](../examples/migration-spec.example.json)
  — a schema-valid specification showing these rules applied.
