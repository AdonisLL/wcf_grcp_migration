# Migration review: {{artifactId}}

**Semantic digest:** `{{semanticDigest}}`
**Digest algorithm:** `{{digestAlgorithmVersion}}`
**Approval state:** `{{approval.state}}`

The current approval state applies only to the decision, specification, and
work-package IDs listed in **Approval scope**. It never grants GitHub mutation,
protected traffic, production access, production cutover, WCF retirement, or
any other action under **Out-of-scope actions**.

## Recommended decisions

{{#each decisionReviews}}
### {{decisionId}} — {{interactionClass}}

**Recommendation:** {{recommendation}}

**Confidence:** {{confidence}}

**Rationale:** {{rationale}}

**Assumptions**

{{#each assumptions}}
- {{this}}
{{/each}}

**Alternatives**

{{#each alternatives}}
- {{this}}
{{/each}}

**Consequences**

{{#each consequences}}
- {{this}}
{{/each}}
{{/each}}

## Architecture

{{architectureSummary.summary}}

## Contracts

{{contractSummary.summary}}

## Roadmap and work packages

{{roadmapSummary.summary}}

## Digest-bound review artifacts

Approval binds the exact artifacts below. Review each linked artifact before
confirming the semantic digest.

| Kind | Artifact | Content digest | Bound IDs |
|---|---|---|---|
{{#each renderedArtifacts}}
| {{kind}} | [{{title}}]({{path}}) | `{{contentDigest}}` | {{boundIds}} |
{{/each}}

## Immediate blockers

{{#each blockingDecisionIds}}
- {{this}}
{{/each}}

## Offline handoff items and deferred prerequisites

Items in this section are not in the approval scope and do not block the
consolidated review. Each carries a `gate` value:

- `implementation` — must be resolved before or during implementation so the
  implementer can write correct code (e.g., deadline thresholds, load-test SLOs).
- `final-local-checkpoint` — must be resolved before `WP-integration-verification`
  can complete its evidence report.
- `offline-handoff` — resolved exclusively through a human authority process
  after the code is complete (e.g., environment-progression approvals, cutover
  gates, retirement authorization).

{{#each offlineHandoffItems}}
- {{decisionId}} — gate `{{gate}}`: {{nextAction}}
{{/each}}

## Out-of-scope actions

The following actions are outside the authority of this review and must not be
performed as a result of approving this bundle:

{{#each outOfScopeActions}}
- {{this}}
{{/each}}

## Approval scope

- Decisions: {{approvalScope.decisionIds}}
- Migration specification: the `migration-spec` entry in `sourceArtifacts`
- Work packages: {{approvalScope.workPackageIds}}
- Excluded actions: {{approvalScope.excludedActions}}
