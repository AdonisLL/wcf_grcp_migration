# WCF-to-gRPC migration status

**Run:** `{{runId}}`  
**Updated:** `{{updatedAt}}`  
**Overall state:** `{{overallState}}`  
**WCF state:** `{{wcfState}}`

## Next action

**Owner:** {{nextRequiredAction.owner}}

{{nextRequiredAction.action}}

## Stage progress

| Stage | State | Current artifact or evidence | Blocking item |
|---|---|---|---|
{{#each stages}}
| {{stage}} | {{state}} | {{artifactOrEvidence}} | {{blockingItemOrNone}} |
{{/each}}

## Blocking items

| Severity | Owner | Blocker | Smallest next action |
|---|---|---|---|
{{#each blockingItems}}
| {{severity}} | {{owner}} | {{summary}} | {{nextAction}} |
{{/each}}

## Risk summary

| Risk | Level | Affected services or packages | Decision / mitigation |
|---|---|---|---|
{{#each riskSummary}}
| {{id}} | {{level}} | {{scope}} | {{decisionOrMitigation}} |
{{/each}}

## Changed since the last review

{{#each changesSinceReview}}
- {{this}}
{{/each}}

## Review drill-down

- Consolidated review: `migration-review.md`
- Target architecture: `target-architecture.md`
- Roadmap: `roadmap.md`
- Contract specifications: `contracts/`
- Work packages: `work-packages/`
- Implementation reports: `implementation-reports/`

This dashboard is a rendering of `orchestration-state.json`; the JSON artifact
is authoritative. It never authorizes deployment, cutover, rollback, protected
traffic access, or WCF retirement.
