---
report_id: {{VRPT_id}}
scope_key: {{scope_key}}
run_status: {{pass_conditional_pass_fail_blocked}}
generated_at: {{generated_at_utc}}
---

# Parity Checklist — {{scope_key}}

Per-check record for the run reported in `{{validation_report_path}}`.
Definitions, measurable pass criteria, and default severities are normative
in
[`../references/parity-checklist.md`](../references/parity-checklist.md).

Fill every row. Allowed check states: `pass`, `fail`, `blocked`,
`not-applicable`, `not-assessed`. Every state other than `pass` needs a
reason and, where it is a defect or an evidence gap, a `VF-*` finding.
Confidence is `high`, `medium`, or `low`; behavioral gates (3–13) require
`high` runtime evidence to pass.

## 1. `contract-parity` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Every in-scope `OP-*` maps to one `RPC-*` present in the shipped `.proto` with the specified shape | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Every in-scope `DC-*`/`FLD-*` maps to a `MSG-*` field of the specified type, or is a recorded intentional drop | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | No undeclared `rpc`, message, or field exists beyond the spec | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Field numbers match the spec; none renumbered, reused, or shifted | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Removed fields/enum values have `reserved` numbers **and** names | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Enum zero values, `oneof`s, presence markers, package/namespace, api version match the spec | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | Descriptor backward-compatibility check reports 0 breaking changes | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 8 | Generated code builds from the shipped `.proto` with the specified codegen wiring | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 2. `build-and-tests` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Narrowest scope-covering build succeeds | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Every in-scope `VAL-*` ran with its exact command/working directory | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Unit tests run; pass/fail/skip counts recorded | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Integration tests over a real channel run and are identified as such | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Every in-scope `AC-*` independently confirmed met/not met | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Flaky/skipped tests covering in-scope behavior enumerated | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 3. `success-behavior` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Every in-scope operation invoked over a real channel and compared field by field with the baseline | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Business-rule outcomes match baseline or a recorded tolerance | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Side effects match; no extra or missing effect | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Empty, boundary, and max-size inputs exercised | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Idempotent reads return identical results on repeat | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Operations that could not be exercised listed with reasons | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 4. `error-parity` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Every in-scope fault mode triggered; status code matches the spec mapping | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Rich error details present and decodable where specified | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Unhandled exceptions map to the specified status and leak nothing | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Validation/not-found/conflict/throttling/authz/authn cases map as specified | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Generated client round-trips the detail contract | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Mid-stream failure terminates the call with the specified status | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 5. `serialization-parity` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | `decimal` round-trips with no precision/scale loss at min, max, and negative magnitudes | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Null/absent is distinguishable from default per the presence strategy | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | `DateTime`/`DateTimeOffset`/`TimeSpan` round-trip with specified UTC/offset/kind handling | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | GUID representation round-trips without corruption or case defects | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Enum values mapped; zero value correct; unknown values behave as specified | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Polymorphic/`KnownType` payloads round-trip; unmapped derived types rejected as specified | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | Collections/dictionaries: empty vs. absent, map keys, ordering as specified | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 8 | Byte arrays and max-size payloads round-trip byte-identically | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 9 | XML-specific/MTOM constructs covered by the specified replacement | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 6. `security-parity` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Unauthenticated call to a protected method → `UNAUTHENTICATED`, no side effect | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Authenticated-but-unauthorized → `PERMISSION_DENIED`, per legacy denial set | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Authorized principals succeed per method policy and overrides | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Expired/malformed/wrong-audience/wrong-issuer/bad-signature credentials all rejected | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | TLS required with specified versions; no unapproved plaintext exposure | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | mTLS negative cases rejected; certificate identity mapped as specified | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | Windows/message/WS-* replacement exercised; residual gap stated | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 8 | No secret material in repository, configuration, or observed logs | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 7. `resilience-parity` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Deadline exceeded → `DEADLINE_EXCEEDED` with the specified value | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Server-side cancellation observed to stop work | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Deadlines propagate across hops where required | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Retry/hedging policy matches spec; non-retryable codes not retried | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Forced retry produces exactly one effect on idempotent operations | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Non-idempotent operations excluded from retry or protected by the idempotency-key mechanism (duplicate submission tested) | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | One-way operation replacement behaves per spec | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 8. `streaming-parity` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Unary calls complete with expected trailers/status | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Server streaming: ordering, completion, early cancellation, no deadlock | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Client streaming: full consumption, correct aggregate, mid-stream failure status | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Bidirectional: concurrency, per-direction ordering, half-close, keep-alive | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Duplex-callback replacement exercised end to end incl. reconnect and delivery semantics | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Large/chunked payload streaming within limits and memory expectations | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | Stream failure/retry semantics match the spec's restrictions | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 9. `state-and-consistency` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | External session/instance state store exercised: read/write across calls, expiry, isolation, restart behavior | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Declared-stateless services leak no state between calls | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Concurrent calls produce the specified outcome without corruption or deadlock | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Transaction replacement converges under a forced mid-sequence failure | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Reliable-delivery replacement handles duplicates, reordering, consumer restart | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Legacy ordering guarantees preserved or explicitly relaxed by decision | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 10. `performance-and-limits` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Max in-scope request/response sizes succeed or fail exactly as specified | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Configured send/receive limits match the spec, read from running config | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Latency percentiles measured and compared with the WCF baseline | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Throughput/concurrency sustained without error-rate or leak regression | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Payload sizes compared with the SOAP/XML baseline; growth investigated | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Streaming throughput/memory measured where streaming is in scope | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | Environment, load profile, duration, and sample count recorded | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 11. `operational-readiness` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Health service answers liveness/readiness incl. dependency-down case | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Structured logs carry specified fields and no secrets/unmasked PII | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Traces propagate across a boundary; required metrics exported | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Specified alerts/dashboards exist and reference emitted metrics | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Deployment to a non-production environment succeeds with documented steps only | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Discovery/load balancing/proxy carry HTTP/2 correctly; rolling restart drains | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | Configuration and certificate rotation exercisable and documented | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 12. `client-cutover` — gate state: {{state}}

