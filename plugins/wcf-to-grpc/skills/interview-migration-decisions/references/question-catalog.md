# Migration Decision Question Catalog

This catalog is used by
[`interview-migration-decisions`](../SKILL.md). It is not a questionnaire to
ask verbatim. Generate a question only when inventory evidence triggers it,
code/configuration cannot settle the future-state choice, and no approved,
non-stale decision already resolves it.

The mandatory destination is gRPC for .NET. Supporting components are
permitted only when explicitly approved as part of a gRPC-centered design.
Do not offer REST, CoreWCF, SOAP, queues, or another protocol as the permanent
replacement target.

## Catalog field meanings

- **Trigger:** inventory/risk/evidence conditions that make the choice real.
- **Ask:** one focused question. Split service-specific choices when answers
  may differ.
- **Why:** consequence to include in the prompt.
- **Recommendation:** default only when evidence justifies it.
- **Skip:** evidence or parent decisions that make the question unnecessary.
- **Category:** value from `decision-log.schema.json`.
- **Gate:** whether unresolved state blocks specification or only later
  cutover/implementation.

## Interaction classes

The catalog is a design checklist, not an instruction to interrupt the user
for every row. Classify each triggered topic before choosing an interaction:

| Class | Default topics |
|---|---|
| `agent-proposed` | `target-runtime`, `service-process-layout`, `service-boundaries`, `coexistence-strategy`, `coexistence-duration`, `package-versioning`, `compatibility-policy`, `guid-format`, `fault-status-map`, `error-disclosure`, `stream-backpressure`, `deadline-policy`, `retry-policy`, `cancellation-semantics`, `baseline-source`, `telemetry-standard`, `parity-oracle`, `fleet-parallelism`, `pilot-selection` |
| `review-required` | `hosting-model`, `operating-system`, `browser-or-http-clients`, `service-authentication`, `transport-security`, `authorization-policy`, `proto-ownership`, `polymorphism-policy`, `decimal-representation`, `presence-semantics`, `timestamp-semantics`, `duration-semantics`, `xml-payload`, `partial-failure`, `session-state`, `duplex-lifecycle`, `duplex-reconnect-delivery`, `large-payload-streaming`, `one-way-acknowledgement`, `one-way-failure`, `idempotency-policy`, `deployment-mechanism`, `service-discovery-mechanism`, `gateway-proxy-mechanism`, `payload-logging`, `rollback-data`, `repository-strategy` |
| `immediate-answer-required` | `solution-layout`, `migration-scope`, `operation-scope`, `external-consumer-support`, `identity-provider`, `message-security-replacement`, `state-lifetime`, `transaction-redesign`, `consistency-requirement`, `reliable-delivery`, `queue-redesign`, `ordering-scope`, `named-pipe-transport`, `audit-requirements`, `compliance-constraints`, `delivery-constraints` |
| `deferred-operational` | `consumer-upgrade-ownership`, `secret-certificate-ownership`, `shared-contract-distribution`, `sla-objectives`, `payload-limits`, `capacity-scaling`, `certificate-operations`, `configuration-ownership`, `test-environments`, `compatibility-matrix`, `shared-foundation-owner`, `cutover-unit`, `cutover-gates`, `rollback-trigger`, `deployment-environment-progression` |
| `out-of-scope-handoff` | `golden-traffic`, `retirement-approval` |

These are defaults, not blind outcomes. Promote an `agent-proposed` or
`review-required` topic to `immediate-answer-required` when evidence conflicts,
confidence is below high, a wire-significant choice has no behavior-preserving
option, or a supporting component introduces material security, consistency,
cost, or operational risk. Demote an immediate topic to `review-required` only
when high-confidence evidence supports a reversible, behavior-preserving
recommendation and every assumption is explicit.

An agent may select a recommendation as `proposed` only when it:

1. preserves observed behavior and the mandatory gRPC target;
2. is supported by high-confidence evidence or a cited applicable policy;
3. is reversible before cutover without destructive data conversion;
4. does not invent provider capability, organizational commitment, numeric
   production objectives, or permission;
5. records assumptions, alternatives, consequences, confidence, and the later
   gate that will test or approve it.

