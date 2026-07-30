# Migration methodology

The playbook for running a WCF-to-gRPC migration with this plugin: what happens
at each stage, what you must decide, what you must approve, and what the plugin
refuses to do for you.

For how the plugin is built see [architecture.md](architecture.md); for the
files it produces see [output-contracts.md](output-contracts.md).

## 1. Before you start

| Question | Why it matters |
|---|---|
| What is in scope? | One service, one solution, or a bounded slice. Everything downstream is scoped by this answer. |
| Does this repository host WCF services, only consume them, or both? | A client-only repository is fully supported but produces no server work packages and cannot own the retirement gate (§8). |
| Which .NET version will host the gRPC services? | Asked once per migration. The plugin recommends the current supported .NET LTS after checking the support policy; it never assumes a version. |
| Who approves the specification, the issue preview, and the retirement? | Each is a distinct human act; the plugin will stop and ask by name. |
| What may the agents do? Network, GitHub mutation, test harness, golden traffic, load test, production access? | All default to off. Nothing is granted implicitly. |

The **target is always gRPC on ASP.NET Core**. This is a fixed product
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

## 3. Stage 2 — Decision interview

**Skill:** `interview-migration-decisions` · **Output:** `decision-log.json`

Only questions the repository cannot answer are asked. Each question states the
evidence that triggered it, the consequence of each option, and a recommended
gRPC-centered option where one is justified. Answers persist incrementally, so
an interrupted interview resumes without re-asking what you already answered.

Typical topics: target runtime; service boundaries; transport security and
authentication model; authorization model; error model and status mapping;
deadlines, retries, and idempotency; session-state redesign; transaction
redesign; streaming shape; observability; hosting platform; coexistence and
consumer cutover; rollback; golden-traffic permission; retirement criteria.

**What you do:** answer, or explicitly defer with an owner. A deferral without
an owner is a blocker, not a deferral. Approving a decision is a human act and
is recorded with who approved it — the plugin never infers an approver.

## 4. Stage 3 — Mapping

**Skill:** `map-wcf-to-grpc` · **Output:** mapping result and redesign risks

Every discovered construct receives a feature mapping, a type mapping, a
security mapping, and an error/streaming mapping. Constructs with no safe
direct gRPC equivalent are flagged `UNSUPPORTED` with a risk level and routed
to an explicit decision.

### Mechanical or low-risk

| WCF | gRPC on ASP.NET Core |
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

It **blocks rather than guesses**. An unresolved blocking decision leaves that
architecture section `unresolved` with a `null` design and an open `QST-*`,
leaves the affected contract or work package unapproved, and is reported. There
are no plausible-looking placeholder designs.

**What you do:** clear blocking items by answering the named question or
re-running the analysis, then re-run the architect in incremental mode. Stable
identifiers, Protobuf field numbers, reservations, and approvals survive
re-runs.

## 6. Stage 5 — Approval gate

Approval is a human act, recorded in the decision log and in the artifact's
`approval` object. **Nothing is implemented and no issue is published before
it.** If you ask an agent to "just start", it will refuse and tell you which
artifact is unapproved.

Review at minimum: scope; each architecture section and its state; per-service
contracts including field numbering and reservations; roadmap phases and
integration checkpoints; work packages with fleet suitability and file
ownership; retirement criteria; open risks and deferred items.

## 7. Stage 6 — Optional GitHub Issue publication

**Skill:** `publish-migration-issues` · **Output:** `issue-set.json`, previews

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
**Output:** code plus `implementation-reports/<work-package-id>.md`

One work package at a time. Before touching a file, the implementer confirms
the package is approved, its `hard` dependencies are satisfied, its wave is
open, the previous integration checkpoint reconciled, and its file ownership is
uncontested — then records a claim marker.

Waves are dispatched with Copilot CLI `/fleet` and observed with `/tasks`, by a
human. Parallel batches contain only packages with pairwise-disjoint
`exclusive-write` ownership. Shared and schema infrastructure — proto
conventions and shared protos, generated-code build configuration,
solution/project/package-management files, host bootstrap and DI composition,
the interceptor chain, auth configuration, shared-state migrations,
gateway/proxy routing, coexistence routing, cutover, and retirement — is always
sequential and single-owner.