| # | Check | State | Evidence | Confidence | Finding |
|---|---|---|---|---|---|
| 1 | Every in-scope `CON-*` has an evidence-backed migration state | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 2 | Migrated consumers exercised end to end against gRPC | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 3 | Unmigrated consumers work through the coexistence path (executed) | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 4 | Coexistence path preserves contract, faults, and authorization | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 5 | Endpoint traffic data identifies remaining WCF callers; no unknown callers | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 6 | Rollback rehearsed with recorded date, operator, environment, result | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 7 | Temporary coexistence components have removal owner and date | {{state}} | {{EVD}} | {{conf}} | {{VF}} |
| 8 | External consumers have a negotiated, recorded timeline | {{state}} | {{EVD}} | {{conf}} | {{VF}} |

## 13. `retirement-readiness` — gate state: {{state_or_not_assessed}}

Assessed only on a `retirement` run; conditions are normative in
[`../references/retirement-gate.md`](../references/retirement-gate.md) and
recorded in `{{retirement_readiness_path}}`.

| # | Condition group | State | Evidence | Finding |
|---|---|---|---|---|
| 1 | Roadmap retirement `offlineHandoffCriteria` satisfied with observed evidence | {{state}} | {{EVD}} | {{VF}} |
| 2 | Gates 1–12 `pass`/`not-applicable` across the whole retirement scope | {{state}} | {{EVD}} | {{VF}} |
| 3 | Consumers complete or waived; zero unknown callers | {{state}} | {{EVD}} | {{VF}} |
| 4 | Operational readiness proven in a production-equivalent environment | {{state}} | {{EVD}} | {{VF}} |
| 5 | Rollback rehearsed and still available | {{state}} | {{EVD}} | {{VF}} |
| 6 | WCF traffic at/below the quiesce threshold for the agreed window | {{state}} | {{EVD}} | {{VF}} |
| 7 | Human retirement approval recorded in the decision log | {{state}} | {{EVD}} | {{VF}} |

## Sign-off

- Gates with any non-`pass` state: {{list_or_none}}
- Blocking findings open: {{list_or_none}}
- Computed run status: {{run_status}}
- This checklist was produced by executed checks; no row was marked `pass`
  from static analysis, a passing build, or an implementation report's
  claim: {{confirmation}}
