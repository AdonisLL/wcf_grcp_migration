# Work Package and Dependency-Graph Patterns

Normative rules for `roadmap` and `workPackages` in
[`migration-spec.schema.json`](../../../schemas/migration-spec.schema.json).
Phase sequencing follows
[hosting-and-rollout.md](../../map-wcf-to-grpc/references/hosting-and-rollout.md).

A work package is a contract with an implementer that may never speak to you.
It is complete when a competent agent can execute it from the package alone,
using only the linked specification, without asking a new question and without
touching a file another package owns.

## Executable boundary

**Every `WP-*` package must produce repository source code, compiled tests, or
checked-in local configuration.** A work package's `deliverables` may only
`create`, `modify`, `delete`, or `verify` files in the repository. Work
packages may not:

- perform production traffic shifts or cutover actions;
- retire, remove, or deactivate WCF endpoints in a live environment;
- mutate running deployment environments;
- capture or replay production traffic;
- authorize any action that requires a separate operational authority.

Deployment-era operations (production cutover, WCF endpoint removal, WCF
retirement) are **non-executable offline guidance** recorded in
`roadmap.retirementCriteria` and the `deployment`, `coexistence`,
`consumer-cutover`, and `retirement` architecture sections. They describe
observable gates and named approval prerequisites; they never become `WP-*`
packages. A final integration-verification work package (see canonical catalog)
is the last executable wave before offline guidance takes over.

## Definition of ready

A package may leave `draft` only when all of the following hold.

1. **Identity.** Stable `WP-*` ID derived from purpose (`WP-order-service-server`),
   never from list position. Renaming the objective does not renumber the ID.
2. **Objective and bounded scope.** One coherent outcome; `scope` lists what is
   built; `nonGoals` names the adjacent work that belongs to another package
   (explicitly including "do not modify shared proto contracts" where true).
3. **Traceability.** `sourceIds` (inventory), `specIds`, `decisionIds`,
   `riskIds`, and `evidenceIds` are populated wherever they apply.
4. **Dependencies.** Every prerequisite is listed with `type` and `reason`; the
   full graph is acyclic; no dependency is on a package that does not exist.
5. **Ownership.** `fleet.fileOwnership` lists every path the package writes
   (`exclusive-write`), reads without writing (`shared-read`), or coordinates
   (`integration-owner`), each with a reason.
6. **Deliverables.** Repository-relative paths with `create`/`modify`/`delete`/
   `verify` actions and a one-line description.
7. **Acceptance.** Observable outcomes with required evidence and at least one
   `VAL-*` each.
8. **Validation.** Exact commands where knowable, otherwise a `manual` step that
   states what is inspected and what constitutes success.
9. **Rollback and coexistence.** Present even when not applicable, using
   `not-applicable` resolved values with a reason.
10. **Integration checkpoints.** The synchronization points after which parallel
    work is reconciled.
11. **No blocking unknowns.** Any blocking `QST-*` leaves the package `draft`
    (or `blocked` after approval) and is reported to the caller.

## Dependency graph rules

- `hard`: the dependent cannot start (compilation, contract, or infrastructure
  prerequisite). `soft`: it can start but cannot complete or merge cleanly.
  `integration`: it must reconcile at a checkpoint even though neither blocks
  the other.
- The directed graph over `dependencies[].workPackageId` **must be acyclic**.
  Verify with a topological sort before reporting completion; report the cycle
  members verbatim if one exists. Two packages that need each other are one
  package or need a third shared package extracted.
- A package may depend only on packages inside the same specification.
- `fleet.wave` equals one plus the maximum wave of its `hard` and `soft`
  dependencies. Wave 1 packages have no unsatisfied prerequisites.
- `dependencies[].state` is `pending` until the prerequisite is completed,
  `satisfied` when it is, `blocked` when the prerequisite is blocked, and
  `waived` only with an approved decision that explains the risk.

## Fleet suitability

| Suitability | Use when | Requirements |
|---|---|---|
| `eligible` | Independent slice with disjoint writes | Known `wave` and `parallelGroup`, at least one `fileOwnership` entry, no overlapping `exclusive-write` path with any other eligible package in the same wave |
| `sequential` | Shared foundations, schema evolution, cutover, retirement | Rationale naming the shared surface and its single owner |
| `ineligible` | Coupling or risk makes parallel execution unsafe | Rationale naming the coupling |
| `unknown` | Analysis incomplete | Blocking questions listed; the package is not executable |

Ownership conflicts are computed, not asserted: intersect the `exclusive-write`
sets of every pair in a wave, and record each collision in
`conflictsWithWorkPackageIds` on both packages. The following surfaces default
to `sequential` with a single integration owner unless the specification proves
disjointness: solution and build files, central package management, shared
`.proto` contracts and generated-code configuration, host bootstrap and DI
composition, cross-cutting interceptors, authentication/authorization
configuration, database or shared-state migrations, reverse-proxy or gateway
routing, and final cutover or retirement.

## Canonical package catalog

Adapt the catalog to the inventory; do not emit packages for constructs the
repository does not have. Waves are typical, not fixed.

