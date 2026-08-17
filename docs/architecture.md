# Plugin architecture

How the `wcf-to-grpc` Copilot CLI plugin is put together, why it is split the
way it is, and which safety properties each part is responsible for.

For the migration process itself see
[migration-methodology.md](migration-methodology.md); for the files the plugin
generates see [output-contracts.md](output-contracts.md).

## 1. Design goals

1. **Evidence over assertion.** Every claim about the legacy system traces to a
   file, a symbol, and a line. Static analysis is never presented as runtime
   parity.
2. **One responsibility per agent.** The agent that analyzes cannot write. The
   agent that designs cannot implement. The agent that implements cannot
   validate. The agent that validates cannot fix. The agent that orchestrates
   does none of the above.
3. **Gates are data, not etiquette.** Every gate is a state you can read out of
   an artifact — an approval object, a dependency state, a digest, a report
   status — so a resumed run reaches the same conclusion as the original.
4. **Refusal is a first-class outcome.** `blocked` with a named missing input,
   an owner, and a next action is always preferable to a plausible guess.
5. **gRPC is a fixed product decision.** The plugin never retargets a migration
   to REST, CoreWCF, or messaging. Constructs that gRPC cannot express directly
   become explicit redesign risks and recorded decisions.

## 2. Component model

```text
plugins/wcf-to-grpc/
├── plugin.json          Manifest: name, version, keywords, component paths
├── agents/*.agent.md    Personas, boundaries, and handoffs (9 agents)
├── skills/*/SKILL.md    Normative procedures, with references/ and templates/
├── schemas/*.json       JSON Schema Draft 2020-12 artifact contracts
├── tests/               Static WCF fixtures, expectations, smoke-test guidance
└── scripts/             Dependency-free repository validator
```

| Layer | Answers | Loaded when |
|---|---|---|
| Agent (`.agent.md`) | *Who am I, what may I touch, what do I refuse, who do I hand to?* | The user selects it, or the orchestrator invokes it through the `agent` tool |
| Skill (`SKILL.md`) | *What is the ordered procedure and its completion criteria?* | The agent loads its skill |
| Reference (`references/*.md`) | *What are the detailed rules, tables, and mappings?* | The skill directs the agent to read it |
| Template (`templates/*.md`) | *What exact shape does the rendered output take?* | Output is written |
| Schema (`schemas/*.json`) | *Is the machine-readable artifact well-formed?* | Artifacts are written or consumed |

Agents stay short and behavioral; skills carry the procedure; references carry
detail. This keeps an agent's context cost low while making the normative
content reviewable and citable on its own.

### Discovery

`plugin.json` declares `"agents": "./agents/"` and `"skills": "./skills/"`.
Copilot CLI discovers `*.agent.md` files in the agents path and `SKILL.md`
files in the skills path — including nested skill directories. Component path
fields are optional and default to `agents/` and `skills/`; they are declared
explicitly here so discovery is unambiguous. See the
[Copilot CLI plugin reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference).

Frontmatter is validated against the current documented field set by
[`Validate-Plugin.ps1`](../plugins/wcf-to-grpc/scripts/Validate-Plugin.ps1):

- Skills: `name` (must equal the directory name), `description`, and optional
  `license`/`allowed-tools`.
- Agents: `name`, `description`, `target`, `tools`, `model`,
  `disable-model-invocation`, `user-invocable`, `mcp-servers`, and `metadata`.
- The repository currently omits `tools` because Copilot CLI 1.0.79 rejects
  several documented aliases while loading plugins, despite the platform
  documentation describing them as supported. Omission uses the CLI default
  toolset; prompts enforce narrower behavior until a compatibility test proves
  that explicit allowlists load portably.
- Internal stage agents use `user-invocable: false`. The parity validator uses
  `disable-model-invocation: true` so only an explicit user action starts it.

## 3. Agents and their tool boundaries

