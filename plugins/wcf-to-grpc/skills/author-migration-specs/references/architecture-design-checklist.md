# Target Architecture Design Checklist

Normative content requirements for `targetArchitecture` in
[`migration-spec.schema.json`](../../../schemas/migration-spec.schema.json) and
for the cross-cutting redesigns that the schema's fifteen sections carry.

Mapping rules come from the `map-wcf-to-grpc` references:
[feature](../../map-wcf-to-grpc/references/feature-mapping.md),
[types](../../map-wcf-to-grpc/references/protobuf-type-mapping.md),
[security](../../map-wcf-to-grpc/references/security-mapping.md),
[errors and streaming](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md),
[hosting and rollout](../../map-wcf-to-grpc/references/hosting-and-rollout.md).
Design *decisions* come from the decision log. This checklist defines what each
section must answer before it may leave the `unresolved` state.

## How to use this checklist

- `sections` contains **exactly fifteen** entries, one per `topic` value. Never
  omit a topic; an unanswerable topic is `state: unresolved`, `design: null`,
  and at least one `QST-*`.
- Every section carries a `scope` field:
  - `scope: code` — the section describes a design choice whose outcome is
    repository code, tests, or local configuration. Unresolved `code`-scope
    sections block the consolidated review.
  - `scope: offline-handoff` — the section describes observable criteria and
    named approval gates for deployment-era operations that occur after the code
    is complete. These sections are non-executable offline guidance; they do not
    generate executable work packages and do **not** block the consolidated
    review. Their unresolved state is reported in `offlineHandoffItems`.
- A section becomes `proposed` only when every "must state" item below is
  answered from approved decisions, inventory evidence, or the mapping
  references, and every unsupported construct it touches has a specified
  gRPC-centered redesign.
- A section becomes `approved` only through an explicit human approval recorded
  in the decision log and artifact approval; authoring never self-approves.
- Each section carries the `decisionIds`, `questionIds`, `riskIds`, and
  `evidenceIds` that justify it. A design sentence with no supporting ID is a
  defect.
- **Blocking rule for `code`-scope sections:** a topic is blocking when an
  in-scope service, consumer, or work package cannot be specified without it.
  `target-runtime`, `hosting`, `service-boundaries`, `protobuf-versioning`,
  `data-types`, `errors`, `security`, and `authorization` are blocking whenever
  any service is in scope. The remainder are blocking for the surfaces they
  touch (for example `deadlines-retries` is blocking when any streaming or
  one-way operation is in scope).
- **`offline-handoff`-scope sections are never blocking for the consolidated
  review.** Their unresolved values become `offlineHandoffItems` with a gate of
  `final-local-checkpoint` or `offline-handoff`.

## Scope reference

| Topic | Scope |
|---|---|
| `target-runtime` | `code` |
| `hosting` | `code` |
| `service-boundaries` | `code` |
| `protobuf-versioning` | `code` |
| `data-types` | `code` |
| `errors` | `code` |
| `security` | `code` |
| `authorization` | `code` |
| `deadlines-retries` | `code` |
| `observability` | `code` |
| `health-checks` | `code` |
| `deployment` | `offline-handoff` |
| `coexistence` | `offline-handoff` (routing config files are `code`; traffic-shifting execution is `offline-handoff`) |
| `consumer-cutover` | `offline-handoff` |
| `retirement` | `offline-handoff` |

## 1. `target-runtime`

Must state: the .NET target framework and support horizon; the gRPC stack
(`Grpc.AspNetCore` server, `Grpc.Net.Client` clients) and generated-code
tooling; language/tooling versions for non-.NET consumers; the OS/container
baseline; and how the runtime choice was confirmed with the user rather than
inferred. Recommend the current supported .NET LTS when the repository does not
establish a target. Blocking for every migration.

## 2. `hosting`

