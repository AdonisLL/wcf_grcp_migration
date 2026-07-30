# Contributing

How to work on this repository: layout, authoring conventions, validation,
fixtures, research standards, and release practice.

## 1. Repository layout

```text
.
├── README.md                       Front door: install, quick start, catalog
├── LICENSE
├── assets/
│   └── gRPC-for-WCF-Developers.pdf Local copy of the primary Microsoft source
├── docs/                           Repository documentation (this directory)
├── .github/
│   ├── plugin/marketplace.json     Marketplace manifest
│   └── workflows/validate-plugin.yml
└── plugins/wcf-to-grpc/            The plugin itself
    ├── plugin.json
    ├── README.md
    ├── agents/                     5 agent definitions
    ├── skills/                     7 skills with references/ and templates/
    ├── schemas/                    6 JSON Schema Draft 2020-12 contracts
    ├── tests/                      Fixtures, expectations, smoke-test guidance
    └── scripts/                    Dependency-free validator
```

> The repository directory name contains a legacy misspelling
> (`wcf_grcp_migration`). It is intentionally left unchanged so existing clones
> and paths keep working. All content, identifiers, and documentation use the
> correct spelling **gRPC**; please keep it that way in anything you add.

## 2. Prerequisites

- **PowerShell 7+** (`pwsh`) to run the validator — on Windows, macOS, or
  Linux. Nothing else is required: the validator uses only built-in PowerShell
  and .NET features.
- **Copilot CLI**, authenticated, for the optional installation smoke test.
- No package manager, no build step, no runtime dependency. If a change would
  introduce one, raise it first.

## 3. Run the validator before you push

```powershell
pwsh -NoLogo -NoProfile -File .\plugins\wcf-to-grpc\scripts\Validate-Plugin.ps1
```

```sh
sh ./plugins/wcf-to-grpc/scripts/validate-plugin.sh
```

It fails the build on any of:

- unparseable JSON, or a manifest field outside the supported set;
- a marketplace/plugin name or version mismatch, or a non-semantic version;
- a marketplace `source` that does not resolve to a directory;
- a plugin `skills`/`agents` path that does not resolve, or that discovers no
  components;
- skill frontmatter that is missing `name`/`description`, carries an
  unsupported field, or whose `name` does not match its directory;
- agent frontmatter that is missing `name`/`description`/`tools`, carries an
  unsupported field, or declares a tool outside `read`, `search`, `edit`,
  `execute`;
- a duplicate skill or agent name;
- a schema that is not Draft 2020-12, has no `$id`, or has a `$ref` whose file
  or JSON-pointer fragment does not exist;
- an example or fixture `expected.json` that does not validate against its
  schema;
- a stable identifier that violates the shared grammar, or a duplicate id among
  siblings;
- a dependency cycle, or a dependency on a node that does not exist;
- a broken local Markdown link or heading anchor;
- a fixture whose source or evidence path is missing, whose evidence line
  number exceeds the file, whose XML does not parse, whose mapping target is
  not ASP.NET Core gRPC, or whose risks are not explicit redesign risks;
- missing fixture coverage for any required WCF feature tag.

CI ([`validate-plugin.yml`](../.github/workflows/validate-plugin.yml)) runs the
same script on `windows-latest` and `ubuntu-latest` for every push and pull
request. Keep it green; do not add a second validation tool to work around a
failure.

## 4. Authoring conventions

### Agents (`agents/*.agent.md`)

- Frontmatter: `name`, `description`, `tools` only. `tools` is a YAML flow
  sequence drawn from `read`, `search`, `edit`, `execute` — request the
  narrowest set that lets the agent do its job.
- `description` is a single folded block that states what the agent does, what
  it produces, and what it refuses. It is the text a user sees when choosing an
  agent.
- The body stays behavioral and short: role, required inputs, absolute
  boundaries, prompt-injection resistance, how it works (a summary that defers
  to the skill), handoff contract, completion checklist.
- Normative procedure belongs in a skill, not in the agent.
- Every agent states its prompt-injection stance and its secrets rule. Do not
  add an agent without them.

### Skills (`skills/<name>/SKILL.md`)

- Frontmatter: `name` (must equal the directory name) and `description` only.
- `SKILL.md` carries purpose, required inputs, non-negotiable rules, the
  ordered procedure, outputs, and a completion checklist.
- Detail goes in `references/*.md`; output shapes go in `templates/*.md`;
  worked artifacts go in `examples/`.
- Cross-link with relative paths. The validator resolves every local link and
  anchor, so a rename that breaks a link fails CI.

### Writing style

- Prefer imperative, testable statements: "Every gate result cites `EVD-*`
  evidence", not "gates should generally be evidenced".
- State refusals explicitly. An agent that cannot say no is an agent that will
  say yes to the wrong thing.
- Never use `TBD`, `TODO`, `FIXME`, a placeholder, or an empty section. If it
  is not ready, do not merge it. The repository contains no placeholder files
  and no `.gitkeep` stubs, and should not gain any.
