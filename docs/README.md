# XFTY Documentation

The docs are grouped by purpose. If you are new, read the tutorials in order;
come back to the how-to and reference material as you need it.

## Tutorials — learn XFTY by doing

Start here. Each builds on the last.

| Guide | You will be able to |
|-------|---------------------|
| [Getting Started](getting-started.md) | Generate records, customize fields, create related records, choose an insert mode. |
| [Customization](customization.md) | Use override templates, `put(...)`, implicit exact values, and removal — and know which to reach for. |
| [Relationships](relationships.md) | Control relationship generation and inclusivity; read and navigate Bundles. |

## How-to guides — extend and operate XFTY

Task-focused, assume you know the basics.

| Guide | Covers |
|-------|--------|
| [Providers](providers.md) | Write a Provider for a new `SObject`; write a Provider Lookup; record-type and flavour variants (`withVariant`, lookup-key constructor); the bundled Providers and their test-user helpers. |
| [Testing Modes](testing-modes.md) | Every insert mode and inclusivity setting, and when to use each. |
| [Packaging & Development](packaging.md) | Local setup, scratch orgs, CI, the `XFTY_Unit` / `XFTY_Integration` / `XFTY_Load` test suites, unlocked-package builds, the namespace / AppExchange roadmap. |

## Reference — look things up

| Document | Contents |
|----------|----------|
| [Migration](migration.md) | Every breaking change in this release and exactly what to change. |
| [Salesforce Considerations](salesforce-considerations.md) | Platform behaviours that constrain XFTY (`@TestSetup`, mixed DML, governor limits) and recommended practice. |
| [Known Issues](known-issues.md) | Defects found and fixed, and the current triage list. |

## Explanation — understand the design

| Document | Contents |
|----------|----------|
| [Internals](internals.md) | Architecture and the reasoning behind the main design decisions. |
| [Future Ideas](future-ideas.md) | Enhancements under consideration, with their open questions. |

## Design proposals — not yet built

Working documents for features still being specified. Each lists open decisions.

| Proposal | Status |
|----------|--------|
| [Multi-Variant Providers](design/multi-variant-providers.md) | Implemented — kept for the rationale. |
| [Context-Aware Values](design/context-aware-values.md) | Sibling + ancestor reads implemented; descendant reads still designed. |
| [Shared Ancestors](design/shared-ancestors.md) | On-demand path implemented; declared / deep-chain path still designed. |