`deferred-operational` values become owned implementation, validation, or
cutover prerequisites. They do not block a complete draft merely because a
specific product, number, environment, or individual is not yet known.
`out-of-scope-handoff` topics (`golden-traffic`, `retirement-approval`) are
**never entered into the decision log, never assigned a decision state, never
cleared by architecture approval, and never included in the consolidated review
approval scope**. They are handled exclusively through their own authority
processes. Note them in the outbound `outOfScopeHandoff` list only.

## 1. Target runtime and hosting platform

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `target-runtime` | Always, once per migration; cite current project/OS/deployment constraints. | Which supported .NET runtime will host the new gRPC services? | Runtime controls gRPC for .NET support and support lifetime. Recommend the current .NET LTS after checking the support policy; as of 2026-07-30, recommend .NET 10 LTS. | `target-runtime`; specification blocker. Never skip. |
| `solution-layout` | Always, once per migration, unless Stage 0 already records the operator-selected `solutionLayout`. | Should gRPC augment the existing solution, use a new solution that references WCF read-only, use a new solution with an immutable WCF test snapshot, or use a gRPC-only new solution? | This choice changes writable paths, build integration, dependency reuse, and parity-test design, so repository evidence cannot decide it. Recommend a new solution referencing original WCF projects read-only when the original solution must remain untouched and local WCF comparison is needed. A copied WCF tree is test-only because a second mutable/deployable copy creates drift. | `hosting`; immediate specification blocker. Skip only when Stage 0 already records the choice. |
| `hosting-model` | `HOST-*`, deployment-platform `DEP-*`, IIS/Windows Service/self-host evidence, or unknown target host. | Which approved platform will host the gRPC for .NET service? | Determines Kestrel/IIS/container integration, HTTP/2, service lifecycle, and operations. Recommend the existing supported platform when it meets HTTP/2/TLS and operational requirements; otherwise recommend Kestrel on the organization's standard platform. | `hosting`; blocker. Skip only when an approved platform policy already covers every affected service. |
| `operating-system` | OS-specific APIs, Windows auth, named pipes, IIS, COM+, service installers, or container constraints. | Must the target remain Windows-hosted, or may it run on the standard cross-platform environment? | Affects compatibility, image/runtime choice, identity, and local IPC. Do not infer organizational deployment permission from current Windows code. | `hosting`; blocker when platform-sensitive. |
| `service-process-layout` | Several `SVC-*` share a host/process, singleton state, conflicting scaling/SLA/security needs. | Should the affected services remain in one deployable host or be split into independently deployed gRPC hosts? | Determines failure isolation, scaling, ownership, and fleet write boundaries. Recommend preserving a cohesive host initially unless evidence shows materially different scaling, security, or release ownership. | `service-boundary`; blocker. Skip for one service/one host with no future split choice. |

## 2. Service, operation, and consumer scope

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `migration-scope` | Inventory contains multiple services, client-only scope, exclusions, or ambiguous ownership. | Which inventoried services and consumers are in this migration release? | Prevents silently planning out-of-scope work and drives dependencies/cutover. Offer evidence-backed slices, not an unbounded “all” assumption. | `service-boundary`; blocker. |
| `service-boundaries` | Contract inheritance, shared implementations, overlapping consumers/data, chatty calls, or one WCF service spans several business capabilities. | Should this WCF contract map to one gRPC service or be split along the evidenced capability boundary? | Protobuf service boundaries are durable and affect compatibility, latency, ownership, and rollout. Recommend one-to-one initially unless evidence supports a stable business split. | `service-boundary`; blocker per affected service. |
| `operation-scope` | Obsolete/dead operations, untraced callers, optional admin operations, or explicitly excluded features. | Are the identified operations required in the gRPC contract, or may any be retired with evidence and approval? | Every retained operation needs an RPC and parity validation; retirement can break unknown clients. Recommend retaining unless caller/traffic evidence and owner approval support removal. | `service-boundary` or `retirement`; blocker. |
| `consumer-upgrade-ownership` | `CON-*` has unknown `upgradeControl`, generated clients, or different release owners. | Who owns upgrading this consumer, and can its release be coordinated with the gRPC service? | Determines coexistence duration, contract packaging, and rollback. | `consumer-cutover`; blocker for cutover planning. Skip when ownership/control is evidenced and already approved. |

