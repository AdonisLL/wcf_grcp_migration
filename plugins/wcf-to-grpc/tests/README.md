# Plugin validation and smoke tests

## Automated validation

From the repository root, run:

```powershell
pwsh -NoLogo -NoProfile -File .\plugins\wcf-to-grpc\scripts\Validate-Plugin.ps1
```

On macOS or Linux with PowerShell installed:

```sh
sh ./plugins/wcf-to-grpc/scripts/validate-plugin.sh
```

The validator uses built-in PowerShell/.NET features only. It checks the
marketplace and plugin manifests, JSON syntax and schemas, schema-valid
examples and fixture expectations, frontmatter fields, local Markdown links
and anchors, component discovery, stable IDs, dependency DAGs, and static WCF
fixture coverage. It does not restore or build the legacy fixture projects.

## Local Copilot CLI installation smoke test

Authentication is required for this manual smoke test, so CI deliberately does
not run it.

1. From the repository root, register the local marketplace and install the
   plugin:

   ```powershell
   copilot plugin marketplace add .
   copilot plugin marketplace browse wcf-grpc-marketplace
   copilot plugin install wcf-to-grpc@wcf-grpc-marketplace
   copilot plugin list
   ```

2. Confirm component discovery without starting a session:

   ```powershell
   copilot plugins list --kind plugin --kind skill
   ```

   All seven plugin skills should appear.
3. Start `copilot`, run `/agent`, and confirm these eight agents are selectable:
   **WCF Migration Orchestrator**, **WCF Codebase Analyst**, **WCF Migration
   Decision Interviewer**, **WCF-to-gRPC Mapper**, **gRPC Migration Architect**,
   **gRPC Migration Issue Publisher**, **gRPC Migration Implementer**, and
   **gRPC Parity Validator**.
4. Installed plugins are cached copies; editing this working tree does not
   update an already installed copy. Exercise reinstall behavior after a local
   change:

   ```powershell
   copilot plugin marketplace update wcf-grpc-marketplace
   copilot plugin uninstall wcf-to-grpc@wcf-grpc-marketplace
   copilot plugin install wcf-to-grpc@wcf-grpc-marketplace
   copilot plugin list
   ```

   Reopen Copilot and repeat step 2 and step 3. During rapid development,
   installing the plugin directory directly with
   `copilot plugin install ./plugins/wcf-to-grpc` bypasses the marketplace
   catalog, but it does not replace the marketplace install/reinstall smoke
   test.
5. Confirm that the repository itself is directly installable:

   ```powershell
   copilot plugin uninstall wcf-to-grpc
   copilot plugin install C:\path\to\wcf_grcp_migration
   copilot plugin list
   ```

## Delegated orchestration smoke test

Run this authenticated test in a disposable copy of
`fixtures/basic-unary/` so generated migration artifacts do not modify the
checked-in fixture.

1. Select **WCF Migration Orchestrator** and provide complete Stage 0 intake.
2. Confirm the orchestrator invokes **WCF Codebase Analyst** itself; it must not
   ask you to switch agents or paste an inventory envelope.
3. Confirm interview questions appear in the orchestrator conversation one at a
   time and answers persist to `decision-log.json`.
4. Confirm mapping runs through **WCF-to-gRPC Mapper** and writes a
   schema-valid `mapping-result.json`.
5. Interrupt and resume the session. The orchestrator must re-read state and
   artifacts without repeating completed inventory, answered decisions, or
   mapping work.
6. Confirm specification approval remains a human gate and issue publication
   defaults to preview-only. No GitHub mutation may occur without an exact
   digest confirmation and explicit mutation permission.
7. For an approved test specification, confirm each implementation invocation
   receives exactly one `WP-*` id, conflicting/shared packages remain
   sequential, and completion is derived from reports on disk.
8. Temporarily make a delegated agent unavailable and confirm the orchestrator
   records the failure and emits a copyable manual recovery handoff rather than
   claiming completion.

## Fixture repositories

- [`fixtures/basic-unary/`](fixtures/basic-unary/) covers a basicHttp unary
  service and typed client with common DataContract values.
- [`fixtures/faults-and-serialization/`](fixtures/faults-and-serialization/)
  covers typed faults, SOAP message security, nullable/default values,
  decimal/date/enum behavior, and KnownType inheritance.
- [`fixtures/duplex-high-risk/`](fixtures/duplex-high-risk/) covers duplex
  callbacks, one-way calls, required sessions, per-session state, transaction
  flow, reliable sessions, and streamed payloads.

Each `expected.json` records inventory facts, evidence, risks, questions,
mandatory gRPC for .NET mapping expectations, explicit redesign risks, and
an acyclic work-package specification.
