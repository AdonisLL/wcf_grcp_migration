# Inventory Schema Use Reference

This reference explains how to populate the `inventory` artifact so it validates
against the checked-in JSON Schema Draft 2020-12 contracts:

- [`inventory.schema.json`](../../../schemas/inventory.schema.json) — the
  inventory contract.
- [`common.schema.json`](../../../schemas/common.schema.json) — shared
  definitions (stable IDs, resolved values, citations, trace links).

The schema is the normative contract. When this prose and the schema disagree,
the schema wins. All relative paths in artifacts use `/`, are
repository-relative, and must not contain drive letters, leading slashes, or
`..` traversal.

## Shared envelope

Every inventory carries the `artifactBase` envelope from `common.schema.json`:

| Field | Meaning |
|---|---|
| `schemaVersion` | `"1.0.0"`. |
| `artifactType` | `"inventory"`. |
| `artifactId` | `INV-<repository-identity>`. |
| `generation` | Generator name/version, UTC `generatedAt`, `sourceRevision` (resolved value), `sourceDigest` (`sha256:...`), and `mode` (`full`/`incremental`). |
| `approval` | Explicit state: `draft`, `review-requested`, `approved`, `rejected`, or `superseded`. Analysis output normally starts `draft`. |
| `citations` | Deduplicated `EVD-*` evidence records used across the inventory. |
| `traceLinks` | Directed `TRC-*` links between stable IDs. |

Inventory-specific top-level fields: `analysisState`, `scope`, `repository`,
`services`, `dataContracts`, `endpoints`, `consumers`,
`externalDependencies`, `risks`, and `unknowns`. All are required; arrays may
be empty during incremental discovery.

## Resolved values: known / unknown / not-applicable

Optional scalars use one of the `common.schema.json` resolved-value objects.
Never substitute `""`, `0`, or `null` for an unknown unless the field's schema
explicitly allows `null` (only `consumer.projectId` and `unknown.decisionId`
do).

```json
{ "state": "known", "value": ".NET Framework 4.8" }
```

```json
{
  "state": "unknown",
  "reason": "Target framework is set by an imported Directory.Build.props not in scope.",
  "questionIds": ["QST-order-service-tfm"]
}
```

```json
{ "state": "not-applicable", "reason": "Client-only repository hosts no services." }
```

- `resolvedString` — text values such as `targetFramework`, `namespace`,
  `address`, `binding`, `securityMode`, `timeout`, `authorization`,
  `entryPoint`, `availability`.
- `resolvedBoolean` — `serverMigration`, `clientOnlyRepository`, `isAsync`,
  `usesSession`, `flowsTransaction`, `requiresOrderedDelivery`, `nullable`,
  `required`, `emitDefaultValue`, `generatedClient`.
- `resolvedNonNegativeInteger` — `field.order`.

Carry the `questionIds` that would resolve each `unknown`, and create a
matching `QST-*` entry in `unknowns`.

## Facts, derived conclusions, and unknowns

- **Fact:** directly supported by cited code/config. Attach `EVD-*` with a
  precise locator and appropriate `confidence`.
