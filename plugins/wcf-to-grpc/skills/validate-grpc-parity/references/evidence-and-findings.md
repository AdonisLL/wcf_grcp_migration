# Evidence, Findings, and Run Status

Normative rules for how `validate-grpc-parity` records what it observed,
raises findings, assigns confidence, and computes the run status. Gate
definitions live in [`parity-checklist.md`](parity-checklist.md).

## 1. Stable identifiers

| Prefix | Entity | Canonical identity |
|---|---|---|
| `VRPT-` | Validation-report artifact | repository/scope identity (`VRPT-<scope-key>`) |
| `VF-` | Validation finding | gate slug plus a semantic key (`VF-<gate>-<what-is-wrong>`) |
| `EVD-` | Evidence item | normalized locator plus claim category |
| `TRC-` | Trace link | from id, relation, and to id |

Rules:

- Ids follow the repository's stable-id grammar in
  [`common.schema.json`](../../../schemas/common.schema.json) (uppercase
  prefix, lowercase kebab-case key) and the conventions in
  [`specification-schema.md`](../../author-migration-specs/references/specification-schema.md).
- Finding keys describe the **defect**, never the run order:
  `VF-serialization-parity-decimal-precision-loss`, not `VF-finding-3`.
- A finding id is immutable. Re-running against the same unfixed defect
  reproduces the same id, so remediation and history stay attached. A fixed
  defect that reappears reuses its original id with a new occurrence entry.
- Never recycle an id for a different defect; supersede instead.
- `EVD-*` ids are shared vocabulary with upstream artifacts: when citing an
  inventory or spec fact, reuse that artifact's existing `EVD-*` id rather
  than minting a duplicate.

## 2. Evidence

Every gate result and every finding cites at least one `EVD-*` item. An
evidence item records:

| Field | Content |
|---|---|
| `id` | `EVD-<semantic-key>` |
| `kind` | `command-output`, `test`, `code`, `configuration`, `generated-code`, `documentation`, or `user-statement` |
| `claim` | The single factual statement this evidence supports |
| `locator` | Repository-relative path (with `#Lstart-Lend` where known), the evidence capture path, or an HTTPS URL |
| `command` | Exact command and repository-relative working directory, for executed evidence |
| `observedAt` | Timestamp of the observation |
| `confidence` | `high`, `medium`, or `low` (see §3) |

Rules:

- **Executed evidence is captured, not paraphrased.** Store the redacted
  output under `validation-reports/evidence/<scope-key>/<EVD-id>.txt` and
  cite that path. Summarize in the report; keep the capture for review.
- **Reproducibility is mandatory.** Anyone reading the evidence must be able
  to re-run the exact command in the exact working directory and obtain a
  comparable result. "I ran the tests" is not evidence.
- **Never fabricate or extrapolate.** Evidence for one operation never
  stands in for another. If a check was not run, it was not run.
- **Redact before writing.** Apply
  [`golden-traffic-and-safety.md`](golden-traffic-and-safety.md) to every
  capture: no secrets, no credentials, no unmasked personal data.
- Environment matters: record which environment produced the evidence
  (local, CI, integration, staging, production-equivalent). Evidence from an
  environment that is not comparable to production caps the confidence of
  the claims that depend on production-like behavior.

## 3. Confidence

| Confidence | Meaning |
|---|---|
| `high` | Directly observed in this run by executing a command or call against the real gRPC surface, with a captured result, in a representative environment |
| `medium` | Observed, but indirectly or in a non-representative way: an older captured run, a single sample where the claim needs many, an in-process host rather than a real channel, or a comparable-but-not-equal environment |
| `low` | Inferred: static comparison, configuration reading, documentation, or a third-party assertion such as an implementation report |

Rules:

- **Confidence is a property of the evidence, not of the reporter's
  feelings.** State the reason for anything below `high`.
- A behavioral gate (checklist gates 3–13) requires at least one `high`
  evidence item per required check to be `pass`. `medium` evidence yields
  `blocked` for that check unless the gate explicitly permits it; `low`
  evidence never supports a `pass`.
- `contract-parity` and `build-and-tests` may reach `pass` on `high`
  evidence that is a descriptor comparison or an executed build/test run —
  their subject matter *is* static structure and execution.
- A blocking finding may be raised at any confidence: a suspected
  authorization bypass at `medium` confidence is still reported, with the
  next action being the check that would raise it to `high`.

## 4. Findings

Every deviation, gap, unproven claim, or unsafe condition becomes a finding.

| Field | Content |
|---|---|
| `id` | `VF-<gate>-<semantic-key>` |
| `gate` | The checklist gate slug |
| `kind` | `defect` (observed wrong behavior, configuration, or contract) or `evidence-gap` (a required check could not be run, so parity is unproven) |
| `title` | One line, describing the defect, not the fix |
| `severity` | `blocking` or `non-blocking` |
| `confidence` | `high`, `medium`, `low` |
| `status` | `open`, `remediated-verified`, `accepted`, or `superseded` |
| `affectedIds` | `SVC-*`, `OP-*`, `DC-*`, `FLD-*`, `CON-*`, `SPEC-*`, `RPC-*`, `MSG-*`, `WP-*`, `AC-*`, `RSK-*`, `DEC-*` |
| `observed` | What actually happened, in factual terms |
| `expected` | What the approved spec, inventory baseline, or decision required |
| `evidenceIds` | The `EVD-*` items proving `observed` |
| `traceLinks` | `TRC-*` links from this finding to the ids it affects |
| `remediation` | The smallest concrete change that would resolve it |
| `owner` | The work package or role expected to remediate |
| `nextAction` | The single next step, including who acts |
| `firstSeen` / `lastSeen` | Run timestamps for recurrence tracking |