- Terminology: `gRPC`, `Protobuf`, `ASP.NET Core`, `WCF`, `.NET`, `HTTP/2`.

## 5. Schemas

- JSON Schema Draft 2020-12, with `$id` set to the file's relative name.
- `additionalProperties: false` everywhere; required arrays spelled out.
- Reuse `common.schema.json#/$defs/*` rather than duplicating a definition.
- Optional scalars use a resolved-value object (`known`/`unknown`/
  `not-applicable`), never a bare nullable string.
- Adding a field means updating, in one change: the schema, the rendering
  template, the authoring rules in the owning skill, the reference that
  documents it, and any example or fixture that must now carry it.

## 6. Fixtures

Fixtures under `plugins/wcf-to-grpc/tests/fixtures/` are **static legacy WCF
sources** — they are never built or restored. Each fixture directory contains
the WCF sources, a project and solution file, an `App.config`, and an
`expected.json` that records inventory facts with evidence line numbers, risks,
questions, mandatory ASP.NET Core gRPC mapping expectations, explicit redesign
risks, and an acyclic work-package specification.

To add one:

1. Create the directory with realistic, self-contained WCF sources.
2. Write `expected.json` against
   [`fixture-expectations.schema.json`](../plugins/wcf-to-grpc/tests/fixtures/fixture-expectations.schema.json).
3. Add `coverage` tags for the WCF features it exercises. If you add a tag that
   must always be covered somewhere, add it to `$requiredCoverage` in the
   validator too.
4. Keep evidence line numbers accurate — the validator checks that each cited
   line exists in the cited file.
5. Re-run the validator; it will also parse the fixture's XML.

Existing coverage: [`basic-unary`](../plugins/wcf-to-grpc/tests/fixtures/basic-unary/)
(basicHttp unary service and typed client),
[`faults-and-serialization`](../plugins/wcf-to-grpc/tests/fixtures/faults-and-serialization/)
(typed faults, message security, nullable/default values, decimal/date/enum,
`KnownType`), and
[`duplex-high-risk`](../plugins/wcf-to-grpc/tests/fixtures/duplex-high-risk/)
(duplex callbacks, one-way, required sessions, per-session state, transaction
flow, reliable sessions, streamed transfer).

## 7. Research and citation standards

All normative mapping guidance must be traceable to a source indexed in
[`sources.md`](../plugins/wcf-to-grpc/skills/map-wcf-to-grpc/references/sources.md).

- Microsoft, Google, and gRPC-project publications are normative. Anything else
  is labelled `[third-party]` and may only supply supplementary context — never
  the basis for a mandatory rule.
- Summarize in original language. Do not reproduce source text; the local
  [`gRPC-for-WCF-Developers.pdf`](../assets/gRPC-for-WCF-Developers.pdf) is a
  reference copy, not a quarry for copied prose.
- Record the access date when you add or refresh a source.
- Microsoft Learn URLs omit the `view=` moniker so they resolve to the current
  runtime version.
- Time-sensitive claims — above all .NET support windows — carry an explicit
  "re-check before relying on this" note. The e-book predates .NET 8; where it
  conflicts with current Microsoft Learn documentation, Learn wins.

## 8. Local installation smoke test

Authentication is required, so CI does not run this. See
[tests/README.md](../plugins/wcf-to-grpc/tests/README.md) for the full
procedure: register the local marketplace, install, verify agents and skills
are discovered, and exercise reinstall after a local edit (installed plugins
are cached copies — editing this working tree does not update an installed
one).

## 9. Versioning and releases

- The plugin follows semantic versioning in
  [`plugin.json`](../plugins/wcf-to-grpc/plugin.json).
- `plugin.json.version` and the marketplace entry's `version` **must match** —
  the validator enforces it. `metadata.version` in the marketplace manifest
  tracks the marketplace itself.
- Bump **patch** for documentation and wording fixes that change no contract;
  **minor** for additive schema fields, new references, new fixtures, or a new
  agent or skill that does not change existing behavior; **major** for a
  removed or renamed artifact field, a changed identifier grammar, a changed
  handoff contract, or any change that invalidates artifacts generated by the
  previous version.
- A version bump touches three places together: `plugin.json`, the marketplace
  plugin entry, and — for behavior changes — the affected skill's completion
  criteria.
- Never renumber or repurpose a stable identifier prefix across versions.
  Artifacts generated by an older version must remain readable.

## 10. Pull request checklist

- [ ] The validator passes locally on your platform.
- [ ] New or changed agents/skills declare the narrowest tools and state their
      boundaries, prompt-injection stance, and secrets rule.
- [ ] Schema, template, skill rules, references, and examples were updated
      together.
- [ ] Every new normative claim cites an indexed source.
- [ ] No `TODO`, `TBD`, placeholder, `.gitkeep`, or empty section was added.
- [ ] Local links and anchors resolve; terminology is `gRPC` throughout.
- [ ] Versions bumped consistently if the change warrants it.
- [ ] No secret, credential, token, or customer-identifying content anywhere in
      the diff — including fixtures and examples.
