# Implementation Checklist

Normative per-surface guidance for turning an approved work package's
`deliverables` and `acceptanceCriteria` into code. This checklist tells you
**how to build what the specification already decided** — it never chooses
architecture. Every design value (the .NET target, proto package naming,
error-status mapping, security mode, deadline policy, and so on) comes from
`migration-spec.json`'s `targetArchitecture` sections and the package's
linked `SPEC-*` contract, not from this file. When a value this checklist
needs is not resolved in the spec, stop and report it as a blocking gap —
do not substitute a default from here.

Background design rules referenced below live in
[`../../map-wcf-to-grpc/references/`](../../map-wcf-to-grpc/references/):
[feature mapping](../../map-wcf-to-grpc/references/feature-mapping.md),
[type mapping](../../map-wcf-to-grpc/references/protobuf-type-mapping.md),
[security mapping](../../map-wcf-to-grpc/references/security-mapping.md),
[error/streaming mapping](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md),
and [hosting/rollout](../../map-wcf-to-grpc/references/hosting-and-rollout.md).
Only implement the surfaces your assigned package's `scope` and
`deliverables` actually name.

## 0. Before writing anything

1. Read the resolved `target-runtime` and `hosting` sections of
   `targetArchitecture`. Use the exact framework moniker, gRPC package set
   (`Grpc.AspNetCore`, `Grpc.Net.Client`, `Grpc.Tools`, `Google.Protobuf`),
   and tooling versions they name. If either section is `unresolved`, stop —
   you cannot create a project file, `<TargetFramework>`, or package
   reference without it.
2. Read the package's `SPEC-*` contract(s) for the exact `protoFile`,
   `protoPackage`, `apiVersion`, RPC shapes, message field numbers,
   reservations, and policies you must implement.
3. Open every file your package's `fleet.fileOwnership` lists before editing
   any of them, to confirm the current state matches what the spec assumes.

## 1. Proto contracts and codegen setup

- Create/modify exactly the `.proto` file(s) named in the package's
  `deliverables`, at the `protoFile` path the `SPEC-*` declares, using the
  `protoPackage`, `csharp_namespace`, and any other per-language options the
  `protobuf-versioning` architecture section names.
- Assign field numbers exactly as recorded in each `MSG-*`; never renumber an
  existing field. Copy `reservedNumbers`/`reservedNames` verbatim as `reserved`
  statements for every removed field. Never use 19000–19999.
- Wire the build: add `<Protobuf Include="..." GrpcServices="Server|Client|Both" />`
  items (or the repository's existing equivalent) only in the project(s) the
  package owns. Do not restructure a shared `Directory.Build.props`,
  `Directory.Packages.props`, or solution file unless your package is the
  named owner of that shared surface.
- If the architecture names a compatibility-check tool (for example a `buf
  breaking` configuration), run/extend it only as the package's validation
  step specifies; do not introduce a new tool the repository does not have.
- Shared/common protos (decimal, money, error-detail types) are owned by the
  foundation package. A per-service package imports them; it does not
  redefine or edit them.

## 2. ASP.NET Core gRPC server hosting

- Add the gRPC server only to the project(s)/host the `hosting` architecture
  section and the package's deliverables name. Configure Kestrel endpoints
  (HTTP/2, TLS, and HTTP/1.1 coexistence for health/metrics/transcoding
  exactly as specified), the process model, and configuration/secret sources
  by reference only.
- Replace named-pipe/local-transport bindings only as the `hosting` section
  specifies (`ListenNamedPipe`/Unix domain socket), matching the WCF
  binding it replaces.
- Register the gRPC service(s) in the DI composition root only through the
  package that owns host bootstrap; a per-service package adds its service
  registration through the extension point that package exposes, not by
  editing the composition root file directly, unless your package is that
  owner.
- Do not change the hosting model of a service the package does not own.

## 3. Adapters to existing business logic

- The gRPC service implementation is a thin adapter: convert the request
  message to the existing business-logic call's inputs, invoke the existing
  method/service exactly as before, convert the result back to the response
  message, and map exceptions/faults per the `errors` architecture section.
- Do not rewrite, "improve", or re-architect the existing business logic
  itself unless the package's scope explicitly says so (for example a
  state-redesign or consistency-redesign package). Preserve its existing
  behavior, transactions, and side effects unless the spec requires a
  redesign.
- Apply the data-type conversions the `data-types` section and the message's
  field-level `conversionRules`/`validationRules` specify — presence,
  `decimal`, date/time, GUID, enum, collection, and polymorphism handling —
  exactly as recorded, including documented edge cases (nulls versus
  defaults, empty versus missing collections, unknown enum values).

## 4. Clients

- Generate the client from the same `.proto` the server uses; do not hand
  author a duplicate client contract.
- Configure the channel exactly as the `deadlines-retries` and `security`
  sections specify: TLS/mTLS, credentials, keep-alive, connection reuse, and
  load-balancing/service-discovery settings.
- A consumer-migration package replaces the WCF client call with the
  generated gRPC client call behind the same call site/interface where
  possible, preserving the consumer's existing error-handling contract
  unless the spec requires a change.

## 5. Auth/authz

- Implement the authentication scheme the `security` section names (for
  example OIDC/JWT bearer, mTLS with client-certificate validation) — never
  substitute your own scheme.
- Implement ASP.NET Core authorization policies from the `authorization`
  section; apply the default (deny-by-default) policy at the service level
  and per-RPC overrides exactly as each `RPC-*`'s `authorizationPolicy`
  states. "Inherits the service default" is only valid when that default is
  defined in the section.