Must state: the replacement for each WCF host (IIS/WAS, Windows Service,
self-host); Kestrel endpoint configuration including HTTP/2 (and HTTP/3 when
chosen), TLS termination, and ports; whether HTTP/1.1 endpoints coexist for
health, metrics, or transcoding; process model, startup, configuration sources,
and secret sources by reference only; the replacement for named pipes or local
transports (Unix domain sockets or loopback TLS); and any platform constraint
that forbids a mapping (for example gRPC over IIS/HTTP.sys limitations).

## 3. `service-boundaries`

Must state: how inventory `SVC-*` contracts group into gRPC services and hosts;
which contracts merge, split, or retire and why; per-service ownership; the
call-graph and shared-dependency consequences of each boundary; and the effect
on deployment units and work-package parallelism. Every in-scope `SVC-*` maps to
exactly one `SPEC-*` unless a merge/split decision says otherwise and cites it.

## 4. `protobuf-versioning`

Must state:

- **Package naming.** A stable, lowercase, dotted package such as
  `<org>.<domain>.<service>.v1`, plus `csharp_namespace` and any other
  per-language options.
- **File layout.** One repository-relative `.proto` path per service
  (`contracts[].protoFile`), the shared/common proto location, import rules, and
  which directory owns generated code and `Protobuf` build items.
- **Versioning.** How the major API version appears in the package and path;
  what counts as a breaking change; the additive-only rule during coexistence;
  the deprecation and removal process; and who owns schema evolution (a single
  integration owner, never a fleet-parallel package).
- **Numbering and reservation policy.** Field numbers are assigned once and
  never renumbered; removed fields move their number *and* name into
  `reservedNumbers`/`reservedNames`; 19000–19999 is forbidden; 1–15 is reserved
  for hot, frequently-populated fields; new fields append.
- **Compatibility verification.** The tool or command that proves compatibility
  between the previous and current descriptor set.

## 5. `data-types`

Must state the repository-wide conventions, with per-field exceptions recorded
on the contract:

- **Presence and nullability.** Proto3 implicit-presence zero values versus
  `optional` explicit presence versus wrapper types, and the rule for choosing;
  how a WCF `IsRequired`/`EmitDefaultValue` combination is honored; how a
  nullable value type round-trips.
- **`decimal`.** The chosen representation (for example a `DecimalValue`
  message with `units` and `nanos`, or a fixed-scale string/integer pair), its
  precision/rounding/overflow behavior, and the shared location of the type.
  Never map money to `double`.
- **Date and time.** `DateTime`/`DateTimeOffset` to `google.protobuf.Timestamp`
  in UTC, `TimeSpan` to `google.protobuf.Duration`, the `DateTimeKind` and
  offset-loss rules, and the date-only/time-only strategy.
- **GUID.** `string` in canonical form (or `bytes` with a stated byte order) and
  the parsing/validation rule.
- **Enumerations.** Zero-valued `*_UNSPECIFIED` member, name prefixing, closed
  versus open handling of unknown values, and how WCF `EnumMember` values and
  flag enums are represented.
- **Collections.** Arrays/lists to `repeated`, dictionaries to `map` with key
  constraints, null-versus-empty semantics, ordering guarantees, and the
  pagination policy for large result sets.
- **Polymorphism.** `KnownType`/inheritance mapped to `oneof` for closed sets or
  `google.protobuf.Any` for open sets, with the type-registry rule; state which
  types remain unsupported and require flattening.
- **Payload limits.** Maximum message sizes, the streaming/chunking threshold,
  compression, and the `byte[]`/`Stream` mapping.
- **Serialization risks.** XML namespaces, element ordering, `IExtensibleDataObject`,
  surrogates, and other constructs with no Protobuf equivalent become risks.

## 6. `errors`