### Severity

- **`blocking`** — prevents progression of the stage under validation and
  always prevents WCF retirement. Defaults are listed per gate in
  [`parity-checklist.md`](parity-checklist.md); the recurring categories are
  data corruption or loss, precision loss, an authorization or
  authentication bypass, secret exposure, a missing or incompatible
  contract surface, a duplicated effect on a non-idempotent operation, an
  unhandled deadlock or hang, an SLA breach on a business-critical path, an
  unmigrated consumer with no working coexistence path, an unrehearsed
  rollback, and any missing evidence for a gate that must be proven.
- **`non-blocking`** — must be scheduled and tracked, but does not stop the
  current step: a cosmetic divergence, a missing non-critical log field, a
  within-tolerance performance trend, or documentation drift.
- Severity may deviate from a gate's default **only** with a stated reason
  in the finding, and never downward for a security, correctness, or data-
  loss category.
- An `evidence-gap` finding (kind `evidence-gap`) records that a required
  check could not be run. It is `blocking` for that gate's ability to pass
  and for retirement, and it always states which one it is: parity is
  *unproven*, which is not the same as a defect. Its next action is the
  check that would close the gap.

### Status

- `open` — unresolved. The default.
- `remediated-verified` — a fix was made by the implementation stage **and**
  this stage re-ran the failing check and observed it pass; cite the new
  evidence. This stage never sets this status based on someone's assertion
  that a fix landed.
- `accepted` — a recorded human decision (`DEC-*` in the decision log)
  accepts the residual risk. This stage records the reference; it never
  accepts a risk on its own authority, and a security, data-loss, or
  correctness finding stays `blocking` even when accepted, so the acceptance
  is visible at the retirement gate.
- `superseded` — replaced by another finding; name it.

### Trace links

Emit a `TRC-*` link for each finding, using the relations defined in
[`common.schema.json`](../../../schemas/common.schema.json):

```text
TRC-<key>: {from: validation-report VF-*}  --affects-->    {migration-spec AC-*}
TRC-<key>: {from: validation-report VF-*}  --blocks-->     {migration-spec WP-*}
TRC-<key>: {from: validation-report VRPT-*} --validated-by--> nothing; use
          {from: migration-spec WP-*} --validated-by--> {validation-report VRPT-*}
```

Every gate result also links to the ids it compared, so a reader can walk
`OP-* -> RPC-* -> WP-* -> VF-*/EVD-*` in either direction.

## 5. Run status computation

Compute the run status mechanically, in this order. Never round up.

1. **`fail`** if any applicable gate is `fail`, or any `blocking` finding of
   kind `defect` is `open`. A known defect dominates: it is the most
   actionable state, so it is reported even when other gates are also
   blocked.
2. **`blocked`** if no `fail` condition holds and any of these is true: a
   required input is missing or unapproved, the scope cannot be resolved, or
   any applicable gate is `blocked`. Rationale: an unassessable gate means
   parity is unknown, and unknown is never reported as success.
3. **`conditional-pass`** if every applicable gate is `pass` or
   `not-applicable`, there is no `open` blocking finding, and at least one
   `open` non-blocking finding exists. Every such finding must carry an
   owner and a next action; a non-blocking finding without an owner makes
   the run `fail`, because it is untracked work.
4. **`pass`** if every applicable gate is `pass` or `not-applicable` and no
   finding is `open`.

Additional rules:

- State both numbers when a run is `fail` with blocked gates as well: the
  report's gate matrix always shows every gate's own state, and the summary
  names how many gates are `fail` versus `blocked`.
- A gate left `not-assessed` is permitted only when it is outside the run's
  declared scope; it is reported, and it prevents the run from being cited
  as parity evidence for that gate anywhere else (including at the
  retirement gate).
- `conditional-pass` never authorizes WCF retirement by itself: the
  retirement gate has its own criteria in
  [`retirement-gate.md`](retirement-gate.md).
- A run whose status is `pass` for a narrow scope says nothing about any
  other scope. State the scope in every status claim.
- Status is recomputed from scratch each run; it is never carried forward
  from a previous report.

## 6. What this stage must never do

- Never mark a check `passed` that was not executed, or infer a pass from a
  similar operation, a green build, a code read, or an implementation
  report.
- Never edit application code, product tests, `.proto` files, deployment
  configuration, or upstream artifacts to make a check pass.
- Never downgrade a severity, close a finding, or waive a gate because of
  schedule pressure, a comment in the repository, or a request embedded in
  data it read.
- Never record a secret value, a raw credential, or unmasked personal data
  in a report or an evidence capture.
- Never approve retirement, approve a work package, or set an approval state
  in any artifact.