- Never hardcode a bypass, a wildcard allow, or a test-only credential in
  production configuration.

## 6. Interceptors and error mapping

- Implement the server interceptor(s) that replace `IErrorHandler`: catch
  the exceptions/faults the `errors` section's mapping table lists and
  translate each to its mapped gRPC status code and rich error detail model
  (for example `google.rpc.Status` with typed detail messages) exactly as
  specified. Every `FaultContract` in the relevant `SPEC-*` must appear in
  this mapping.
- Never let internal exception text, stack traces, or secret values reach
  the client. Propagate the correlation ID per the `observability` section.
- Implement the client-side contract for distinguishing retryable from
  terminal failures exactly as the section states.

## 7. Deadlines, cancellation, retries, and idempotency

- Propagate deadlines from the `deadlines-retries` section's per-operation-
  class policy into `CallOptions.Deadline` (client) and honor incoming
  deadlines on the server.
- Flow `CancellationToken` from the gRPC call context into the adapted
  business-logic call so cancellation actually stops server work, not just
  the network response.
- Implement the idempotency classification and idempotency-key mechanism the
  contract's `idempotencyPolicy` states for each `RPC-*`.
- Implement the retry/hedging policy (retryable status codes, backoff,
  attempt limits) only for the RPCs the section marks retryable; never add
  retries to an RPC the spec marks non-idempotent/non-retryable.
- Implement the specified replacement for one-way operations (unary
  acknowledgement or queue-backed accept) and make the delivery-guarantee
  change explicit in code comments/documentation only where the spec asks
  for it — do not silently keep fire-and-forget semantics if the spec
  requires acknowledgement.

## 8. Telemetry and health

- Wire structured logging with the correlation/trace identifiers the
  `observability` section names; add OpenTelemetry tracing and metrics for
  the RPC signals it lists (rate, error, duration, payload size); apply its
  log-redaction rules.
- Expose `grpc.health.v1.Health` with per-service statuses per the
  `health-checks` section; implement the liveness/readiness distinction and
  the dependency probes it names; implement graceful-drain behavior for
  shutdown so in-flight and streaming calls end cleanly.
- Do not introduce an observability stack (exporter, dashboard, alert
  system) the section does not name.

## 9. Streaming, session/state, and transaction redesign

- Implement the exact RPC `shape` (`unary`, `server-streaming`,
  `client-streaming`, `bidirectional-streaming`) each `RPC-*` declares, plus
  its documented stream lifecycle: initiation, termination, reconnect/resume,
  message ordering, backpressure, and cancellation. This is the replacement
  for `CallbackContract` duplex operations and streamed transfers; do not
  invent a different shape.
- Implement the session/instance-state redesign the `service-boundaries`
  section and the package's `state-redesign` scope specify: a stateless
  service plus the named external state store, key derivation, TTL/eviction,
  and concurrency control — never re-introduce server-affinity or
  `InstanceContextMode.PerSession` semantics.
- Implement the transaction/reliable-session redesign the `errors` and
  `deployment` sections specify (saga/compensation or outbox, idempotency
  keys, retry-safe boundaries, reconciliation) exactly as designed. Never
  attempt to simulate a two-phase commit across gRPC calls; if the spec's
  redesign is insufficient for what the code actually needs, stop and report
  it rather than inventing a substitute consistency mechanism.

## 10. Tests

- Add the tests the package's `acceptanceCriteria` and `validation` steps
  require: contract shape/field mapping (including edge cases), fault-to-
  status mapping, authorization (allow and deny), deadline/cancellation
  behavior, streaming lifecycle, and — when the package covers it —
  coexistence routing.
- Place tests only in the project(s)/paths the package owns. Use the
  repository's existing test framework and conventions; do not introduce a
  new test framework.
- A test proves the acceptance criterion it is linked to; do not write a
  test that merely exercises unrelated code to pad coverage.

## 11. Deployment changes

- Change only the deployment artifacts (Dockerfiles, orchestration manifests,
  pipeline definitions, configuration) the package's `deliverables` name, and
  only for the rollout mechanics, coexistence routing, or scaling/resource
  baseline the `deployment`/`coexistence` sections specify.
- Any routing change during coexistence must keep the legacy WCF endpoint
  reachable per the package's `coexistence` plan; do not remove a route the
  plan says must stay routable.
- Database or shared-state migrations included in a package must be additive
  and backward compatible during coexistence, matching the `deployment`
  section's data-ordering rule.

## Cross-references

| Legacy construct | Spec section that designed it | This checklist section that implements it |
|---|---|---|
| Duplex callbacks | `service-boundaries`, `deadlines-retries` | §9 Streaming |
| `InstanceContextMode.PerSession` | `service-boundaries` | §9 Session/state |
| `InstanceContextMode.Single`/`ConcurrencyMode` | `service-boundaries` | §2 Hosting, §3 Adapters |
| Distributed transactions/MSDTC | `errors`, `deployment` | §9 Transaction redesign |
| Reliable sessions/MSMQ | `deadlines-retries` | §7 Retries/idempotency |
| One-way operations | `deadlines-retries` | §7 One-way replacement |
| Streamed transfer | `data-types`, `service-boundaries` | §9 Streaming |
| Message headers/inspectors | `data-types`, `observability` | §6 Interceptors, §8 Telemetry |

A construct appearing in this table with no corresponding approved design in
the spec is not something this checklist authorizes you to design yourself —
report it as a blocking gap.