Must state: the mapping from each WCF fault contract and unhandled exception to
a gRPC status code; the rich error detail model (for example
`google.rpc.Status` with typed detail messages, or a service-owned detail
message) and its proto location; the trailer/metadata keys used; the
server-interceptor replacement for `IErrorHandler`; the rule that internal
exception text, stack traces, and secrets are never returned; correlation-ID
propagation; and the client-side contract for distinguishing retryable from
terminal failures. Every `FaultContract` in the inventory must appear in a
contract-level mapping table.

## 7. `security`

Must state: TLS configuration and certificate sourcing/rotation by reference;
whether mTLS is required and how client certificates are validated; the
replacement for Windows/Negotiate, message-level, and WS-\* security (typically
OIDC/JWT bearer tokens or certificate authentication) with the identity provider
and token lifetime; transport credential propagation for service-to-service
calls; how proxies terminating TLS preserve identity; and the explicit risk
entry for every WCF security mode with no direct gRPC equivalent.

## 8. `authorization`

Must state: the modern .NET authorization policies replacing
`PrincipalPermission`, role checks, and custom authorization managers; the
default policy (deny by default) and per-RPC overrides; claim/role mapping from
the new identity provider; how per-message or data-scoped authorization is
enforced; and how authorization is proved by tests. Each `RPC-*` carries an
`authorizationPolicy`; "inherits the service default" is an acceptable value
only when the default is defined here.

## 9. `deadlines-retries`

Must state: the deadline policy per operation class and how WCF
send/receive/open/close timeouts and `OperationTimeout` translate into client
deadlines and server cancellation; how `CancellationToken` flows into
application code; the idempotency classification of every RPC and the
idempotency-key mechanism when needed; the retry/hedging policy including
retryable status codes, backoff, attempt limits, and why non-idempotent RPCs are
excluded; the replacement for one-way operations (unary acknowledgement or
queue-backed accept) with the delivery-guarantee change made explicit; and
client channel/connection reuse, keep-alive, and load-balancing settings.

## 10. `observability`

Must state: structured logging with correlation/trace identifiers; OpenTelemetry
tracing and metrics for server and client, including the exporter and the
replacement for WCF message inspectors and diagnostic tracing; the RPC metrics
required for parity comparison (rate, error, duration, payload size); log
redaction rules; and the dashboards/alerts required before cutover.

## 11. `health-checks`

Must state: the gRPC health-checking service (`grpc.health.v1.Health`) exposure
and per-service statuses; liveness versus readiness semantics; dependency probes
(database, identity provider, downstream services); the probe configuration used
by the load balancer or orchestrator; and how draining/shutdown is signalled so
in-flight and streaming calls end cleanly.

## 12. `deployment`

Must state: the deployment unit and pipeline mechanism (container image, installer, k8s manifest — the code-observable choice); environment/configuration management approach; TLS material provisioning by reference (never values); service discovery and load balancing (client-side, proxy, or mesh) with HTTP/2 connection-affinity implications; scaling and resource baselines; rollout mechanics (blue/green, canary, ring) and the rollback action; database or shared-state migration ordering; and the network/firewall changes the new endpoints require.

> **Environment-specific values are deferred-operational offline guidance.**
> Specific production hostnames, environment-progression schedules, cloud
> regions, and deployment-approval chains are not blocking for a complete
> specification draft. Record them as named offline prerequisites with a
> concrete next action, not as unresolved architecture facts. The architecture
> section must answer the code-observable mechanism; it does not specify
> environment-specific deployment values.

## 13. `coexistence`

Must state: whether WCF and gRPC run simultaneously and for how long; the
topology (side-by-side endpoints, reverse proxy, SOAP adapter, or gRPC JSON
transcoding) with the routing rule for each consumer class; the shared-state and
data-consistency rule while both stacks are live; the additive-only schema
constraint during the window; the exit condition and the owner who declares it;
and the risk that any adapter becomes permanent. A coexistence component is a
temporary supporting element, never the migration target.

> The coexistence routing configuration is code and may appear in an executable
> `WP-coexistence-routing` package that writes repository-resident config files.
> The traffic-shifting execution (moving live production traffic from WCF to
> gRPC) is an offline operational action and must not appear as an executable
> work package.

