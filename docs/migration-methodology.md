# Migration methodology

The playbook for running a WCF-to-gRPC migration with this plugin: what happens
at each stage, what you must decide, what you must approve, and what the plugin
refuses to do for you.

**Scope of the orchestrated workflow:** stages 1–9 (through integration
checkpoints, solution build, repository-local tests, and the structured code
handoff). Deployment, environment provisioning,
production/protected traffic, runtime parity validation, cutover, live rollback,
and WCF retirement are out-of-scope offline activities. Guidance for those
activities is in §9–11 of this document for reference; the orchestrator does
not invoke them.

**Repository layout:** Stage 0 records an operator choice: augment the existing
solution, or create an isolated solution that references WCF read-only, copies
an immutable WCF test fixture, or contains only gRPC projects. WCF is never
modified in any mode.

For how the plugin is built see [architecture.md](architecture.md); for the
files it produces see [output-contracts.md](output-contracts.md).

## 1. Before you start

| Question | Why it matters |
|---|---|
| What is in scope? | One service, one solution, or a bounded slice. Everything downstream is scoped by this answer. |
| Does this repository host WCF services, only consume them, or both? | A client-only repository is fully supported but produces no server work packages. |
| Which .NET version will host the gRPC services? | The plugin proposes the current supported .NET LTS and highlights constraints; override it in consolidated review. |
| Should gRPC augment the existing solution or use an isolated solution? | This controls every writable path, build command, project reference, and local coexistence-test strategy. It is a future-state choice and cannot be inferred safely from the repository. |
| Who approves architecture and publication? | Architecture decisions/spec/work packages share one scoped review; publication is a distinct act. |
| What may the agents do? Network, GitHub mutation? | All default to off. Nothing is granted implicitly. |

The **target is always gRPC for .NET**. This is a fixed product
decision, not a recommendation the plugin will renegotiate. A WCF construct
that gRPC cannot express directly becomes an explicit redesign risk and a
recorded decision — never a quiet retarget to REST, CoreWCF, or a message
broker.

## 2. Stage 1 — Read-only inventory

**Agent:** WCF Codebase Analyst · **Skill:** `inventory-wcf-codebase` ·
**Output:** `inventory.json`

The analyst discovers solutions, projects, target frameworks, and packages;
traces service, operation, data, message, fault, and callback contracts to
their implementations and call sites; reads `app.config`/`web.config`, config
transforms, and code-based configuration; and enumerates hosts, endpoints,
bindings, behaviors, quotas, timeouts, security, identity, serialization,
`KnownType` hierarchies, sessions, instance and concurrency modes,
transactions, reliable sessions, one-way/duplex/streaming operations,
inspectors and interceptors, generated proxies, `ChannelFactory` usage,
consumers, external dependencies, deployment, and tests.

Three rules make the inventory trustworthy:

- **Read-only.** It never edits, builds, restores, or formats the repository.
- **Attribute search is not completeness.** Finding `[ServiceContract]` yields
  a *candidate*; the candidate is only `complete` once traced to its
  implementation, its configuration, and its call sites.
- **Facts, conclusions, and unknowns are separated.** Unknowns become `QST-*`
  questions with a stated reason, never a guess, an empty string, or a zero.

**What you do:** confirm the scope looks right, and look at the `risks` list —
it is your first honest view of how hard this migration will be.

## 3. Stage 2 — Decision proposals and focused blockers

**Agent:** WCF Migration Decision Interviewer · **Skill:**
`interview-migration-decisions` · **Output:** `decision-log.json`

The agent evaluates the complete decision catalog in one pass. High-confidence,
reversible, behavior-preserving recommendations become proposed assumptions.
They are not approvals. The agent interrupts only when no safe default exists;
each such focused question states its evidence and blocked design surface.

Typical code topics are target runtime, service boundaries, transport security
abstractions, authentication/authorization, error mapping, deadlines, retries,
idempotency, state/transaction redesign, streaming, and observability.
Environment hosting values, coexistence routing, consumer cutover, and live
rollback are recorded as `out-of-scope-handoff` guidance rather than
interactive code-generation blockers.

**What you do:** answer an irreducible blocker when one exists; otherwise review
all proposals later in one bundle. Operational numbers and platform details may
be deferred to a concrete implementation, validation, or cutover gate.

## 4. Stage 3 — Mapping

**Agent:** WCF-to-gRPC Mapper · **Skill:** `map-wcf-to-grpc` · **Output:**
`mapping-result.json`

