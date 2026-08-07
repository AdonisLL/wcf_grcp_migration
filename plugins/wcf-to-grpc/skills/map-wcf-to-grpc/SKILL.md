---
name: map-wcf-to-grpc
description: >
  Translates an evidence-backed WCF inventory and recorded migration decisions
  into deterministic gRPC/Protobuf mapping guidance with risk flags. The
  target is always gRPC for .NET; constructs with no safe direct gRPC
  equivalent are flagged as redesign risks and routed to an explicit
  architectural decision instead of being silently replaced by REST, CoreWCF,
  or a messaging system.
---

# Skill: Map WCF to gRPC

## Purpose

This skill turns the outputs of `inventory-wcf-codebase` (the evidence-backed
inventory of WCF constructs) and `interview-migration-decisions` (the
recorded architectural decisions) into a complete mapping from every
discovered WCF construct to its gRPC/Protobuf equivalent. Its output feeds
directly into `author-migration-specs`, which authors the assessment,
architecture, and work-package documents.

Expected input: the `inventory` object produced by `inventory-wcf-codebase`
and the `decisions` object produced by `interview-migration-decisions`.

Expected output: `docs/wcf-grpc-migration/mapping-result.json` (or the
configured output path), valid against
[`../../schemas/mapping-result.schema.json`](../../schemas/mapping-result.schema.json).
It covers, per construct, the applicable `feature`, Protobuf `type`, `security`,
and `error`/`streaming` mappings, plus unsupported features that require an
architectural decision before specification authoring can proceed.

## Mandatory product rule

The target platform is **gRPC for .NET**. When a WCF feature has no
safe direct gRPC equivalent, this skill must:

1. Flag the construct as `UNSUPPORTED` with a risk level (`HIGH` or `MEDIUM`).
2. Document the gRPC-centered redesign required (for example, replacing
   duplex callbacks with bidirectional streaming, or replacing distributed
   transactions with saga/outbox patterns).
3. Record an architectural decision reference. A safe proposal may drive the
   draft mapping; an unresolved immediate blocker keeps only its affected
   surface incomplete.
4. **Never** emit a mapping that targets REST, CoreWCF, MSMQ, or any
   non-gRPC replacement. A high-risk supporting component requires an explicit
   approved decision before implementation, even when its proposed design is
   shown in a draft.

## Workflow

1. Load the inventory and decisions into context.
2. For each service and operation contract, apply `references/feature-mapping.md`.
3. For each data/message contract field, apply `references/protobuf-type-mapping.md`.
4. For each binding and endpoint security configuration, apply `references/security-mapping.md`.
5. For each fault contract, streaming shape, session, and transaction, apply
   `references/error-and-streaming-mapping.md`.
6. For hosting topology, coexistence, and rollout constraints, apply
   `references/hosting-and-rollout.md`.
7. Assemble the structured mapping result and populate `unsupportedFeatures`
   for every `HIGH`-risk or `UNSUPPORTED` construct.
   Proposed decisions are valid draft inputs. An unresolved
   `immediate-answer-required` decision blocks the affected entry and is
   reported without suppressing independent mappings.
8. Validate and persist the deterministic mapping artifact. Preserve stable ids
   and generation metadata when the semantic inputs are unchanged.
9. Return its path, digest, coverage, blockers, and next required action to the
   caller for specification authoring.

## Reference index

| File | Covers |
|------|--------|
| `references/feature-mapping.md` | Service/operation contracts, message contracts, bindings, behaviors, instance/concurrency modes, extensibility points, observability |
| `references/protobuf-type-mapping.md` | Scalar types, nullability, dates/times, `decimal`, GUIDs, enums, collections, inheritance/polymorphism, field numbering |
| `references/security-mapping.md` | WCF security modes, credential types, TLS/mTLS, WS-* standards, authorization, secret management |
| `references/error-and-streaming-mapping.md` | Fault contracts, gRPC status codes, streaming shapes, duplex callbacks, sessions, reliable messaging, transactions |
| `references/hosting-and-rollout.md` | Hosting topology, runtime selection, coexistence strategies, rollout phases, parity validation, rollback |
| `references/sources.md` | Cited sources with URLs, publishers, and access date |
