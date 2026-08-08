# Parity Checklist

Normative gate definitions for `validate-grpc-parity`. Each gate states its
question, its **required checks** (what must be executed or compared), its
**measurable pass criteria** (the literal condition for `pass`), its
**required evidence**, and the **default severity** of a deviation.

Gate states are `pass`, `fail`, `blocked`, `not-applicable`, and
`not-assessed`; findings and status computation are defined in
[`evidence-and-findings.md`](evidence-and-findings.md).

Design rules referenced below live in the mapping skill:
[feature mapping](../../map-wcf-to-grpc/references/feature-mapping.md),
[Protobuf type mapping](../../map-wcf-to-grpc/references/protobuf-type-mapping.md),
[error and streaming mapping](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md),
[security mapping](../../map-wcf-to-grpc/references/security-mapping.md),
[hosting and rollout](../../map-wcf-to-grpc/references/hosting-and-rollout.md).
This checklist validates against those rules **as the approved
`migration-spec.json` applied them** — where the spec made an explicit,
approved decision that differs from a default, validate the spec's decision
and record the divergence, do not fail the gate for not matching a default.

## Universal rules for every gate

1. **A gate is `pass` only when every one of its required checks passed with
   its required evidence.** There is no partial pass. Coverage below 100% of
   the in-scope items is `fail` (deviation observed) or `blocked` (not
   observable), never a qualified pass.
2. **Behavioral gates require executed runtime evidence.** Gates 3–13 may
   never be `pass` on static analysis, a signature or descriptor comparison,
   a green build, a code review, or an implementer's claim. When only static
   evidence exists, the gate is `blocked` with an `evidence-gap` finding.
3. **A comparison needs both sides.** A behavioral check compares observed
   gRPC behavior with a legacy baseline (inventory evidence, recorded Phase 0
   baseline, or an executed legacy call). Without a baseline the check is
   `blocked`, not `pass`.
4. **Known, approved semantic differences are tolerances, not failures** —
   but only when the decision log records them (for example UTC
   normalization of `DateTime`, `decimal` representation, or enum default
   handling). An undeclared difference is a finding.