## 3. External clients and coexistence

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `external-consumer-support` | External-controlled/uncontrolled `CON-*`, public WSDL, partner endpoints, or unknown consumers. | Can each external consumer adopt gRPC directly within the migration window? | Uncontrolled clients can prevent WCF retirement. Ask per materially different consumer group. | `consumer-cutover`; retirement blocker. |
| `coexistence-strategy` | Consumers cannot move together, client-only repos, external clients, or rollback requirement. | Which gRPC-centered coexistence pattern will keep legacy consumers working during migration? | Side-by-side WCF/gRPC is usually the safest default because it preserves rollback. A SOAP adapter or gateway is temporary and requires explicit approval and exit criteria. | `coexistence`; blocker. Skip only for proven atomic cutover with approved risk. |
| `coexistence-duration` | Any bridge, dual endpoint, adapter, or staged consumer migration. | What event and latest date end coexistence for the affected legacy endpoint? | Temporary surfaces otherwise become permanent. Recommend measurable exit criteria: all consumers migrated, parity passed, and zero WCF traffic for an approved quiesce period. | `coexistence`; retirement blocker. |
| `browser-or-http-clients` | Browser, REST, mobile, or environments lacking native HTTP/2 gRPC support. | Must these clients use gRPC-Web or gRPC JSON transcoding as a supporting access surface? | Determines gateway/client support while preserving the same gRPC service implementation. Recommend only the minimum supporting surface required by evidenced consumers. | `coexistence`; blocker for those clients. |

## 4. Security identity and authorization replacement

Use
[`security-mapping.md`](../../map-wcf-to-grpc/references/security-mapping.md).
Never ask for credentials, keys, tokens, certificates, or connection strings.

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `identity-provider` | Windows/Kerberos, username, issued token, WS-Federation, message credentials, or unknown target identity. | Which approved identity provider and credential flow will authenticate the affected gRPC callers? | Windows/WS-* mechanisms do not map directly to gRPC. Recommend the organization's existing OIDC/OAuth 2.0 provider and short-lived JWTs when available. | `security`; blocking. |
| `service-authentication` | Internal service-to-service calls, certificate dependencies, zero-trust policy, or TLS client-credential evidence. | Will service-to-service callers use bearer workload identity, mTLS, or an approved combination? | Determines channel setup, certificate/token operations, and principal construction. Recommend managed workload identity/JWT; add mTLS when policy or trust boundaries require it. | `security`; blocking. |
| `transport-security` | SecurityMode.None, TLS termination, proxy/gateway, certificate evidence, external reachability. | Where must TLS terminate, and is encryption required on every backend hop? | HTTP/2/TLS topology affects trust boundaries and certificate ownership. Recommend TLS for production and explicit backend protection after gateway termination. | `security`; blocking. |
| `message-security-replacement` | WCF `SecurityMode.Message`, signing/encryption, WS-Security, or compliance risk. | Which approved TLS and application-level protection replaces the evidenced message-security requirement? | gRPC has no WS-Security equivalent. Recommend TLS/mTLS plus signed identity tokens; application field encryption only when a documented requirement survives threat/compliance review. | `security`; blocking, explicit approval. |
| `authorization-policy` | PrincipalPermission, roles, custom authorization manager/policy, ClaimsPrincipal checks, or operation authorization unknown. | Which claims and .NET authorization policy preserve this operation's access rules? | Authentication replacement can silently alter authorization semantics. Recommend policy-based authorization with stable claims and parity tests. | `authorization`; blocking. |
| `secret-certificate-ownership` | Certificate/identity dependencies or environment config. | Which team/system owns provisioning, rotation, revocation, and access policy for the required credentials? | Operational ownership is required without collecting secret values. | `security`; implementation blocker. |

## 5. Protobuf compatibility and ownership