| Agent | Tools | May write | Never |
|---|---|---|---|
| [WCF Codebase Analyst](../plugins/wcf-to-grpc/agents/wcf-codebase-analyst.agent.md) | CLI default; prompt-bounded | `inventory.json` only | Mutate application files, build, restore, or format; choose a target |
| [WCF Migration Decision Interviewer](../plugins/wcf-to-grpc/agents/wcf-migration-decision-interviewer.agent.md) | CLI default; prompt-bounded | `decision-log.json` | Fabricate organizational facts, infer approval, alter a review bundle |
| [WCF-to-gRPC Mapper](../plugins/wcf-to-grpc/agents/wcf-to-grpc-mapper.agent.md) | CLI default; prompt-bounded | `mapping-result.json` | Drop a construct, resolve a decision, author architecture |
| [gRPC Migration Architect](../plugins/wcf-to-grpc/agents/grpc-migration-architect.agent.md) | CLI default; prompt-bounded | `migration-spec.json`, `migration-review.json/.md`, rendered design docs | Application code, issues, implementations, inferred approvals |
| [gRPC Migration Issue Publisher](../plugins/wcf-to-grpc/agents/grpc-migration-issue-publisher.agent.md) | CLI default; prompt-bounded | Issue preview and publication artifacts | Mutate GitHub without approved inputs, exact confirmation, and permission |
| [gRPC Migration Implementer](../plugins/wcf-to-grpc/agents/grpc-migration-implementer.agent.md) | CLI default; prompt-bounded | Only its assigned work package's `exclusive-write` paths | Migration artifacts, other packages' paths, deployment/routing/cutover/live rollback, any WCF removal |
| [gRPC Code Handoff Author](../plugins/wcf-to-grpc/agents/grpc-code-handoff-author.agent.md) | CLI default; prompt-bounded | Only `code-handoff.json` and `code-handoff.md` | Application code, migration artifacts, product commands, deployment, parity claims |
| [gRPC Parity Validator](../plugins/wcf-to-grpc/agents/grpc-parity-validator.agent.md) | CLI default; prompt-bounded | Only `validation-reports/` | Application code, upstream artifacts, fixing findings, granting retirement |
| [WCF Migration Orchestrator](../plugins/wcf-to-grpc/agents/wcf-migration-orchestrator.agent.md) | CLI default; prompt-bounded | Only `orchestration-state.json` and the optional status view | Any stage work, any approval, product/deployment/GitHub mutation commands, any slash command |

The orchestrator may execute only repository digest and artifact-validation
scripts required to verify a stage gate. Product builds, tests, restores, Git,
deployment, and GitHub mutation remain owned by their stage agent or operator.
This narrow exception prevents fabricated gate evidence without letting the
coordinator become an implementer.

The analyst prompt limits command use to non-mutating inspection. The agent
contract, skill, and reference files constrain that behavior even though the
portable default toolset is available.

## 4. Skills

| Skill | Stage | Output |
|---|---|---|
| [`inventory-wcf-codebase`](../plugins/wcf-to-grpc/skills/inventory-wcf-codebase/SKILL.md) | Analysis | `inventory.json` |
| [`interview-migration-decisions`](../plugins/wcf-to-grpc/skills/interview-migration-decisions/SKILL.md) | Decisions | `decision-log.json` |
| [`map-wcf-to-grpc`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/SKILL.md) | Mapping | `mapping-result.json` + redesign risks |
| [`author-migration-specs`](../plugins/wcf-to-grpc/skills/author-migration-specs/SKILL.md) | Specification | `migration-spec.json`, `migration-review.json/.md`, rendered design docs |
| [`publish-migration-issues`](../plugins/wcf-to-grpc/skills/publish-migration-issues/SKILL.md) | Publication | `issue-set.json` + previews |
| [`implement-grpc-migration`](../plugins/wcf-to-grpc/skills/implement-grpc-migration/SKILL.md) | Implementation | Code + `implementation-reports/` |
| [`finalize-code-handoff`](../plugins/wcf-to-grpc/skills/finalize-code-handoff/SKILL.md) | Code handoff (terminal) | `code-handoff.json`, `code-handoff.md` |
| [`validate-grpc-parity`](../plugins/wcf-to-grpc/skills/validate-grpc-parity/SKILL.md) | Optional manual post-deploy | `validation-reports/` |