## 14. `consumer-cutover`

Must state: every consumer (`CON-*`) with its language, ownership, upgrade
control, and target client (generated .NET client, gRPC-Web, transcoding, or
adapter); the ordered cutover sequence and per-consumer gate; how external or
unreachable consumers are handled; the traffic-shifting mechanism and rollback
trigger; the communication/versioning expectations for external teams; and how
consumer readiness is verified before the legacy endpoint is withdrawn.

## 15. `retirement`

Must state the WCF retirement gates as observable criteria: every in-scope
service migrated and validated; contract, behavior, fault, security,
serialization, streaming, and performance parity evidence produced by the
validation stage; zero traffic on legacy endpoints for a defined observation
window with the measurement source; every consumer cut over or explicitly waived
by an approved decision; rollback rehearsed and its window expired; operational
readiness (alerts, dashboards, runbooks, on-call) accepted; coexistence
components removed or given a dated removal plan; and explicit human approval of
the retirement decision. Retirement is never approved by the architect and never
by static analysis.

> **Non-executable offline guidance.** This section defines observable
> retirement *criteria* only. It does not generate executable `WP-*` packages,
> does not authorize WCF endpoint removal, and does not constitute a production
> retirement decision. The criteria become `roadmap.retirementCriteria` entries
> in the migration specification and are presented to the human retirement
> authority as a checklist. Actual retirement execution is an out-of-scope
> authority action that must occur outside this workflow.

## Cross-cutting redesigns carried by the sections

Constructs with no direct gRPC equivalent still need a specified design. Record
each on the section named below, plus its `RSK-*` and the `DEC-*` that
authorized the redesign.

| Legacy construct | Section that carries the design | Required content |
|---|---|---|
| Duplex callbacks (`CallbackContract`) | `service-boundaries` (contract shape) and `deadlines-retries` (lifetime) | Bidirectional or server-streaming replacement, stream lifetime and ownership, reconnect/resume semantics, message ordering, backpressure, and the loss of independent server-initiated dial-back |
| Sessions and `InstanceContextMode.PerSession` | `service-boundaries` | Stateless services plus an explicit state store (distributed cache/database), state key derivation, TTL/eviction, concurrency control, affinity removal, and the behavior change when a stream or connection drops |
| `InstanceContextMode.Single` / `ConcurrencyMode` | `service-boundaries` | DI lifetime mapping, thread-safety requirements, shared-state protection, and throttling replacement (concurrency limits, rate limiting, channel/queue depth) |
| Distributed transactions, `TransactionFlow`, MSDTC | `errors` (failure surface) and `deployment` (data ordering) | Saga/compensation or outbox design, idempotency keys, retry-safe boundaries, consistency window, reconciliation and alerting, and the explicit statement that atomic two-phase commit is not available |
| Reliable sessions, ordered delivery, MSMQ | `deadlines-retries` | At-least-once versus at-most-once behavior, deduplication, ordering guarantees, queue-backed acceptance when required, and the delivery-guarantee difference |
| One-way operations | `deadlines-retries` | Unary acknowledgement or queued accept, and the change from fire-and-forget to acknowledged delivery |
| Streaming (`OperationContract` streamed transfer) | `data-types` and `service-boundaries` | Chunk message shape and size, first-message metadata, checksum/completion signalling, and cancellation |
| Message contracts, headers, and inspectors | `data-types` and `observability` | Header-to-metadata mapping, interceptor replacements, and any header that must become a request field |

## Topology

`topologyNodes` and `topologyEdges` must describe the end state *and* the
coexistence window: gRPC services, retained WCF services, consumers, proxies,
identity providers, data stores, brokers, and observability sinks. Every edge
states its protocol, purpose, and whether it exists only during coexistence
(`coexistenceOnly: true`). Every node references the inventory IDs it
represents so the topology stays traceable.
