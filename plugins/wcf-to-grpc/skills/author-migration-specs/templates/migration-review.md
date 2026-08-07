# Migration review: {{artifactId}}

**Semantic digest:** `{{semanticDigest}}`

This review approves only the decision, specification, and work-package IDs
listed in **Approval scope**. It does not grant GitHub mutation, protected
traffic, production access, cutover, rollback execution, or WCF retirement.

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

## Draft architecture

{{architectureSummary.summary}}

## Draft contracts

{{contractSummary.summary}}

## Roadmap and work packages

{{roadmapSummary.summary}}

## Immediate blockers

{{#each blockingDecisionIds}}
- {{this}}
{{/each}}

## Deferred operational gates

{{#each deferredOperationalItems}}
- {{decisionId}} — resolve before {{gate}}: {{nextAction}}
{{/each}}

## Excluded authority gates

{{#each excludedAuthorityGates}}
- {{this}}
{{/each}}

## Approval scope

- Decisions: {{approvalScope.decisionIds}}
- Migration specification: the `migration-spec` entry in `sourceArtifacts`
- Work packages: {{approvalScope.workPackageIds}}
- Excluded actions: {{approvalScope.excludedActions}}