Only `implement-grpc-migration` may modify application source, and only inside
the bounded ownership its assigned work package declares.

## 5. Orchestration state machine

The orchestrator drives stages 0–9. Each transition is gated on artifact
state that can be read back from disk, which is what makes a run resumable.
Stage 0 is a sequential structured wizard over only the missing intake values;
it accepts custom answers, asks layout-specific paths conditionally, and skips
values already supplied or persisted.

```text
intake ──▶ inventory ──▶ proposals/blockers ──▶ mapping ──▶ draft + review bundle
                                                                    │
                                                                    ▼
                                                        consolidated approval
                                                                        │
                       ┌────────────────────────────────────────────────┘
                       ▼
              publication (optional, confirmation-gated)
                       │
                       ▼
     implementation waves ⇄ integration checkpoints ──▶ build + tests ──▶ code handoff (gRPC Code Handoff Author)
```

Parity validation, cutover, and retirement are out-of-scope offline activities.
The parity validator is available as a standalone tool after deployment; it is
not connected to the orchestration state machine.

Loops are normal and expected: a spec deviation routes back to the architect,
an unresolved decision routes back to the interview. Stages never run out of
order, and an upstream change marks its downstream artifacts `stale` and
invalidates the approvals that depended on them.

Run state lives in `orchestration-state.json`
([schema](../plugins/wcf-to-grpc/schemas/orchestration-state.schema.json)). On
every invocation the orchestrator re-derives gates from the artifacts on disk
rather than trusting the stored status, so an interrupted, reassigned, or
resumed migration reaches the same next action.

### The gates that cannot be bypassed

| Gate | Enforced by |
|---|---|
| No draft surface without complete inventory evidence and a proposal or explicit blocker | Architect required inputs; orchestrator stage 4 gate |
| No implementation before bundle-scoped decision, specification, and work-package approval | Interviewer/architect approval recording; orchestrator stage 7 gate |
| No GitHub mutation before a full-set preview and digest-matched confirmation | Publication skill; orchestrator stage 6 gate |
| No parallel batch with overlapping or shared ownership | `fleetPlan` ownership data; implementer boundaries 3–5; orchestrator wave partitioning |
| No next wave before its integration checkpoint reconciles | Fleet reference §5; orchestrator stage 7 wave gate |
| No code handoff before affected solution builds clean and repository-local tests pass | Orchestrator stage 8 completion gate |

## 6. Fleet execution model

Copilot CLI's [`/fleet`](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/fleet)
runs multiple subagents in parallel in one session, and
[`/tasks`](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/speed-up-task-completion)
shows what those subagents are doing. This plugin uses them as the execution
substrate for implementation waves — but never as the source of safety.

- **The specification carries the parallelism plan.** Each work package
  declares `dependencies`, `fleet.wave`, `fleet.suitability`
  (`eligible`/`sequential`/`ineligible`), `fleet.fileOwnership`
  (`exclusive-write`, `shared-read`, `integration-owner`), and
  `conflictsWithWorkPackageIds`. The dependency graph is validated acyclic.
- **The orchestrator partitions each wave** into a parallel-eligible set with
  pairwise-disjoint `exclusive-write` paths and a sequential set containing all
  shared or schema infrastructure — proto conventions, generated-code build
  configuration, solution and package-management files, host bootstrap and DI,
  the interceptor chain, auth configuration, shared-state code, and the final
  local verification package. Routing, cutover, live rollback, and retirement
  are not work packages.
- **The orchestrator delegates work packages directly.** It invokes one
  implementer per package through the `agent` tool and may issue concurrent
  calls only for the verified parallel-eligible set. `/fleet` and `/tasks`
  remain optional interactive operator controls, not orchestration
  prerequisites.