Use
[`protobuf-type-mapping.md`](../../map-wcf-to-grpc/references/protobuf-type-mapping.md).

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `proto-ownership` | Any service is in scope. | Which team owns each `.proto` package and approves compatibility changes? | Protobuf contracts outlive implementations and require an accountable evolution owner. Recommend service-aligned ownership with a shared review gate for common types. | `protobuf`; blocking. |
| `package-versioning` | Any contract; multiple services/consumers or external consumers increase priority. | What package namespace and versioning policy will govern the gRPC API? | Package names and versions affect generated namespaces and breaking-change strategy. Recommend stable organization/domain/service `.v1` packages and additive evolution. | `protobuf`; blocking. |
| `compatibility-policy` | Existing/anticipated independent consumer releases, stored payloads, external clients. | Which compatibility checks and breaking-change approval process are required before publishing Protobuf changes? | Prevents field reuse and accidental consumer breaks. Recommend automated breaking-change checks, permanent field/name reservation, and explicit major-version approval. | `protobuf`; blocking. |
| `shared-contract-distribution` | Many consumers or repositories, common proto/error/decimal types. | How will approved Protobuf contracts and generated clients be distributed and versioned? | Determines reproducibility and consumer rollout. Recommend a versioned internal package/registry aligned with existing tooling. | `protobuf`; implementation blocker. |
| `polymorphism-policy` | `knownTypeIds`, inheritance, `XmlInclude`, open subtype loading. | Is the evidenced subtype set closed enough for `oneof`, or must an approved type registry support `Any`? | The choice is wire-significant and difficult to reverse. Recommend `oneof` for a known closed set; use `Any` only with explicit registry ownership. | `protobuf`; blocking. |

## 6. Decimal, null, default, and time semantics

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `decimal-representation` | `FLD-*` uses `decimal`, especially currency/scientific values. | Which lossless Protobuf representation will be standard for the affected decimal fields? | Protobuf has no decimal scalar; `double` can corrupt exact values. Recommend a shared typed decimal message for arithmetic domains, or canonical string only when interoperability outweighs typed handling. Never recommend `double` for currency. | `serialization`; blocking. |
| `presence-semantics` | Nullable scalars, `EmitDefaultValue=false`, required members, null checks, empty-vs-absent behavior. | Which fields must distinguish absent, null-equivalent, empty, and zero values? | Proto3 default values can erase business meaning. Recommend `optional` scalars or explicit wrapper/domain messages only where evidence requires presence. | `serialization`; blocking. Skip per field when code proves no presence distinction. |
| `timestamp-semantics` | `DateTime`, `DateTimeOffset`, local/unspecified kinds, persisted offsets. | Should the gRPC contract normalize these values to UTC `Timestamp`, and must the original offset/time-zone identity also be retained? | Normalization can change displayed or comparison semantics. Recommend UTC `Timestamp`; retain an explicit offset/time-zone field only when consumers need it. | `serialization`; blocking. |
| `duration-semantics` | `TimeSpan`, timeout/duration fields, negative/infinite sentinel values. | Do all evidenced values fit `google.protobuf.Duration`, or are sentinel/business semantics required? | Prevents silently converting infinite or special values. Recommend `Duration` for true elapsed durations. | `serialization`; blocking when special values exist. |
| `guid-format` | `Guid` fields and external consumers. | Will GUIDs use canonical lowercase strings or validated 16-byte values? | Both sides must agree on format and byte order. Recommend canonical strings unless measured payload constraints justify bytes. | `serialization`; usually non-blocking. |
| `xml-payload` | `XmlElement`, `XmlDocument`, `IXmlSerializable`, raw SOAP/XML blobs. | Must the XML payload remain opaque, or will it be redesigned as typed Protobuf messages? | Typed redesign improves validation; opaque XML preserves compatibility but retains legacy coupling. Recommend typed messages unless exact XML preservation is a requirement. | `serialization`; blocking, explicit approval for opaque XML. |

## 7. Faults and error semantics

Use
[`error-and-streaming-mapping.md`](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md).

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `fault-status-map` | `faultContractIds`, FaultException, IErrorHandler, or custom error envelopes. | Which gRPC status code and rich error detail represent this fault without exposing sensitive internals? | Clients branch on status/detail shape; inconsistent mappings become compatibility defects. Recommend a shared error policy and typed details for actionable domain faults. | `errors`; blocking. |
| `error-disclosure` | Detailed fault messages, stack traces, PII/compliance evidence. | Which error details may cross the service boundary in production? | Prevents leakage while preserving actionable client behavior. Recommend stable public messages/details and server-side logging of internal exceptions. | `errors`; blocking when sensitive. |
| `partial-failure` | Batch operations, one-way work, streams, multi-item responses. | How must partial success and per-item failure be represented? | A single RPC status cannot describe every item outcome. Recommend explicit per-item result messages when callers must continue after individual failures. | `errors`; blocking. |