Every discovered construct receives a feature mapping, a type mapping, a
security mapping, and an error/streaming mapping. Constructs with no safe
direct gRPC equivalent are flagged `UNSUPPORTED` with a risk level and routed
to an explicit decision.

### Mechanical or low-risk

| WCF | gRPC for .NET |
|---|---|
| `[ServiceContract]` | Protobuf `service` (no interface inheritance; flatten) |
| `[OperationContract]` request/response | Unary `rpc` (one request message, one response message) |
| `[DataContract]`/`[DataMember]` | Protobuf `message` with stable field numbers |
| `BasicHttpBinding`, `NetTcpBinding` | gRPC over HTTPS on Kestrel |
| `NetNamedPipeBinding` | gRPC over a named pipe or Unix domain socket |
| `SendTimeout` | `CallOptions.Deadline` (absolute; gRPC has **no** default deadline) |
| `MaxReceivedMessageSize` | `GrpcServiceOptions.MaxReceiveMessageSize`/`MaxSendMessageSize` |
| Message inspectors, `IErrorHandler` | Server and client interceptors |

### Semantic differences that need review

| WCF | Why it is not mechanical |
|---|---|
| `[MessageContract]` | SOAP envelope shape is lost; literal-envelope consumers break |
| Nullable and default values | proto3 zero-value/presence semantics differ from `DataContract` |
| `decimal`, `DateTime`, `Guid`, enums, `KnownType` polymorphism | No native Protobuf equivalents; each needs an explicit, recorded representation |
| `IsOneWay = true` | Becomes a unary call with an empty response, or client streaming |
| `WSHttpBinding` | Bundled transport/encoding/security must be decomposed into explicit settings |
| `WebHttpBinding` (REST) | gRPC JSON transcoding, or a separately owned concern |

### Unsupported / high-risk — redesign plus a recorded decision

| WCF feature | Required gRPC-centered redesign |
|---|---|
| Duplex callbacks (`CallbackContract`, `WSDualHttpBinding`) | Bidirectional streaming |
| `InstanceContextMode.PerSession`, session state | Externalized state; gRPC has no session concept |
| `ConcurrencyMode.Reentrant` | Async/await; no reentrancy model |
| Reliable sessions (WS-ReliableMessaging) | Application-level idempotency, retries, acknowledgement |
| Distributed transactions (WS-AtomicTransaction, `TransactionFlow`) | Saga/outbox patterns with compensations |
| `NetMsmqBinding` / MSMQ | An explicitly decided external broker fronted by a gRPC surface |
| `SecurityMode.Message`, WS-Security, WS-SecureConversation, WS-Trust | TLS/mTLS plus token-based authentication |
| Windows authentication (NTLM/Kerberos), CardSpace | Modern token or certificate credentials |
| WS-Management | Cloud-native orchestration and observability |

