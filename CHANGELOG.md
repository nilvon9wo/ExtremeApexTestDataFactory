# Changelog

All notable changes to XFTY are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); XFTY aims to follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Predicate combinators** — `XFTY_Predicates.allOf(list)` / `anyOf(list)` /
  `negate(one)` build AND / OR / NOT trees of `XFTY_SObjectPredicateIntf` for a
  flavoured lookup key, beyond the implicit AND of repeated `.matching(...)`.

### Changed

- **Predicate internals split out.** `XFTY_FieldPredicate` and `XFTY_Predicates`
  are now thin facades over one small, directly-usable class per condition:
  `XFTY_FieldEqualToPredicate`, `XFTY_FieldGreaterThanPredicate`,
  `XFTY_FieldLessThanPredicate`, `XFTY_FieldInSetPredicate` (sharing
  `XFTY_ValueComparison`), and `XFTY_AllOfPredicate` / `XFTY_AnyOfPredicate` /
  `XFTY_NegationPredicate`. No inner classes, no operator enum, no `switch`;
  `notEqualTo` / `isNotNull` are a negated `equalTo`. Facade method names are
  unchanged (`equalTo` / `greaterThan` / `inSet` / …).
- **Explicit variant vs. override template are now reconciled.** Supplying both
  `withVariant(key)` (or a relationship's explicit key) *and* an override
  template that independently matches a *different* refined variant now throws
  `XFTY_ProviderLookups.LookupException` instead of silently letting the explicit
  key win. A template with no discriminator is unaffected.

## [4.0.0-beta.1] – 2026-09-01

The first public beta of XFTY 4.0. Feature-complete on the `4.0-beta` branch;
APIs may still shift before 4.0 final. See
[docs/reference/migration.md](docs/reference/migration.md) for the upgrade path
from 3.5.

### Added

- **Context-aware values** — a field derived from another record in the graph:
  `XFTY_CopyFromSiblingExpression`, `XFTY_CopyFromAncestorExpression` (single- or
  multi-hop), a custom `XFTY_ContextAwareExpressionIntf`, and `context.siblingValue(field)`
  (a guarded sibling read that throws on a mis-ordered `put` instead of returning
  a misleading `null`).
- **Descendant (up-flowing) value reads** — `XFTY_CopyFromDescendantExpression`
  copies a value up from a generated child, resolved during the `DEFERRED` flush.
- **Shared ancestors** — `XFTY_SharedAncestor`: many children under one generated
  parent, flat or deep (auto-detected), nested, with cycle and depth guards.
  `put` / `putAsTemplate` / `putAsValue` / `putIfAbsent` / `getId`, per-record
  shaping via `XFTY_SharedAncestorProvider`, packaged defaults via
  `XFTY_SharedAncestorDefaultsIntf`, and `disable` / `manualResolutionOnly` /
  `resolveNow` for controlling what gets built.
- **Downward generation** — `with(...)` / `withChildren(...)` / `withChild(...)`
  and `XFTY_SObjectChildProvider` generate the records *below* a primary, nested
  to any depth, `DEFERRED`-aware.
- **Per-call relationship control** — `includeOptional(field)`,
  `includeOptional(path)`, and `excludeRelationship(field)` override inclusivity
  for one call, on the Provider instance.
- **Path-scoped value overrides** — `put(List<SObjectField>, …)` sets how a field
  on a generated ancestor is produced, for one call, without editing that
  ancestor's Provider.
- **Deferred & depth-batched insert** — the `DEFERRED` insert mode plus
  `XFTY_DeferredInserter.flush()` generate across many calls and insert once;
  `.depthBatched()` collapses a `NOW` call to one `insert` per dependency depth.
- **Multi-variant Providers** — record-type and "flavour" lookup keys
  (`XFTY_RecordTypeLookupKey`, `XFTY_FlavouredLookupKey`, `XFTY_FieldPredicate`),
  `withVariant(key)`, and a lookup-key constructor.
- **Governor-limit warnings** — `XFTY_GovernorBudget` writes a `WARN` to the
  debug log when generation alone crosses half of any per-transaction limit;
  tunable through the `XFTY_Settings__c` hierarchy custom setting.
- **Implicit literal values** — `put(field, 'literal')` wraps the value in
  `XFTY_LiteralExpression` for you.
- **Split test suites** — `XFTY_Unit`, `XFTY_Integration`, `XFTY_Load`,
  `XFTY_Examples`, `XFTY_OrgOnly`, and `XFTY_PersonAccount`.
- **`scripts/verify-doc-examples.py`** — CI job that fails the build if a
  documented `apex` example is not backed, line for line, by a runnable test.

### Changed

- **Source format.** XFTY is now a Salesforce DX source-format project
  (`force-app/main/default/classes/<area>/`), with a second, non-default
  `test-support/` package directory for examples and org-only tests.
- **Relationship strategy classes merged.**
  `XFTY_DummyDefaultRelationshipRequired` and `…Optional` are now the single
  `XFTY_DummyDefaultRelationship`; requiredness comes from `putRequired` /
  `putOptional`. Untyped `put(field, <relationship>)` now throws.
- **Provider Lookups replace the global registry.** Every
  `XFTY_DummySObjectProvider` takes a lookup as its second constructor argument.
  `XFTY_DummySObjectProviderLookupIntf` gained `get(XFTY_LookupKeyIntf)` and
  `keysFor(SObject)`. Build one with `XFTY_ProviderLookups.of(map)` or by copying
  `XFTY_DefaultSObjectProviderLookup`.
- **`createBundle` takes an `XFTY_GenerationContext`** instead of three scalar
  arguments. Every custom Provider must update the signature (a one-line change).
- **Value strategies renamed to value expressions** — the `DummyDefault` prefix
  is gone, an `Expression` suffix is added (e.g. `XFTY_DummyDefaultValueIntf` →
  `XFTY_ValueExpressionIntf`, `XFTY_DummyDefaultValueExact` →
  `XFTY_LiteralExpression`). Full table in the migration guide. Behaviour is
  unchanged.
- **`profileIdFor` / `roleIdFor` throw** `UnknownReferenceException` on a miss
  instead of returning `null`.
- **`XFTY_DefaultSObjectProviderLookup.get()` throws** on an unknown `SObjectType`
  instead of swallowing the error.
- Provider-level `put(...)` and `removeFromMasterTemplate(...)`, previously silent
  no-ops, now take effect.

### Removed

- `XFTY_InsertMocker` — was a byte-for-byte duplicate of `XFTY_IdMocker`.
- `IndeterminateSObjectTypeException` and its guards — proven unreachable.
- `XFTY_DummySObjectFactory.cloneAndCompleteNonRelationshipValues` (public
  wrapper) — the logic moved to `XFTY_PlainValueFiller`.

### Fixed

- `XFTY_DummySObjectMasterTemplate` was shallow-cloned between calls.
- `XFTY_RecordTypeDataProvider` re-queried record types on every miss.
- A mismatched override-template list silently retargeted the Provider to a
  different `SObjectType`; it now throws.
- `ALL` inclusivity plus a self-referential relationship recursed until the stack
  overflowed; the ancestor-cycle guard now throws a clear error, and
  `.allowAncestorCycles()` opts out for a chain that terminates on its own.
- A mis-ordered context-aware sibling read returned a silent `null`.
- Real-org compile issues surfaced during beta verification: `@IsTest` on an
  interface, over-length identifiers, a static-initialiser ordering dependency,
  and a field/enum name collision in `XFTY_PathValue`.

### Coverage

- 100% line coverage, verified on a scratch org (the framework ships as
  `@IsTest`, so Salesforce reports 0% until the annotation is stripped for
  measurement). Every one of the ~424 tests passes; zero classes carry an
  uncovered line.

## [3.5.0] – prior to 4.0 development

Baseline. Single-argument Providers, a global Provider registry, relationship
strategy classes split by requiredness, "value strategy" naming, and the pre-DX
`src/` layout. Tagged retroactively so the 4.0 migration guide and release notes
have a fixed reference point.

[4.0.0-beta.1]: https://github.com/nilvon9wo/ExtremeApexTestDataFactory/tree/4.0-beta
[3.5.0]: https://github.com/nilvon9wo/ExtremeApexTestDataFactory/releases/tag/v3.5.0