## 8. Sessions, state, duplex, and streaming

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `session-state` | `usesSession=true`, PerSession, OperationContext state, sessionful binding. | Which state must survive between calls, and where will the gRPC design store it? | gRPC has no WCF session instance. Recommend eliminating incidental state; externalize required state to an approved durable/cache store keyed by explicit identity/correlation. | `session-state`; blocking. |
| `state-lifetime` | Externalized session/workflow state is approved. | What creates, expires, recovers, and deletes the externalized state? | Prevents leaks, stale behavior, and ambiguous failover. | `session-state`; blocking. |
| `duplex-lifecycle` | `duplex-callback`, CallbackContract, WSDualHttpBinding. | Will the callback workflow become a client-initiated bidirectional gRPC stream, and what is the stream lifetime? | gRPC cannot initiate callbacks outside an active stream. Recommend bidirectional streaming when synchronous live callbacks are required. | `streaming`; blocking. |
| `duplex-reconnect-delivery` | Duplex/long-lived streaming and missed callbacks matter. | What should happen to messages when the client disconnects or reconnects? | Determines acknowledgements, replay, retention, and duplicate handling. Recommend explicit sequence/idempotency keys; add durable support only when loss is unacceptable. | `streaming` or `reliable-delivery`; blocking. |
| `large-payload-streaming` | WCF streaming, MTOM, `Stream`, large `byte[]`, or quota risks. | Should this payload use gRPC streaming, a bounded unary message, or an approved external blob transfer referenced by gRPC? | Avoids memory pressure and message-limit failures. Recommend chunked streaming for in-band large transfer; external storage is supporting infrastructure requiring approval. | `streaming`; blocking. |
| `stream-backpressure` | Client/server/bidirectional streaming. | What buffering, cancellation, and slow-consumer behavior is required? | Prevents unbounded memory and stuck streams. Recommend bounded buffers and cancellation propagation. | `streaming`; implementation blocker. |

## 9. One-way operations

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `one-way-acknowledgement` | `shape=one-way` or IsOneWay. | Must the caller receive acceptance/completion status, or is durable asynchronous processing required after a quick gRPC acknowledgement? | gRPC has no fire-and-forget RPC and surfaces server status. Recommend unary acknowledgement for simple work; use an approved broker/outbox only when durable asynchronous semantics are required. | `reliable-delivery`; blocking. |
| `one-way-failure` | One-way operation has meaningful server-side failures. | How will callers or operators learn that accepted work later failed? | Determines status APIs, events, dead-letter handling, and observability. | `errors` or `observability`; blocking. |

## 10. Transactions, reliable sessions, queues, and named pipes

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `transaction-redesign` | `flowsTransaction=true`, TransactionScopeRequired, MSDTC, WS-AtomicTransaction. | Which gRPC-centered consistency pattern replaces the distributed transaction for these operations? | gRPC cannot flow ambient distributed transactions. Recommend local transactions plus outbox/saga for most cross-service workflows; require explicit compensation and consistency requirements. | `transactions`; blocking, explicit approval. |
| `consistency-requirement` | Transaction redesign or coupled writes. | Which invariants require immediate consistency, and which may become eventually consistent? | The answer determines whether saga/outbox is acceptable. | `transactions`; parent blocker before selecting pattern. |
| `reliable-delivery` | reliable sessions, ordered delivery, retries across reconnects, WS-ReliableMessaging. | What delivery guarantee is actually required across connection failures? | gRPC orders messages within a stream but does not provide exactly-once delivery. Recommend at-least-once plus idempotency/outbox where loss is unacceptable; do not promise exactly once without a proven application protocol. | `reliable-delivery`; blocking. |
| `queue-redesign` | MSMQ/NetMsmqBinding/message-queue dependency. | Which approved broker/worker design will support durable asynchronous work while gRPC remains the service API/control boundary? | Queues are supporting components, not replacement targets. Requires ownership, replay, dead-letter, retention, and operational approval. | `reliable-delivery`; blocking, explicit approval. |
| `ordering-scope` | `requiresOrderedDelivery=true`, queue/session ordering. | Is ordering required globally, per client, per entity, or only within one stream? | Narrow ordering enables scalable partitioning and avoids unnecessary serialization. Recommend the narrowest evidenced ordering key. | `reliable-delivery`; blocking. |
| `named-pipe-transport` | NetNamedPipeBinding/local-machine consumers. | Must communication remain machine-local, and is gRPC for .NET over Windows named pipes approved for those callers? | Preserves local IPC but affects hosting, permissions, diagnostics, and external access. Recommend named-pipe gRPC when locality is intentional; otherwise standard HTTPS gRPC. | `hosting`; blocking. |