- **Derived conclusion:** an inference over facts (for example, "duplex because
  the contract declares `CallbackContract`"). It is still backed by the facts'
  evidence; keep confidence honest (often `medium`).
- **Unknown:** a genuine gap. Emit a `QST-*` in `unknowns` and reference it
  from the relevant resolved value's `questionIds`. Never guess.

## Stable identifiers

IDs use an uppercase prefix and a lowercase kebab-case semantic key derived
from a canonical identity, never display text or discovery order. Prefixes are
enforced by `common.schema.json#/$defs/stableId` and per-field patterns.

| Prefix | Entity | Canonical identity example |
|---|---|---|
| `INV-` | Inventory artifact | repository identity |
| `REPO-`, `SOL-`, `PRJ-`, `HOST-` | Repository topology | normalized repository-relative path |
| `SVC-` | Service | project path + fully qualified contract symbol |
| `OP-` | Operation | service ID + method signature |
| `DC-`, `FLD-` | Data contract and field | declaring type/member symbol |
| `END-`, `CON-`, `DEP-` | Endpoint, consumer, dependency | owning ID + normalized address/name |
| `EVD-` | Evidence | normalized locator + claim category |
| `RSK-`, `QST-` | Risk and question | affected IDs + semantic topic |
| `TRC-` | Trace link | from ID, relation, and to ID |

On collision, append the first 8 lowercase hex characters of a SHA-256 digest
of the canonical identity. IDs are immutable once emitted: when extending a
prior inventory, reuse existing IDs across moves and renames; never recycle an
ID from a removed entity (mark it or its links `superseded`/`obsolete`).
Downstream `DEC-*`, `SPEC-*`, `WP-*`, `ISSUE-*`, and `VAL-*` artifacts attach
to these IDs, so preserving them preserves traceability.

## Citations (`EVD-*`)

Each citation records `id`, `kind`, `claim`, `locator`, `confidence`, and
optional `symbol`/`excerptDigest`/`observedAt`.

- `kind`: `code`, `configuration`, `project`, `package`, `generated-code`,
  `test`, `command-output`, `documentation`, or `user-statement`.
- `locator`: repository-relative path with an optional `#Lstart-Lend` suffix,
  an `http(s)://` URL, or `user-statement:<label>`.
- `confidence`: `high`, `medium`, or `low`.

```json
{
  "id": "EVD-order-service-contract",
  "kind": "code",
  "claim": "IOrderService is annotated [ServiceContract].",
  "locator": "src/Orders/IOrderService.cs#L10-L14",
  "symbol": "Acme.Orders.IOrderService",
  "confidence": "high"
}
```

Cite the smallest useful span. Never inline secrets — reference the location
and redact the value. Every discovered service, operation, contract, field,
endpoint, consumer, and dependency requires at least one `EVD-*`.

## Analysis states

- Inventory root `analysisState` and each `service.analysisState` are
  `discovered`, `partial`, or `complete`.
- `complete` means the declared scope for that item was traced through
  configuration and call sites — **not** that runtime parity was proved.
- Do not raise an item to `complete` on attribute-only evidence.

## Risks and unknowns

`risk` (`RSK-*`): `title`, `category` (`contract`, `serialization`,
`security`, `hosting`, `consumer`, `transaction`, `session`, `streaming`,
`reliability`, `operations`, `unknown`), `severity`
(`low`/`medium`/`high`/`critical`), `status` (`identified`,
`decision-required`, `mitigated`, `accepted`, `closed`), `statement`,
`affectedIds`, `questionIds`, `decisionIds`, and `evidenceIds` (at least one).

Flag every unsupported/high-risk WCF feature as a risk and link the questions
it raises. Use `decision-required` when a user choice is needed; leave
`decisionIds` empty until the decision stage creates the `DEC-*`.

`unknown` (`QST-*`): `prompt`, `whyNeeded`, `status` (`open`/`answered`/
`obsolete`), `blocking`, `affectedIds`, `decisionId` (or `null`), and
`evidenceIds`. Never answer a question here; the interview/decision stage does.

## Trace links (`TRC-*`)

Build the forward chain so downstream stages attach without renumbering:

```text
inventory item -> risk/question -> (decision -> spec -> work package -> issue -> implementation -> validation)
```

At the inventory stage you normally emit the first hops: `raises`
(item → risk/question) and, where an item evidences another, `evidences`. Use
the relation enum in `common.schema.json`; represent a missing downstream
artifact with an unresolved or omitted link, never a fabricated ID.

## Client-only repositories

A client-only repository still produces a full inventory:

- `scope.serverMigration` resolves to `false` with evidence; `services` may be
  empty and `repository.hosting` may be empty.
- `consumers` (generated proxies, `ChannelFactory`), the endpoints/bindings
  they target, and external dependencies become the primary content.
- Consumed contracts discovered only through generated proxies are recorded as
  `dataContract.kind: generated-proxy-type` / `consumer.kind: generated-proxy`
  with appropriate confidence.

## Determinism and validation

- Treat the JSON as the source of truth. Canonicalize paths to `/`; never emit
  machine-specific absolute paths or drive letters.
- Sort object keys; sort ID-based collections lexicographically.
- Use UTF-8, LF line endings, one trailing newline, two-space indentation.
- Preserve prior IDs, evidence, risks, questions, and trace links when
  regenerating; do not renumber because discovery order changed.
- Before handing off, parse the JSON and validate it against
  [`inventory.schema.json`](../../../schemas/inventory.schema.json) with an
  available Draft 2020-12 validator. Fix every violation before reporting the
  inventory ready.
