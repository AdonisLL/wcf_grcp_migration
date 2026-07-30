# GitHub Publication Guidance

## Tool order

1. Prefer GitHub read/search tools available in the environment for repository
   inspection and duplicate detection.
2. Use GitHub issue search/read/list before any mutation attempt.
3. If a first-class GitHub write tool is unavailable, use an already-authenticated
   GitHub CLI session only after explicit confirmation and only as fallback.

This repository currently documents the following preferred read/search actions:

- search issues by stable `WP-*` and `ISSUE-*` markers;
- list issues by labels or recent update time;
- read matching issues to verify stable markers and previously published body
  digests.

## Stable duplicate markers

Every rendered body should contain machine-checkable stable markers, for
example:

```text
Stable issue ID: ISSUE-order-service-server
Work package ID: WP-order-service-server
Migration spec ID: MSPEC-contoso-orders
Issue set ID: ISET-contoso-orders
```

A hidden HTML comment marker is also recommended so reruns can patch bodies
idempotently without rewriting unrelated text.

## Safe GitHub CLI fallback

Use fallback CLI mutation only when all of the following are true:

1. The current preview digest was explicitly confirmed.
2. Existing GitHub read/search tools were used for preflight.
3. No approved GitHub mutation tool is available in the environment.
4. `gh auth status` already succeeds for the target repository.

Never ask the user to paste a token. Never write auth material to disk.

### Fallback sequence

1. `gh auth status`
2. label existence check / optional label creation
3. `gh issue create` for each issue in dependency order
4. body patch or `gh issue edit`/`gh api` follow-up once dependency issue
   numbers are known

If any CLI step fails, capture the stderr/output verbatim, persist prior
successes, and stop.

## Resumability rules

- Persist issue numbers and URLs immediately after each successful create.
- Persist dependency-link patch digests immediately after each successful patch.
- Reuse previously recorded issue numbers only when the repository issue still
  exists and still advertises the same stable markers.
- If an expected issue is missing or its markers disagree, block and report the
  mismatch instead of creating a replacement automatically.

## Error handling

Never convert these failures into success-shaped summaries:

- missing auth;
- insufficient scopes or repository permissions;
- secondary rate limits;
- duplicate conflicts;
- digest mismatch between preview and requested publication;
- inability to patch dependency links after issue creation.

When one of these occurs, return the exact failed issue/label IDs plus the next
safe action.