## 11. Deadlines, retries, cancellation, and idempotency

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `deadline-policy` | Any production RPC; WCF timeout evidence seeds values. | What end-to-end deadline applies to this operation or operation class? | gRPC has no default deadline and propagated budgets prevent runaway call chains. Recommend evidence-based per-operation deadlines, not one global value. | `performance`; blocking for production readiness. |
| `retry-policy` | Transient dependencies, idempotent reads, WCF retry code, availability risk. | Which status codes and operations may be retried, with what attempt/backoff budget? | Unsafe retries can duplicate writes and amplify outages. Recommend retries only for transient statuses and proven idempotent operations, within the original deadline. | `reliable-delivery`; blocking. |
| `idempotency-policy` | Retriable writes, one-way work, queue/reliable delivery, duplicate risk. | Which mutating operations require an idempotency key, and how long are results/deduplication records retained? | Makes retries and at-least-once delivery safe. Recommend caller-generated stable keys and server-side deduplication for retriable mutations. | `reliable-delivery`; blocking. |
| `cancellation-semantics` | Long-running calls, streams, downstream work, current cancellation behavior. | Which work must stop when the gRPC caller cancels, and which accepted durable work must continue? | Distinguishes request cancellation from committed asynchronous processing. | `performance`; implementation blocker. |

## 12. SLAs, performance, and payload sizes

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `sla-objectives` | Any production service; especially differing criticality/traffic. | What availability, throughput, and P50/P95/P99 latency objectives must the gRPC service meet? | Drives scaling, deadlines, test thresholds, and cutover gates. Do not invent targets from current timeout config. | `performance`; validation/cutover blocker. |
| `baseline-source` | Existing tests/telemetry absent or incomplete. | Which production-safe source will provide the WCF latency, error-rate, throughput, and payload baseline? | Parity needs measured evidence, not assumptions. Recommend existing telemetry first, then controlled capture/load testing. | `performance`; cutover blocker. |
| `payload-limits` | Large contracts, quotas, MTOM, bytes, stream evidence, default 4 MB risk. | What observed and maximum request/response sizes must each RPC support? | Determines unary limits versus streaming and protects memory. Recommend measured percentiles plus a bounded safety margin. | `performance`; blocking. |
| `capacity-scaling` | Singleton/state, throttles, burst traffic, expensive dependencies. | What concurrency and burst behavior must the target sustain, and what is the scaling constraint? | Drives replicas, rate limiting, connection limits, and downstream protection. | `performance`; implementation blocker. |

## 13. Deployment, discovery, TLS, and gateways

