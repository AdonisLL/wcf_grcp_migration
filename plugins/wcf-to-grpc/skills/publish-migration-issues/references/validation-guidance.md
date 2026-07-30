# Validation Guidance

Validate the publication artifacts and documentation in this order.

## 1. Schema validation

- Parse `examples/issue-set.example.json` as JSON.
- Validate `../../../schemas/issue-set.schema.json` with a Draft 2020-12
  validator.
- Validate the example issue set against the schema.
- Re-run validation after any change to IDs, publication states, labels,
  dependency metadata, or GitHub publication records.

## 2. Deterministic preview checks

- Confirm every approved work package in scope appears exactly once in
  `issue-set.json`.
- Confirm every issue body rendered under `issues/<issue-id>.md` matches the
  `body` stored in `issue-set.json`.
- Confirm `previewDigest` changes whenever any body, label plan, or issue order
  changes.
- Confirm a `published` issue always records a non-null GitHub repository,
  number, URL, and `publishedBodyDigest`.

## 3. Dependency and resumability checks

- Topologically sort `dependsOnWorkPackageIds` and fail on cycles.
- Confirm every `dependsOnIssueIds` value resolves to another issue entry.
- Confirm dependency placeholders exist before publication and numbered links are
  patched only after the corresponding issue numbers are known.
- Re-run with a partially published example and confirm unchanged published
  entries remain stable.

## 4. Documentation checks

- Validate the frontmatter in `SKILL.md`; use only supported keys (`name`,
  `description`).
- Resolve every local Markdown link in `SKILL.md`, `references/*.md`, and
  `templates/*.md`.
- Confirm the templates still include sections for traceability, metadata,
  dependencies, ownership/fleet suitability, acceptance, validation, rollback,
  and evidence.

## 5. Security checks

- Confirm no example or template contains credential values.
- Confirm fallback guidance refers only to existing authentication context and
  never to pasted secrets.
- Confirm failures are surfaced verbatim and do not masquerade as successful
  publication.