| Package | Typical wave | Fleet | Purpose |
|---|---|---|---|
| `WP-foundation-proto-conventions` | 1 | sequential | Proto layout, package naming, versioning policy, shared types (decimal, money, IDs), generated-code configuration, compatibility check tooling |
| `WP-foundation-host-bootstrap` | 1 | sequential | Kestrel host on modern .NET, HTTP/2/TLS, configuration, DI composition, project structure |
| `WP-foundation-cross-cutting` | 2 | sequential | Error-mapping interceptor, authentication/authorization policies, logging/tracing/metrics, health checks, deadline and cancellation plumbing |
| `WP-<service>-contract` | 2–3 | eligible per service | The service `.proto`, message mappings, reservations, generated-code registration |
| `WP-<service>-server` | 3–4 | eligible per service | Service implementation delegating to existing business logic, request/response conversion, validation, error mapping |
| `WP-<service>-state-redesign` | 3–4 | sequential when shared store | Session/instance-state replacement, store schema, TTL, concurrency |
| `WP-<service>-consistency-redesign` | 3–4 | sequential | Saga/outbox/compensation replacing distributed transactions or reliable sessions |
| `WP-<service>-parity-tests` | 4 | eligible per service | Contract, behavior, fault, serialization, authorization, deadline, and streaming tests defined by the spec |
| `WP-coexistence-routing` | 3 | sequential | Side-by-side endpoint routing configuration and consumer-switchable traffic control (produces repository-resident routing config and health probes, not live traffic changes) |
| `WP-consumer-<consumer>-client` | 4–5 | eligible per consumer | Client migration to the generated gRPC client, configuration, retry/deadline policy, rollout |
| `WP-integration-verification` | highest+1 | sequential | Final sequential checkpoint: builds the complete solution, runs all parity-test suites, verifies coexistence routing configuration, confirms health probes pass, and produces the integration evidence report that feeds the offline retirement-gate review |

> **Retired from the executable catalog:** `WP-cutover-<service>` and
> `WP-wcf-retirement` are no longer executable work packages. Production
> traffic cutover and WCF endpoint removal require human operational authority,
> monitoring windows, and rollback readiness verification that cannot be
> executed by an implementer agent from a work package alone. These are
> documented as non-executable offline guidance in `roadmap.retirementCriteria`
> and the `retirement` and `consumer-cutover` architecture sections.
> `WP-integration-verification` is the final executable wave; what comes after
> is outside the code-only boundary.

## Acceptance criteria

Acceptance criteria are observable outcomes, never task lists.

- Good: "Every `FaultContract` in `SPEC-order-service` returns its mapped status
  code and detail message, proven by `VAL-order-faults`."
- Bad: "Implement fault mapping."

Each `AC-*` states `evidenceRequired` (the artifact that proves it: test output,
descriptor diff, log or metric sample, review record) and links `validationIds`.
Cover at least: contract shape parity, message/field mapping including edge
cases (nulls/defaults, `decimal` precision, time zones, empty versus missing
collections, unknown enum values), fault-to-status mapping, authentication and
authorization, deadline and cancellation behavior, streaming lifecycle,
coexistence routing, rollback readiness, and observability signals.

## Validation steps

- Prefer the narrowest existing command in the repository. Inspect the solution
  or build files before writing one; never invent a project path or a tool the
  repository does not have.
- Typical `.NET` shapes — adjust to the discovered layout:
  - `build`: `dotnet build src/Orders/Orders.Grpc.csproj -c Release`
  - `test`: `dotnet test tests/Orders.Grpc.Tests/Orders.Grpc.Tests.csproj --filter Category=Contract`
  - `contract-compatibility`: the repository's descriptor or breaking-change
    check (for example a `buf breaking` invocation) when that tooling exists,
    otherwise a package that establishes it first
  - `security`: the authorization test selector
  - `operational`: the health probe command against a locally started host
- When the exact command is not knowable, use `kind: manual` and state precisely
  what is inspected and what result passes. Do not fabricate a command to
  satisfy the schema.
- `workingDirectory` is repository-relative. `status` starts at `not-run`;
  authoring never records `passed`.
- Golden-traffic or production comparison steps must state the data-handling
  constraint: no secrets, no unapproved personal data.

## Rollback and coexistence

Rollback states the strategy, the triggers that fire it, ordered recovery steps,
data impact, the owner, and the validation that proves recovery. Coexistence
states whether it is required, the routing strategy and traffic control, the
duration or exit condition, whether the legacy endpoint stays routable, and the
validation that proves both paths behave identically. Any schema or database
change made during coexistence is additive and backward compatible.

## Integration checkpoints

Every parallel wave ends with a checkpoint that reconciles generated code,
shared contracts, DI registration, and configuration, then runs the build and
the affected tests. Phases with `integrationCheckpoint: true` may not overlap
the next wave. Each package lists the checkpoints it must participate in and
what it must present there (changed files, commands run and results, new risks,
spec deviations).

## Completion report expected from implementers

Changed files, commands executed with results, acceptance evidence per `AC-*`,
assumptions, newly discovered risks or decisions, deviations from the package,
coexistence state, and rollback readiness. A completion report never authorizes
WCF retirement, never performs production traffic shifts, and never marks its
own package as approved.

The [`implement-grpc-migration`](../../implement-grpc-migration/SKILL.md)
skill executes exactly this contract per work package, including the fuller
[handoff report contract](../../implement-grpc-migration/references/handoff-report-contract.md)
and fleet wave/ownership enforcement in
[fleet-execution-and-ownership.md](../../implement-grpc-migration/references/fleet-execution-and-ownership.md).