> **Code/abstraction vs. environment split.** Each entry below asks for the
> code-observable mechanism choice (which tool, technology, or abstraction the
> service code and local configuration will use). **Specific environment
> hostnames, registry URLs, production addresses, environment progression
> schedules, approvals, and deployment-environment values are
> `deferred-operational`** (`deployment-environment-progression`) and do not
> block a complete specification draft.

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `deployment-mechanism` | Existing platform/deployment evidence or multiple environments. | Which deployment mechanism and tooling integration (container image, install script, Windows Service wrapper, k8s manifest) will the gRPC service use? | Determines the artifacts the implementer must produce (Dockerfile, helm chart, service installer) and which health-check and rollout hooks are needed. Recommend the existing standard automation when it supports HTTP/2 and TLS. Environment progression schedules and approvals are deferred. | `deployment`; code-side mechanism is `review-required`; environment-specific values are `deferred-operational`. |
| `service-discovery-mechanism` | Dynamic replicas, containers, current endpoint config, client-side addresses. | Which service-discovery mechanism (DNS SRV, platform service registry, static address list) will gRPC clients use? | Determines the configuration shape the implementer must write. Recommend the platform's supported DNS/service-discovery mechanism and documented load-balancing policy. Specific registry addresses and environments are deferred. | `deployment`; mechanism is `review-required`; specific values are `deferred-operational`. |
| `gateway-proxy-mechanism` | External ingress, TLS termination, browser clients, path routing, service mesh. | Which gateway or proxy type, if any, is approved and confirmed to support end-to-end gRPC/HTTP2 requirements? | Misconfigured proxies break streaming, deadlines, headers, and message sizes. The code must emit the correct headers and handle the proxy's behaviors. Specific gateway instance configuration is deferred. | `deployment`; mechanism is `review-required`; instance config is `deferred-operational`. |
| `certificate-operations` | TLS/mTLS required. | Which managed certificate source and rotation process will the deployment use? | Asks ownership/process only, never certificate contents or private keys. | `security`; implementation blocker. |
| `configuration-ownership` | Environment transforms, secrets, endpoint/timeouts vary by environment. | Which settings are deploy-time configuration, and who approves environment-specific values? | Prevents embedding environment details in contracts or code. | `deployment`; implementation blocker. |

## 14. Observability and compliance

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `telemetry-standard` | Existing diagnostics/inspectors/logging or organization platform unknown. | Which logging, metrics, tracing, correlation, and alerting platform must the gRPC service use? | Enables parity, incident response, and retirement evidence. Recommend OpenTelemetry with the organization's existing backend. | `observability`; production blocker. |
| `audit-requirements` | Audit inspectors, security logs, regulated operations, identity changes. | Which authenticated actions and decision-relevant fields must be auditable, and what retention/access controls apply? | Prevents losing WCF audit behavior or logging sensitive payloads. | `observability`; blocking when required. |
| `compliance-constraints` | WS-Security, message encryption, PII/payment/health data, explicit risk. | Which named compliance or data-handling requirements constrain the gRPC design? | Ask only standards/classifications and controls, never sensitive data. Determines encryption, residency, logging, approvals, and test evidence. | `security`; blocking. |
| `payload-logging` | WCF message logging/inspectors, golden traffic, sensitive fields. | May request/response payloads be captured, and what redaction/sampling rules apply? | Full payload logging can leak secrets/PII. Recommend metadata and structured business-safe fields by default. | `observability`; blocking before capture. |

## 15. Testing and golden traffic

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `parity-oracle` | Existing tests, WSDL/sample messages, business logic, unknown expected equivalence. | What is the authoritative oracle for contract and behavioral parity? | Defines acceptance beyond compilation. Recommend automated legacy-vs-gRPC comparison with explicit allowed semantic differences. | `other`; specification blocker. |
| `golden-traffic` | Production-like samples needed, complex faults/serialization/edge cases. | Can sanitized representative WCF traffic be captured and approved for replay/comparison? | Golden traffic finds undocumented semantics but may contain sensitive data. Recommend sanitized or synthetic equivalents under compliance approval; never collect secrets. | `other`; `out-of-scope-handoff`. Never entered into the decision log; handled exclusively through the compliance/data-governance authority process. |
| `test-environments` | External dependencies, queues, identity, transactions, streams. | Which test environment and dependency substitutes are approved for end-to-end parity? | Determines whether failures, identity, retries, and rollback can be exercised safely. | `other`; implementation blocker. |
| `compatibility-matrix` | Multiple consumer languages/frameworks/versions. | Which client languages and supported versions must generated-client compatibility tests cover? | Prevents a C#-only design from breaking external consumers. | `protobuf`; validation blocker. |

## 16. Rollback, cutover, and retirement