Full detail and citations:
[`feature-mapping.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/feature-mapping.md),
[`protobuf-type-mapping.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/protobuf-type-mapping.md),
[`security-mapping.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/security-mapping.md),
[`error-and-streaming-mapping.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/error-and-streaming-mapping.md),
[`hosting-and-rollout.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/hosting-and-rollout.md).

## 5. Stage 4 — Architecture and specification

**Agent:** gRPC Migration Architect · **Skill:** `author-migration-specs` ·
**Output:** `migration-spec.json` plus rendered Markdown

The architect produces fifteen architecture sections, per-service Protobuf
contract specifications, a dependency-ordered roadmap with integration
checkpoints, and independently implementable work packages with acceptance
criteria, validation steps, non-goals, rollback, and coexistence plans.

Before review it also proves implementation readiness: exact SDK, package,
test-adapter, and code-generation versions; compatibility-baseline format;
restore/feed boundaries; and exact validation commands. It computes waves from
dependencies and checkpoint barriers and rejects any writable path that
intersects the inventory's immutable WCF content manifest.

It applies proposed decisions as labeled assumptions and **blocks rather than
guesses**. An unresolved immediate decision leaves that
architecture section `unresolved` with a `null` design and an open `QST-*`,
leaves the affected contract or work package unapproved, and is reported. There
are no plausible-looking placeholder designs.

It also emits `migration-review.json` and `migration-review.md`, binding every
proposal, architecture section, contract, roadmap item, and work package to one
semantic digest.

## 6. Stage 5 — Consolidated review

Approval is one atomic human act over the exact review-bundle digest. The
interviewer records its listed decisions and the architect records the
specification, binds all scoped IDs, and promotes all listed work packages.
The shared semantic digest excludes these lifecycle transitions. **Nothing is
implemented and no issue is published before both records are complete.**

Review at minimum: recommendations, assumptions, confidence and alternatives;
scope; each architecture section and its state; per-service
contracts including field numbering and reservations; roadmap phases and
integration checkpoints; work packages with fleet suitability and file
ownership; open risks and deferred items. This approval explicitly excludes
GitHub mutation, production/protected traffic, cutover, rollback execution,
and retirement.

## 7. Stage 6 — Optional GitHub Issue publication

**Agent:** gRPC Migration Issue Publisher · **Skill:**
`publish-migration-issues` · **Output:** `issue-set.json`, previews

Publication is optional. When you use it, the safeguards are absolute:

1. Default mode is `dry-run`; `export-only` writes artifacts without mutation.
2. The **complete** set is previewed with a digest — never a sample.
3. Mutation requires `publish-approved` plus a confirmation whose
   `previewDigest` matches the current preview and whose `allowLabelCreation`,
   `allowIssueCreation`, and `allowDependencyPatch` flags are explicitly
   present. A missing flag blocks that mutation; it never defaults to true.
4. A preview that changed after confirmation makes the confirmation stale:
   re-preview, re-confirm.
5. Duplicates are detected by stable `ISSUE-*`/`WP-*` identity, so a re-run
   never double-posts.
6. Labels are created only after confirmation; issues are created in
   dependency-safe order; dependency links are patched only once issue numbers
   exist; partial successes persist so a re-run resumes.
7. No credential is ever collected or stored. Publication uses authentication
   already present in your environment.

## 8. Stage 7 — Implementation in waves

**Agent:** gRPC Migration Implementer · **Skill:** `implement-grpc-migration` ·
**Output:** code plus append-only
`implementation-reports/<work-package-id>/attempt-<attempt-id>.md`

One work package at a time. Before touching a file, the implementer confirms
the package is approved, its `hard` dependencies are satisfied, its wave is
open, the previous integration checkpoint reconciled, and its file ownership is
uncontested — then records a claim marker. A capability handshake first proves
that the delegated subprocess can edit files, execute commands, use the exact
.NET SDK, and access required package feeds. An unchanged incapable backend is
not retried.

The implementation follows the selected layout exactly. For isolation with
local legacy reuse, referencing original WCF projects read-only is preferred.
A copied WCF tree is permitted only as a complete, hash-verified, immutable,
test-only fixture; it is not deployable. A gRPC-only solution neither
references nor copies WCF.

The implementer compares inventory-time and post-run hashes for WCF-protected
and package-owned paths, and reports reviewed direct package versions beside
effective resolved versions. Unexplained transitive drift is blocking.

Waves are dispatched with Copilot CLI `/fleet` and observed with `/tasks`, by a
human. Parallel batches contain only packages with pairwise-disjoint
`exclusive-write` ownership. Shared and schema infrastructure — proto
conventions and shared protos, generated-code build configuration,
solution/project/package-management files, host bootstrap and DI composition,
the interceptor chain, auth configuration, shared-state migrations, solution
files, and code-generation configuration — is always sequential and
single-owner. Gateway/proxy and coexistence routing are offline work.

The implementer stops and reports rather than improvising when the spec
contradicts the real code, a policy is unspecified, or a design choice is
genuinely open. It never marks its own validation passed, never edits migration
artifacts, and never modifies WCF.

### Client-only repositories

A repository that consumes WCF through generated proxies or `ChannelFactory`
and owns no service implementation is a first-class case. It still gets a full
inventory (proxies, channel usage, endpoint configuration, consumers), a
decision log, contract alignment against the service owner's Protobuf
specification, client work packages, and coexistence planning. It produces no
server work packages.

## 9. Stage 8 — Final local integration checkpoint

A roadmap phase marked `integrationCheckpoint: true` holds the next wave until
`implementation-reports/checkpoint-<phase-id>.md` records the checkpoint
reconciled: the affected solution rebuilt, generated code regenerated and
diffed, shared contract and DI registration consistency verified, and the
affected tests run. A missing, stale, or unresolved checkpoint report blocks the
next wave.

### Stage 9 — Code handoff

When all waves are complete and the final integration checkpoint
are reconciled, the orchestrator invokes the **gRPC Code Handoff Author**
(skill: `finalize-code-handoff`). It reads the approved specification, every
implementation report, and the final checkpoint, verifies from those reports
that the affected solution built cleanly and repository-local tests passed,
then writes
`code-handoff.json` and `code-handoff.md`. This is the end of the orchestrated
workflow.

`code-handoff.json` records: deliverables, local validation evidence, code
gaps, code-rollback steps, and twelve categories of offline obligation — each
marked `not-executed` with an owner role and next action. `wcfState` is always
`"active-and-unchanged"`. Six explicit limitations are embedded: `not-deployed`,
`runtime-parity-not-established`, `production-readiness-not-established`,
`cutover-not-authorized`, `live-rollback-not-executed`, and
`wcf-retirement-not-authorized`.

## 10. After the plugin finishes — optional parity validation (offline)

**Agent:** gRPC Parity Validator · **Skill:** `validate-grpc-parity` ·
**Output:** `validation-reports/`

The parity validator is an independent read-only tool you invoke manually after
you deploy to a test environment. It is not an orchestrated stage. The
orchestrator does not invoke it and does not gate handoff on its results.

When you are ready, select the **gRPC Parity Validator** agent and grant the
permissions your test environment requires (network access, test harness).

Thirteen gates: contract and Protobuf compatibility with reserved fields; build
and tests; success-path behavior; typed faults and status/error details;
serialization edge cases; authentication/authorization/TLS/mTLS; deadlines,
cancellation, retries, idempotency; streaming; session-state, concurrency,
transaction, and reliable-delivery redesigns; payload and message limits with
performance SLA evidence; health, telemetry, deployment, and service discovery;
client migration, coexistence, and rollback; and WCF retirement criteria.

Non-negotiables:

- **Parity is proven, never inferred.** A green build, a passing unit test, a
  matching signature, or an implementer's claim is not behavioral evidence.
- **A comparison needs both sides.** No legacy baseline means no verdict.
- **Run status is computed mechanically** — `fail`, then `blocked`, then
  `conditional-pass`, then `pass` — never rounded up.
- The validator is read-only on the product and **never fixes what it finds**.

## 11. WCF retirement gate (offline)

Retiring WCF is an offline activity owned by your team. When parity validation
produces a `retirement-ready` outcome, it is a readiness statement — not an
authorization. A human must separately record a retirement approval in the
decision log. The plugin does not orchestrate retirement.

Prerequisites the plugin can help you document:

- a current `VRPT-*` report whose retirement outcome is `retirement-ready` for
  the retirement scope, produced against the deployed revision;
- every roadmap `retirementCriteria` entry met with cited evidence;
- gates 1–12 `pass` or justified `not-applicable`, with zero open blocking findings;
- every consumer in a terminal state, with zero unknown callers;
- WCF endpoint traffic at or below the agreed quiesce threshold for the agreed
  duration, measured;
- operational readiness proven in a production-equivalent environment;
- rollback rehearsed and observed to work, with date, operator, environment, and result;
- a recorded human retirement approval referencing the `VRPT-*` id.

`retirement-ready` is a readiness statement, not an authorization. There is no
such thing as "ready with a caveat" — a caveat means not ready, with a named
condition.

## 12. Working rhythm

| Situation | Do this |
|---|---|
| A stage reports `blocked` | Read the named blocking item; it states the owner and the smallest next action |
| A decision was wrong | Record a superseding decision; re-run the architect incrementally. Never hand-edit an artifact |
| The code contradicts the spec | The implementer reports a `spec-deviation`; route it back to the architect |
| The migration is paused | Everything needed to resume is on disk; the orchestrator re-derives the next action from artifact state |
| You are told to skip a gate | The plugin refuses, names the gate, and states what would satisfy it |

## 13. Sources

Guidance in this plugin is derived from the sources indexed in
[`sources.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/sources.md),
principally Microsoft's *gRPC for WCF Developers*
([local copy](../assets/gRPC-for-WCF-Developers.pdf),
[online edition](https://learn.microsoft.com/en-us/dotnet/architecture/grpc-for-wcf-developers/)),
the [gRPC for .NET documentation](https://learn.microsoft.com/en-us/aspnet/core/grpc/),
the [Protocol Buffers proto3 language guide](https://protobuf.dev/programming-guides/proto3/),
and the [gRPC status code definitions](https://grpc.io/docs/guides/status-codes/).
Support windows change with every .NET release: re-check the
[.NET support policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core)
before relying on an LTS recommendation.
