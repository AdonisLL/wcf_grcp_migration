# Validation and Gates

Normative rules for how this agent runs validation during implementation.
Validation-step *authoring* rules (what a `VAL-*` step must contain) are
defined by `author-migration-specs`'s
[`work-package-patterns.md`](../../author-migration-specs/references/work-package-patterns.md#validation-steps);
this reference is the *implementer's* side — how to execute what was
authored, without broadening or weakening it.

## 1. Narrow validation per package

- Run **only** the `validation` (`VAL-*`) entries defined on the work
  package(s) you were assigned. Do not run the repository's full build or
  test suite unless a step's own `command` is exactly that.
- Use the step's exact `command` and repository-relative `workingDirectory`
  when given. Do not substitute a broader or narrower command you think is
  "close enough."
- When a step's `kind` is `manual`, perform precisely the inspection it
  describes and record precisely the observed result against its stated
  success condition — do not silently convert a manual step into an
  automated one you invent, and do not skip it.
- If a step's command fails because a referenced project, script, or tool
  does not exist, that is a spec/deliverable defect (the command was not
  knowable when authored) — report it; do not invent a replacement command
  to force a pass.
- Update the step's recorded `status` only to a value you actually observed:
  `passed` only after a real, successful run; `failed` with the real error;
  `blocked` when a prerequisite prevented running it at all. Never write
  `passed` speculatively or by extrapolation from a similar package.
- A validation run's evidence (command output, test report path, log
  excerpt) belongs in the handoff report per
  [`handoff-report-contract.md`](handoff-report-contract.md); never fabricate
  evidence that was not actually produced by the run.

## 2. Acceptance criteria require real evidence

Each `AC-*` on your package states `evidenceRequired` and links `validationIds`.
Before reporting an acceptance criterion as met:

1. Confirm every linked `VAL-*` actually ran and its recorded result supports
   the criterion.
2. Confirm the `evidenceRequired` artifact was actually produced (a specific
   test name and its pass/fail, a descriptor diff, a log/metric sample, or a
   review record) — not merely "the code was written."
3. If evidence is missing or ambiguous, report the criterion as **not met**
   with the reason. A criterion with no evidence is not silently assumed
   true because the corresponding code exists.

## 3. Integration-checkpoint validation

At a checkpoint (see
[`fleet-execution-and-ownership.md`](fleet-execution-and-ownership.md#5-integration-checkpoints)),
run the reconciliation build/tests the checkpoint requires, using the
narrowest command that covers the packages merged at that checkpoint (for
example the affected solution/project build plus the test projects the
merged packages own) — not the entire repository unless that is genuinely
the narrowest available command.

## 4. Static analysis and code review are never parity proof

Neither this agent's own review of its diff, nor a successful narrow build
or unit-test run, constitutes runtime parity evidence between WCF and gRPC
behavior. This agent may and should verify its own package's contract shape,
unit behavior, and the acceptance criteria it was given — but it must never
claim, imply, or record in a handoff report that its package's validation
constitutes independent parity evidence. That evidence is produced only by
the parity-validation stage
([`validate-grpc-parity`](../../validate-grpc-parity/SKILL.md)).

## 5. Final sequential integration checkpoint

After all `VAL-*` steps complete, every package run by this skill must
execute a **final sequential integration checkpoint** before the handoff
report is written:

1. Build every project the package created or modified (or, if an affected
   solution exists, build that solution). Use the narrowest existing
   repository command (for example `dotnet build <project>.csproj` or
   `dotnet build <solution>.sln`). Do not introduce a new build tool.
2. Run all existing repository-local tests that exercise the changed code
   (for example `dotnet test <test-project>.csproj`). Do not introduce a
   new test framework.
3. Record the exact command, working directory, and full result (pass/fail,
   test count) in the handoff report.
4. State explicitly: *"This checkpoint confirms the code compiles and
   existing tests pass. It does not constitute runtime parity evidence,
   WCF behavior equivalence, or deployment readiness."*

If the build or tests fail, the handoff status is `partial` or `blocked`;
do not report `completed`.