> **Offline guidance.** All topics in this section describe deployment-era
> operational decisions that cannot be answered by code analysis and cannot
> create executable `WP-*` implementation packages. `cutover-unit`,
> `cutover-gates`, and `rollback-trigger` are `deferred-operational` —
> documented as offline prerequisites in the roadmap but not included in the
> consolidated review approval scope. `rollback-data` has a code-observable
> side (additive schema constraint during coexistence) that stays in the
> specification; only the production data-recovery procedure is offline.
> `retirement-approval` is `out-of-scope-handoff` — recognized but never
> entered into the decision log.

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `cutover-unit` | Multiple services/consumers, coexistence, shared data. | Will traffic move by service, operation, consumer cohort, or percentage? | Defines routing blast radius and validation checkpoints. Recommend the smallest independently observable slice. | `consumer-cutover`; `deferred-operational`. Not a code choice; documented as a named offline prerequisite gate. |
| `cutover-gates` | Any production migration. | Which measured conditions must pass before increasing gRPC traffic? | Converts rollout into an auditable decision. Recommend contract/behavior/security parity, SLA thresholds, error budget, and rollback readiness. | `consumer-cutover`; `deferred-operational`. Not a code choice; documented as an offline gate. |
| `rollback-trigger` | Any cutover; data/schema changes increase priority. | Which signals require traffic to return to WCF, and who may trigger rollback? | Avoids debate during incidents. | `coexistence`; `deferred-operational`. Not a code choice; documented as an offline gate. |
| `rollback-data` | Writes, dual write/read, schema migrations, async processing. | How will data remain compatible and recoverable during rollback? | The code-side answer (additive-only schema changes during coexistence) belongs in the architecture specification. The production data-recovery procedure is an offline operational gate. Ask only the code-observable constraint: must schema changes be additive and backward-compatible throughout the coexistence window? | `coexistence`; `review-required` for the code-observable constraint; production data-recovery procedure is `deferred-operational`. |
| `retirement-approval` | Planned WCF shutdown. | Who approves WCF retirement after parity and zero-traffic evidence, and what quiesce period is required? | Retirement is irreversible for uncontrolled clients. Recommend explicit approval after all consumers migrate and monitoring proves no legacy traffic. | `retirement`; `out-of-scope-handoff`. Never entered into the decision log; handled exclusively through the retirement authority process. |

## 17. Implementation and fleet constraints

| Topic key | Trigger and evidence | Focused question | Why / recommendation | Category / gate / skip |
|---|---|---|---|---|
| `repository-strategy` | Multiple repos/projects, shared contracts, client-only/server split. | In which repository and ownership boundary will proto, server, generated client, and shared policy changes be implemented? | Determines work-package dependencies and integration ownership. | `other`; implementation blocker. |
| `shared-foundation-owner` | Shared proto types, auth, interceptors, hosting, observability, package management. | Who owns the sequential shared foundation that service migrations depend on? | Shared files cannot safely be edited by parallel agents/teams without one integration owner. | `other`; fleet blocker. |
| `fleet-parallelism` | Several independent service slices are in scope. | Which service slices have disjoint exclusive-write paths and may be implemented in parallel after foundation/pilot gates? | Prevents merge conflicts and inconsistent shared policy. Recommend sequential foundation and pilot, then parallel only for evidenced disjoint slices. | `other`; fleet blocker. |
| `pilot-selection` | Multiple services available. | Which low-risk service/consumer slice is approved as the pilot? | Validates shared runtime, security, deployment, and compatibility before fleet scale-out. Recommend low traffic, controlled consumers, unary calls, and no session/transaction/duplex risk. | `other`; implementation blocker. |
| `delivery-constraints` | Release freezes, staffing, licensing, unsupported tooling, fixed dates. | Which implementation constraints materially limit sequencing, tooling, or deployment? | Makes roadmap and fleet eligibility realistic. Ask only constraints that cannot be inferred from repository evidence. | `other`; planning blocker. |

## Dependency and skip examples

- If migration scope excludes `SVC-x`, skip its serialization and streaming
  choices but retain any shared-contract question still affecting included
  services.
- If no external/uncontrolled consumer exists and all internal consumers can
  release atomically, deprioritize coexistence; do not skip rollback.
- If a session decision removes state entirely, skip state-store lifetime and
  eviction questions.
- If an operation becomes unary acknowledgement with no durable continuation,
  skip broker selection but still ask deadline/idempotency where applicable.
- If code proves all `DateTime` values are UTC and no offset is consumed,
  recommend `Timestamp` and ask only for confirmation when the choice is
  contract-significant.
- If an approved organization policy already specifies OIDC, OpenTelemetry,
  deployment, or discovery and applies to the affected IDs, reuse it and ask
  only repository-specific exceptions.