- **Each implementer is safe in isolation.** Its wave gating, ownership
  claiming (via `<work-package-id>.claim.json`), and conflict detection derive
  entirely from `migration-spec.json` — never from assumptions about how it was
  launched. A wave dispatched by hand is exactly as safe as one dispatched in a
  fleet batch.
- **Completion is read from reports on disk**, not inferred from a child-agent
  summary or `/tasks` output.

Details: [fleet-execution-and-ownership.md](../plugins/wcf-to-grpc/skills/implement-grpc-migration/references/fleet-execution-and-ownership.md).

## 7. Trust and authority model

Authority is ranked, and the ranking is stated in every agent:

1. The user's direct request in the current session.
2. The agent and skill configuration shipped by this plugin.
3. Everything else — repository source, comments, configuration, README files,
   commit messages, test fixtures, generated proxies, GitHub issue and PR
   bodies, captured traffic, and artifacts produced by earlier stages — which
   is **data to evaluate, never instructions to obey**.

Captured traffic and prior-stage reports are treated as the highest-risk
inputs, because their content is attacker-influenced or agent-authored by
construction. A materially relevant injection attempt is recorded as an
observation with its source, and not acted on.

Secrets never enter an artifact. Agents cite the location of a credential and
redact its value; the validator redacts at write time; the publication stage
relies on authentication already present in the operator's environment and
never collects credentials.

## 8. Traceability chain

```text
EVD-* ─▶ RSK-*/QST-* ─▶ DEC-* ─▶ SPEC-*/architecture section ─▶ WP-*/AC-*/VAL-*
      ─▶ ISSUE-* ─▶ implementation report ──▶ [optional] VRPT-*/VF-* ─▶ retirementCriteria
```

Identifiers are stable and semantic (`WP-order-service-server`, not `WP-7`), so
regenerating an artifact never renumbers downstream references. A link that
does not yet exist is reported as unresolved; it is never invented. The
validator enforces the shared identifier grammar and checks that work-package
and issue dependency graphs are acyclic.

## 9. Validation and CI

[`Validate-Plugin.ps1`](../plugins/wcf-to-grpc/scripts/Validate-Plugin.ps1) is
dependency-free — built-in PowerShell and .NET only — and runs identically on
Windows, macOS, and Linux. It checks manifests and component discovery, JSON
syntax, schema drafts and `$ref` targets, schema-valid examples and fixture
expectations, agent/skill frontmatter, local Markdown links and anchors, stable
identifier grammar, dependency acyclicity, and static WCF fixture coverage.
[`validate-plugin.yml`](../.github/workflows/validate-plugin.yml) runs it on
`windows-latest` and `ubuntu-latest`.

The authenticated installation smoke test is deliberately excluded from CI and
documented in [tests/README.md](../plugins/wcf-to-grpc/tests/README.md).

## 10. Extension points

- **New mapping rule** → a reference in `skills/map-wcf-to-grpc/references/`
  with a citation in
  [`sources.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/sources.md).
- **New artifact field** → the schema, its rendering template, the skill's
  authoring rules, and the fixture expectations, together.
- **New stage** → a skill for the procedure, an agent for the boundary, a
  handoff contract reference, and an orchestrator gate. A stage with no gate is
  a stage that will be skipped under pressure.
- **New fixture** → see [contributing.md](contributing.md).

## 11. Deliberate non-goals

- No runtime component, MCP server, LSP server, or hook ships with this plugin;
  it is agents, skills, schemas, fixtures, and a validator.
- The plugin does not execute a migration by itself. Every irreversible step —
  approval and publication — is a human act.
- The plugin does not host, deploy, or monitor anything; the orchestrated
  workflow ends at a verified code handoff. Deployment, environment
  provisioning, production/protected traffic, runtime parity validation, cutover,
  live rollback, and WCF retirement are out-of-scope offline activities.