5. **`not-applicable` requires proof of absence**, cited from the inventory
   (for example "no `[FaultContract]` in scope: `inventory.json` services in
   scope declare zero fault contracts"). "Probably unused" is
   `not-assessed`, not `not-applicable`.

---

## 1. `contract-parity` — schema and Protobuf compatibility

**Question:** does the gRPC contract cover, and remain compatible with,
everything the WCF contract exposed and everything previously published?

**Required checks**

1. Every in-scope `OP-*` in the inventory maps to exactly one `RPC-*` in the
   spec and to a `rpc` method that exists in the shipped `.proto`, with the
   RPC shape (unary/server/client/bidirectional) the spec declares.
2. Every in-scope `DC-*`/`FLD-*` maps to a `MSG-*` field of the specified
   type, or is explicitly recorded in the spec as intentionally dropped with
   a decision id.
3. No `rpc`, message, or field exists in the shipped `.proto` that the spec
   does not specify (undeclared surface is a contract defect).
4. Field numbers match the spec's assigned numbers exactly; no field number
   was renumbered, reused, or shifted since the previous published
   descriptor.
5. Every removed field or enum value has a `reserved` number **and**
   `reserved` name entry; no reserved number is reused.
6. Enum zero values, `oneof` groupings, `optional`/presence markers,
   `package`/`option csharp_namespace` values, and the api-version segment
   match the spec.
7. Backward compatibility against the last published descriptor: no field
   type change, no label change, no message/service/method rename or
   removal, no cardinality change.
8. Generated code builds from the shipped `.proto` and the codegen wiring is
   the spec's (`Grpc.Tools` items or the declared equivalent).

**Measurable pass criteria**

- In-scope operation coverage = 100%, message/field coverage = 100%.
- Undeclared proto surface count = 0.
- Renumbered/reused field numbers = 0; unreserved removals = 0.
- Descriptor compatibility check reports 0 breaking changes.

**Required evidence:** the descriptor or `.proto` comparison output (a
`protoc`/descriptor-set diff, a breaking-change checker run, or an explicit
enumerated table when no tool exists), the codegen build output, and the
inventory/spec locators for each mapped pair.

**Default severity:** missing operation, incompatible type change, renumber,
reuse, or unreserved removal → **blocking**. Cosmetic naming or comment
divergence → **non-blocking**.

**Reference:** [protobuf-type-mapping.md](../../map-wcf-to-grpc/references/protobuf-type-mapping.md)
§12 field numbering policy; [feature-mapping.md](../../map-wcf-to-grpc/references/feature-mapping.md)
§1.

---

## 2. `build-and-tests` — build, unit, and integration execution

**Question:** does the migrated code actually build, and do its own tests
actually pass, at the scope's current commit?

**Required checks**

1. The narrowest build command covering the scope runs and succeeds; warnings
   that the spec treats as errors are honored.
2. Every `VAL-*` step attached to the in-scope work packages runs with its
   exact `command` and `workingDirectory`; the observed result is recorded
   as `passed`, `failed`, or `blocked`.
3. Unit tests for the migrated services run; the pass count, fail count,
   skipped count, and total are recorded.
4. Integration tests that exercise the gRPC surface end to end (real
   channel, real server) run and are identified as such — an in-process
   test double is not integration evidence.
5. Each `AC-*` on the in-scope work packages is confirmed met or not met
   against its `evidenceRequired`, independently of the implementer's claim.
6. Flaky or skipped tests covering in-scope behavior are enumerated.

**Measurable pass criteria**

- Build exit code = 0.
- Failed tests = 0 within the scope's test targets.
- Executed `VAL-*` coverage = 100% of the in-scope steps (none left
  `not-run` without a `blocked` reason).
- `AC-*` met = 100% of in-scope criteria, each with observed evidence.

**Required evidence:** exact commands with working directories, exit codes,
and redacted output captures; test result counts and the names of failing or
skipped tests.

**Default severity:** build failure, failing test, or unmet `AC-*` →
**blocking**. Skipped non-critical test or missing coverage for a
non-behavioral concern → **non-blocking** finding requiring remediation.

**A passing build and green tests satisfy this gate only.** They are never
evidence for gates 3–13.

---

## 3. `success-behavior` — WCF-vs-gRPC success paths

**Question:** for the same logical request, does the gRPC service return an
equivalent result to the WCF service?

**Required checks**

1. Every in-scope operation is invoked over a real gRPC channel with at
   least one representative request, and the response is compared field by
   field with the legacy baseline for the same input.
2. Business-rule outcomes (computed totals, status transitions, generated
   identifiers, ordering of returned collections) match the baseline or a
   recorded tolerance.
3. Side effects match: the same persisted rows/messages/audit entries are
   produced, and no extra side effect appears.
4. Empty, boundary, and maximum-size representative inputs are exercised,
   not only the happy nominal case.
5. Idempotent read operations return identical results on repeat calls.
6. Any operation that cannot be exercised is listed with the reason.

**Measurable pass criteria**

- Operations exercised = 100% of in-scope operations.
- Field-level mismatches outside recorded tolerances = 0.
- Unexplained side-effect differences = 0.

**Required evidence:** per-operation request/response comparison (redacted or
synthetic data), the baseline source, and the executed command or test name.

**Default severity:** wrong value, missing field, wrong ordering where order
is contractual, or a missing/extra side effect → **blocking**. A cosmetic
difference already recorded as a tolerance → not a finding; an undocumented
but harmless difference → **non-blocking** with a request to record the
tolerance.

---

## 4. `error-parity` — typed faults, status codes, and error details

**Question:** does every failure mode that previously produced a WCF fault
now produce the specified gRPC status and error detail — and nothing more?

**Required checks**

1. Every in-scope `[FaultContract]`/`PF-*` failure mode is triggered and the
   resulting `RpcException` status code matches the spec's mapping.
2. Rich error details are present and decodable where the spec requires
   them (`google.rpc.Status` in `grpc-status-details-bin` trailers, packed
   detail messages with the specified fields).
3. Untyped/unhandled server exceptions surface as the specified status
   (normally `UNKNOWN` or `INTERNAL`) and **never** leak stack traces,
   internal type names, SQL text, file paths, host names, or secret values
   in `Status.Detail` or trailers.
4. Validation failures map to the specified code (commonly
   `INVALID_ARGUMENT`), not-found to `NOT_FOUND`, conflict to
   `ALREADY_EXISTS`/`ABORTED`, throttling to `RESOURCE_EXHAUSTED`,
   authorization to `PERMISSION_DENIED`, missing credentials to
   `UNAUTHENTICATED`, per the spec's `errors` architecture section.
5. The client side observes the status/detail contract the spec promises
   (the generated client can round-trip the detail type).
6. Error behavior inside streams is exercised: a failure mid-stream
   terminates the call with the specified status.

**Measurable pass criteria**

- Fault modes exercised = 100% of in-scope fault contracts and specified
  error cases.
- Status-code mismatches = 0.
- Missing required error details = 0.
- Information-leak occurrences = 0.

**Required evidence:** per-case triggered request, observed status code,
observed trailer/detail content (redacted), and the baseline WCF fault it
replaces.

**Default severity:** wrong status code, missing required detail, or any
information leak → **blocking**. Message wording differences that carry no
contractual meaning → **non-blocking**.

**Reference:** [error-and-streaming-mapping.md](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md)
§1.

---

## 5. `serialization-parity` — type and value semantics

**Question:** do values survive the round trip with the same meaning?

**Required checks (each exercised with a real call, not a unit conversion
test alone)**

1. **`decimal`**: monetary and high-precision values round-trip with no
   precision or scale loss, including the largest and smallest in-scope
   magnitudes and negative values, using the spec's decimal representation.
   Any `double`-based representation of money is a finding regardless of the
   observed sample passing.
2. **Presence, null, and defaults**: a field the WCF contract could send as
   `null` is distinguishable from one sent as its zero value, per the spec's
   presence strategy (`optional`, wrapper types, or an explicit "absent
   means default" decision). Verify that an omitted field does not silently
   become `0`, `""`, or `false` where the legacy semantics were nullable.
3. **Date and time**: `DateTime`/`DateTimeOffset` values round-trip through
   `google.protobuf.Timestamp` with UTC normalization, `DateTimeKind`
   handling, offsets, and unspecified-kind values behaving per the spec;
   `TimeSpan` via `Duration`; and date-only/time-only values per the spec.
   Cross a DST boundary when local time was contractually significant.
4. **GUID**: representation matches the spec (string form and casing, or
   `bytes` ordering), and round-trips without reordering or case-sensitivity
   defects.
5. **Enums**: every legacy enum value has a mapping; the zero value is the
   specified unspecified/default member; unknown incoming values behave as
   specified rather than throwing; flags enums use the specified
   representation.
6. **Polymorphism and inheritance**: `KnownType`/derived types round-trip
   through the specified `oneof` or `Any` design; an unmapped derived type
   is rejected as specified rather than silently degraded to the base type.
7. **Collections and dictionaries**: empty vs. absent collections behave as
   specified, `map` key types and ordering expectations hold, and nested or
   null elements behave as specified.
8. **Byte arrays and large payloads**: binary content round-trips
   byte-identically, including at the maximum in-scope size.
9. **XML-specific constructs**: any `XmlElement`, `IXmlSerializable`,
   namespace-order-dependent, or MTOM construct in the inventory is covered
   by the spec's replacement and validated against it.

**Measurable pass criteria**

- Serialization-sensitive `FLD-*` in scope covered = 100%.
- Round-trip mismatches outside recorded tolerances = 0.
- Precision/scale loss occurrences = 0.

**Required evidence:** per-category round-trip case with the input value,
the observed output value, and the comparison verdict.

**Default severity:** precision loss, null-vs-default collapse, timestamp
offset error, GUID corruption, enum mismapping, polymorphic degradation, or
binary corruption → **blocking**. Formatting-only differences with a
recorded tolerance → not a finding.

**Reference:** [protobuf-type-mapping.md](../../map-wcf-to-grpc/references/protobuf-type-mapping.md).

---

## 6. `security-parity` — authentication, authorization, TLS, and mTLS

**Question:** is every caller who was rejected under WCF still rejected, and
is the transport at least as protected?

**Required checks**

1. **Unauthenticated access**: a call without credentials to a protected
   method returns `UNAUTHENTICATED` and performs no side effect.
2. **Authenticated but unauthorized**: a principal lacking the required
   role/scope/claim receives `PERMISSION_DENIED`; the legacy denial set is
   reproduced case by case from the inventory's authorization data.
3. **Authorized**: each legitimately authorized principal succeeds, per
   method-level policy including any per-RPC override and any
   `[AllowAnonymous]` equivalent.
4. **Token handling**: expired, malformed, wrong-audience, wrong-issuer, and
   wrong-signature credentials are all rejected; none is accepted.
5. **TLS**: the endpoint requires TLS with the specified protocol versions;
   plaintext HTTP/2 is not reachable on a non-loopback interface unless the
   spec explicitly approves it (for example behind a TLS-terminating proxy,
   which must itself be validated).
6. **mTLS**: when specified, a client without a valid certificate is
   rejected, an untrusted or expired certificate is rejected, and the
   certificate identity is mapped to a principal as specified.
7. **Replacement of WCF-only security**: where Windows/Kerberos, message
   security, or WS-* was used, the specified replacement is exercised and
   the residual gap is stated explicitly.
8. **Secret handling**: no credential, key, or certificate material is
   present in the repository, in configuration, or in logs observed during
   the run.

**Measurable pass criteria**

- Authorization test cases derived from the inventory covered = 100%.
- Authorization bypasses = 0; unauthenticated successes on protected
  methods = 0.
- TLS/mTLS negative cases rejected = 100%.
- Secrets found in code, config, logs, or evidence = 0.

**Required evidence:** per-case credential class (never the credential
value), the invoked method, and the observed status code; TLS handshake
observations; certificate-rejection observations.

**Default severity:** any bypass, any accepted invalid credential, any
unintended plaintext exposure, or any exposed secret → **blocking**, always,
regardless of environment. Missing defence-in-depth hardening the spec lists
as optional → **non-blocking**.

**Reference:** [security-mapping.md](../../map-wcf-to-grpc/references/security-mapping.md).

---

## 7. `resilience-parity` — deadlines, cancellation, retries, idempotency

**Question:** do time limits, cancellation, and retry behavior preserve the
legacy contract without duplicating effects?

**Required checks**

1. A call that exceeds its deadline terminates with `DEADLINE_EXCEEDED` at
   the client, and the deadline value matches the spec's mapping from the
   legacy binding timeouts.
2. The server observes cancellation: when the client cancels or the deadline
   expires, the server-side `CancellationToken` is raised and the work stops
   (verified by an observable effect, not by reading the code).
3. Deadlines propagate across service hops where the spec requires it.
4. The retry/hedging policy matches the spec (codes retried, max attempts,
   backoff); non-retryable codes are not retried.
5. Retries never duplicate effects for operations the spec marks idempotent:
   a forced retry produces exactly one effect, verified against the data
   store or an effect counter.
6. Non-idempotent operations are excluded from automatic retry, or protected
   by the specified idempotency-key mechanism, which is exercised with a
   duplicate submission.
7. One-way (`IsOneWay`) legacy operations behave per the spec's replacement,
   including its acknowledgement and failure-visibility semantics.

**Measurable pass criteria**

- Deadline cases exercised = 100% of the in-scope operations with a legacy
  timeout; observed status = `DEADLINE_EXCEEDED` in all.
- Server-side cancellation observed = yes for every long-running in-scope
  operation.
- Duplicate effects under forced retry = 0.

**Required evidence:** executed deadline/cancel/retry cases with observed
statuses, effect counts before/after, and the configured policy values read
from the running configuration.

**Default severity:** duplicated effect, ignored cancellation, or a
non-idempotent operation exposed to automatic retry → **blocking**. Backoff
tuning divergence within the spec's stated tolerance → **non-blocking**.

**Reference:** [error-and-streaming-mapping.md](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md)
§8; [feature-mapping.md](../../map-wcf-to-grpc/references/feature-mapping.md)
§2.1.

---

## 8. `streaming-parity` — unary and streaming call shapes

**Question:** does each call shape behave correctly for its whole lifecycle,
including the redesign that replaced duplex callbacks?

**Required checks**

1. **Unary**: request/response completes, with trailers and status observed.
2. **Server streaming**: all expected messages arrive in order, the stream
   completes with `OK`, client-side early cancellation stops production,
   and back-pressure/flow control does not deadlock.
3. **Client streaming**: all client messages are consumed, the single
   response reflects the complete set, and a mid-stream client failure
   yields the specified status.
4. **Bidirectional streaming**: concurrent send/receive works, message
   ordering per direction is preserved, half-close is handled, and an
   idle/keep-alive period does not silently drop the call.
5. **Duplex-callback replacement**: where WCF used a `CallbackContract`, the
   specified bidirectional-stream or event-delivery redesign is exercised
   end to end, including client reconnect after a broken stream and the
   at-least-once/at-most-once semantics the spec promises.
6. **Streamed payloads**: large or chunked payload streaming completes
   within message-size limits and without buffering the whole payload where
   the spec forbids it.
7. **Failure and retry**: stream failure semantics match the spec; retries
   on streaming calls follow the documented restrictions.

**Measurable pass criteria**

- Distinct call shapes present in the scope exercised = 100%.
- Message loss, duplication, or reordering within a stream = 0 (or exactly
  the spec's declared semantics).
- Hangs/deadlocks observed = 0.

**Required evidence:** per-shape executed exercise with message counts,
ordering observations, completion status, and cancellation/reconnect
observations.

**Default severity:** message loss, reordering where order is contractual,
deadlock, or a callback replacement that cannot deliver → **blocking**.
Suboptimal chunk sizing → **non-blocking**.

**Reference:** [error-and-streaming-mapping.md](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md)
§§2–3.

---

## 9. `state-and-consistency` — sessions, concurrency, transactions, reliable delivery

**Question:** do the redesigns that replaced WCF sessions, instance/
concurrency modes, distributed transactions, and reliable messaging actually
hold under concurrent, failing conditions?

**Required checks**

1. **Session/instance state**: where WCF used `PerSession` or `Single`
   instancing, the specified external state store is exercised — state is
   read/written across calls, survives a server restart if the spec requires
   it, expires as specified, and is isolated per principal/session key.
2. **Statelessness**: services the spec declares stateless are verified to
   leak no state between calls (scoped/singleton DI lifetimes behave as
   specified; a second call sees no residue from the first).
3. **Concurrency**: concurrent calls against the same entity produce the
   specified outcome (last-write-wins, optimistic concurrency conflict as
   `ABORTED`, or locking) with no corruption, lost update, or deadlock.
4. **Transactions**: where WCF used `TransactionFlow`/MSDTC, the specified
   saga/outbox/compensation design is exercised including a forced
   mid-sequence failure, and the system converges to the specified
   consistent state; residual inconsistency windows are documented.
5. **Reliable delivery**: where WS-ReliableMessaging or MSMQ existed, the
   specified acknowledgement/idempotency/queue replacement is exercised for
   duplicate delivery, out-of-order delivery, and consumer restart.
6. **Ordering guarantees** the legacy system provided are either preserved
   or explicitly and visibly relaxed by a recorded decision.

**Measurable pass criteria**

- Redesigned mechanisms in scope exercised under failure = 100%.
- Data corruption, lost updates, or unrecoverable partial states observed =
  0.
- Undocumented consistency-window regressions = 0.

**Required evidence:** concurrency/failure-injection exercise output, state
store observations before/after, and the specified-versus-observed
convergence result.

**Default severity:** corruption, lost update, unbounded inconsistency, or a
lost message where delivery was guaranteed → **blocking**. A documented,
approved, bounded inconsistency window → not a finding; an undocumented one
→ **blocking** until recorded.

**Reference:** [error-and-streaming-mapping.md](../../map-wcf-to-grpc/references/error-and-streaming-mapping.md)
§§4–7.

---

## 10. `performance-and-limits` — payload limits, latency, throughput

**Question:** does the gRPC service meet the agreed performance envelope and
handle the payload sizes the legacy service handled?

**Required checks**

1. Maximum in-scope request and response sizes are sent successfully, or
   fail exactly as the spec's limits declare — never with an unexpected
   `RESOURCE_EXHAUSTED`.
2. Configured send/receive message-size limits (server and client) match the
   spec's mapping from the legacy quotas, read from running configuration.
3. Latency is measured for representative operations and compared with the
   recorded WCF baseline at the agreed percentiles (typically P50/P95/P99).
4. Throughput/concurrency at the agreed level is sustained without error-rate
   increase, and resource usage does not indicate a leak over the run.
5. Payload sizes are compared with the legacy SOAP/XML baseline; a
   *larger* Protobuf payload is investigated as a probable mapping defect.
6. Streaming throughput and memory behavior for large payloads are measured
   where streaming is in scope.
7. The measurement environment, load profile, and duration are recorded; a
   measurement from an environment that is not comparable is reported as
   `medium`/`low` confidence, not as a pass.

**Measurable pass criteria**

- Max-size payload cases pass = 100%.
- Latency percentiles within the SLA tolerance recorded in the decision log
  or architecture section; where no SLA exists, the gate is `blocked` with a
  finding requesting the target, not passed by assumption.
- Error rate under the agreed load ≤ the agreed threshold.

**Required evidence:** measurement command, environment description, sample
count, percentile table, baseline comparison, and configured limit values.

**Default severity:** SLA breach on a business-critical path, or an
unhandled max-payload failure → **blocking**. Within-tolerance regression or
a trend concern → **non-blocking**.

**Reference:** [hosting-and-rollout.md](../../map-wcf-to-grpc/references/hosting-and-rollout.md)
§5.3; [feature-mapping.md](../../map-wcf-to-grpc/references/feature-mapping.md)
§2.1.

---

## 11. `operational-readiness` — health, telemetry, deployment, discovery

**Question:** can operators run, observe, and route to this service in
production?

**Required checks**

1. The health service/endpoint answers liveness and readiness correctly,
   including reporting `NOT_SERVING` when a required dependency is down.
2. Structured logs are emitted with the specified fields (correlation/trace
   id, service and method name, status code, duration) and contain no
   secrets or unredacted personal data.
3. Distributed traces propagate across at least one service boundary, with
   spans for the gRPC call, and metrics for request count, error rate, and
   latency are exported as specified.
4. Alerts and dashboards named by the spec exist and reference the emitted
   metrics; an alert threshold with no underlying metric is a finding.
5. The deployment unit deploys to a non-production environment using the
   specified mechanism and configuration surface, with no manual step that
   is not documented.
6. Service discovery, load-balancing, and gateway/proxy configuration route
   HTTP/2 correctly (including any required end-to-end HTTP/2 or gRPC-aware
   proxy settings), and a rolling restart drains connections without
   dropping in-flight calls beyond the specified tolerance.
7. Configuration and certificate rotation procedures are exercisable and
   documented; nothing depends on a hardcoded value.

**Measurable pass criteria**

- Health probe cases pass = 100% including the negative (dependency-down)
  case.
- Required log fields present = 100%; secret/PII occurrences in logs = 0.
- Traces observed across a boundary = yes; required metrics exported = 100%.
- Deployment to a non-production environment succeeds using only documented
  steps.

**Required evidence:** probe responses, redacted log samples, trace/metric
samples or query results, deployment run output, and routing observations.

**Default severity:** missing/incorrect health reporting, no telemetry on a
production-bound service, a proxy that cannot carry gRPC, or an undocumented
manual deployment step → **blocking**. Missing dashboard polish or a
non-critical log field → **non-blocking**.

**Reference:** [hosting-and-rollout.md](../../map-wcf-to-grpc/references/hosting-and-rollout.md)
§§1, 5.4; [feature-mapping.md](../../map-wcf-to-grpc/references/feature-mapping.md)
§6.

---

## 12. `client-cutover` — consumers, coexistence, rollback

**Question:** can every consumer actually move, keep working during
coexistence, and be rolled back?

**Required checks**

1. Every in-scope `CON-*` consumer from the inventory has a recorded
   migration state: `migrated`, `in-progress`, `not-started`, or
   `out-of-scope with decision id` — with evidence, not assumption.
2. Migrated consumers are exercised against the gRPC endpoint end to end.
3. Not-yet-migrated consumers still work through the specified coexistence
   mechanism (side-by-side endpoints, reverse-proxy routing, SOAP adapter,
   or JSON transcoding), verified by an executed call through that path.
4. The coexistence mechanism preserves behavior for those consumers
   (contract, faults, and authorization through the adapter path).
5. Traffic evidence identifies remaining WCF callers (per-endpoint request
   counts over an agreed window); an unknown-caller population is a finding.
6. The rollback procedure is **rehearsed**, not merely described: routing is
   shifted back to WCF (or the flag flipped) in a non-production environment
   and calls succeed; the rehearsal timestamp, operator, and result are
   recorded.
7. Any temporary coexistence component has a removal owner and date.
8. External consumers outside the organization's upgrade control have a
   negotiated, recorded timeline.

**Measurable pass criteria**

- Consumers with an evidence-backed migration state = 100%.
- Coexistence paths exercised = 100% of those still in use.
- Rollback rehearsal performed and successful = yes, with a recorded date.

**Required evidence:** per-consumer state with citation, executed
coexistence-path call results, endpoint traffic data, and the rollback
rehearsal record.

**Default severity:** an unmigrated consumer with no working coexistence
path, an unrehearsed rollback, or an unknown caller population →
**blocking** for retirement (and for cutover of that consumer). A documented
consumer still within its negotiated window → **non-blocking**.

**Reference:** [hosting-and-rollout.md](../../map-wcf-to-grpc/references/hosting-and-rollout.md)
§§3–4, 6.

---

## 13. `retirement-readiness` — WCF retirement criteria

**Question:** may the legacy WCF endpoints be switched off?

This gate is assessed only on a `retirement` run and is governed by
[`retirement-gate.md`](retirement-gate.md). Summary of required checks:

1. Every retirement criterion in the roadmap's `offlineHandoffCriteria` is satisfied with
   observed, referenced evidence produced by this stage.
2. Gates 1–12 are `pass` (or `not-applicable` with proof) for **all**
   services in the retirement scope, and no blocking finding is open.
3. Consumer migration is complete or explicitly waived by a recorded
   decision, with zero unknown callers.
4. Operational readiness is proven in the production-equivalent environment.
5. Rollback remains exercisable up to and beyond the retirement date, or its
   removal is an explicit, recorded decision.
6. WCF endpoint traffic is zero for the agreed quiesce period, measured, not
   assumed.
7. A human retirement approval is recorded in the decision log — this stage
   never records it.

**Measurable pass criteria:** all of the above true, each with evidence;
otherwise the gate is `fail` or `blocked` and retirement is refused.

**Default severity:** any unmet criterion → **blocking**.

---

## Gate-to-source quick map

| Gate | Primary legacy source | Primary target source |
|---|---|---|
| `contract-parity` | inventory `SVC-*`/`OP-*`/`DC-*`/`FLD-*` | spec `contracts`, shipped `.proto`, descriptors |
| `build-and-tests` | — | work-package `AC-*`/`VAL-*` |
| `success-behavior` | Phase 0 baseline, legacy endpoint | running gRPC endpoint |
| `error-parity` | inventory fault contracts | spec `errors` section |
| `serialization-parity` | inventory serialization-sensitive fields | spec `data-types` section |
| `security-parity` | inventory bindings/behaviors/authorization | spec `security`/`authorization` sections |
| `resilience-parity` | inventory timeouts/quotas/one-way ops | spec `deadlines-retries` section |
| `streaming-parity` | inventory streaming/duplex operations | spec RPC shapes |
| `state-and-consistency` | inventory sessions/instancing/transactions | spec redesign sections |
| `performance-and-limits` | recorded baseline, binding quotas | spec SLA/limits decisions |
| `operational-readiness` | legacy hosting/monitoring | spec `observability`/`health-checks`/`deployment` |
| `client-cutover` | inventory `CON-*` | spec `coexistence`/`consumer-cutover` |
| `retirement-readiness` | all of the above | roadmap retirement `offlineHandoffCriteria` |