The implementer stops and reports rather than improvising when the spec
contradicts the real code, a policy is unspecified, or a design choice is
genuinely open. It never marks its own validation passed, never edits migration
artifacts, and never retires WCF.

**Coexistence is a real capability, not a paragraph.** The legacy WCF endpoint
keeps serving throughout; every schema, database, and proto change made during
coexistence is additive and backward compatible; each package's rollback steps
are implemented so they can actually be exercised.

### Client-only repositories

A repository that consumes WCF through generated proxies or `ChannelFactory`
and owns no service implementation is a first-class case. It still gets a full
inventory (proxies, channel usage, endpoint configuration, consumers), a
decision log, contract alignment against the service owner's Protobuf
specification, client work packages, coexistence and cutover planning, and
client-cutover validation. It produces no server work packages, and it cannot
own the retirement gate — the service owner does.

## 9. Stage 8 — Integration checkpoints

A roadmap phase marked `integrationCheckpoint: true` holds the next wave until
`implementation-reports/checkpoint-<phase-id>.md` records the checkpoint
reconciled: the affected solution rebuilt, generated code regenerated and
diffed, shared contract and DI registration consistency verified, and the
affected tests run. A missing, stale, or unresolved checkpoint report blocks the
next wave.

## 10. Stage 9 — Independent parity validation

**Agent:** gRPC Parity Validator · **Skill:** `validate-grpc-parity` ·
**Output:** `validation-reports/`

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
- **A comparison needs both sides.** No legacy baseline means no verdict; the
  gRPC implementation is never its own baseline.
- **Run status is computed mechanically** — `fail`, then `blocked`, then
  `conditional-pass`, then `pass` — never rounded up.
- **Golden production traffic requires recorded permission** plus masking,
  retention, and deletion controls. Default to synthetic or masked data. Never
  replay mutating traffic against production.
- The validator is read-only on the product and **never fixes what it finds**.

## 11. Stage 10 — WCF retirement gate

Retiring WCF requires all of the following, each verified by reading an
artifact:

- a current `VRPT-*` report whose retirement outcome is `retirement-ready` for
  the retirement scope, produced against the deployed revision;
- every roadmap `retirementCriteria` entry met with cited evidence;
- gates 1–12 `pass` or justified `not-applicable` across the whole retirement
  scope, with zero open blocking findings;
- every consumer in a terminal state, with **zero unknown callers** — "we
  believe nobody uses it" is not evidence, and absent monitoring is a blocking
  gap;
- WCF endpoint traffic at or below the agreed quiesce threshold for the agreed
  duration, measured;
- operational readiness proven in a production-equivalent environment, with
  capacity evidence for 100% of traffic;
- rollback **rehearsed** and observed to work, with date, operator,
  environment, and result;
- a recorded **human retirement approval**, distinct from architecture and
  work-package approval, referencing that `VRPT-*` id.

`retirement-ready` is a readiness statement, not an authorization. There is no
such thing as "ready with a caveat" — a caveat means not ready, with a named
condition.

## 12. Working rhythm

| Situation | Do this |
|---|---|
| A stage reports `blocked` | Read the named blocking item; it states the owner and the smallest next action |
| A decision was wrong | Record a superseding decision; re-run the architect incrementally. Never hand-edit an artifact |
| The code contradicts the spec | The implementer reports a `spec-deviation`; route it back to the architect |
| Validation fails | Route each finding by its owner; re-validate the **same** scope, never a narrower one |
| The migration is paused | Everything needed to resume is on disk; the orchestrator re-derives the next action from artifact state |
| You are told to skip a gate | The plugin refuses, names the gate, and states what would satisfy it |

## 13. Sources

Guidance in this plugin is derived from the sources indexed in
[`sources.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/sources.md),
principally Microsoft's *gRPC for WCF Developers*
([local copy](../assets/gRPC-for-WCF-Developers.pdf),
[online edition](https://learn.microsoft.com/en-us/dotnet/architecture/grpc-for-wcf-developers/)),
the [ASP.NET Core gRPC documentation](https://learn.microsoft.com/en-us/aspnet/core/grpc/),
the [Protocol Buffers proto3 language guide](https://protobuf.dev/programming-guides/proto3/),
and the [gRPC status code definitions](https://grpc.io/docs/guides/status-codes/).
Support windows change with every .NET release: re-check the
[.NET support policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core)
before relying on an LTS recommendation.
