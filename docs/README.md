# XFTY Documentation

The docs are split by **who you are and what you are trying to do**. Pick the
directory that matches your goal.

| I want to… | Go to | Start with |
|------------|-------|-----------|
| **Use XFTY to write tests for my code** | [`use/`](use/) | [use/getting-started.md](use/getting-started.md) |
| **Teach XFTY about my org's SObjects** (write Providers, register variants, custom value expressions) | [`extend/`](extend/) | [extend/README.md](extend/README.md) |
| **Work on XFTY itself** (architecture, tests, packaging, contributing) | [`contribute/`](contribute/) | [contribute/architecture.md](contribute/README.md) |
| **Look something up** (breaking changes, platform constraints, open defects, the API list) | [`reference/`](reference/) | [reference/](reference/) |
| **See what's built, in progress, or proposed** | [`roadmap/`](roadmap/) | [roadmap/README.md](roadmap/README.md) |
| **Read the thinking behind XFTY** (the author's essays — background, not reference) | [`articles/`](articles/) | [articles/README.md](articles/README.md) |

---

## use/ — consume XFTY in your tests

One page per feature, each opening with the simplest example and building up.
See [use/README.md](use/README.md) for the reading order and the full feature
matrix (every feature → its page → the runnable test that proves its examples).

- [Getting Started](use/getting-started.md) — the guided tour
- Generating & customizing: [generating-records](use/generating-records.md) ·
  [override-templates](use/override-templates.md) ·
  [value-expressions](use/value-expressions.md) ·
  [context-aware-values](use/context-aware-values.md)
- Relationships: [relationships](use/relationships.md) ·
  [per-call-relationships](use/per-call-relationships.md) ·
  [shared-ancestors](use/shared-ancestors.md) · [bundles](use/bundles.md)
- Persistence: [insert-modes](use/insert-modes.md) ·
  [deferred-insert](use/deferred-insert.md)
- [provider-variants](use/provider-variants.md) ·
  [test-user-helpers](use/test-user-helpers.md)
- [advanced/](use/advanced/) — combining features

## extend/ — teach XFTY about your org

- [Providers](extend/providers.md) — support a new `SObject` type
- [Provider Lookups](extend/provider-lookups.md) — your project's registry
- [Provider Variants](extend/provider-variants.md) — record-type / flavour keys
- [Custom Value Expressions](extend/custom-value-expressions.md)
- [Shared Ancestors in a Master Template](extend/shared-ancestors-in-templates.md)
- [The Bundled Providers](extend/bundled-providers.md) — copy-and-adjust

## contribute/ — work on XFTY

- [Coding Standards](contribute/coding-standards.md) — the rules code is held to
- [Architecture](contribute/architecture.md) — the engine and why it is shaped this way
- [Local Development](contribute/local-development.md) — scratch orgs, Nimbus, coverage
- [Test Suites](contribute/test-suites.md) — `XFTY_Unit` / `XFTY_Integration` / `XFTY_Load` / `XFTY_Examples`
- [Coverage Standards](contribute/coverage-standards.md)
- [Packaging](contribute/packaging.md) · [CI](contribute/ci.md)

## reference/

- [Migration](reference/migration.md) — every breaking change in this release
- [Salesforce Considerations](reference/salesforce-considerations.md) — `@TestSetup`, mixed DML, governor limits
- [Volume & Limits](reference/volume-and-limits.md) — where generation breaks Salesforce, and the automatic WARN
- [Known Issues](reference/known-issues.md) — the open triage list
- [API Cheat-Sheet](reference/api-cheatsheet.md) — every public class and method, one line each

## roadmap/

[roadmap/README.md](roadmap/README.md) is the status table plus the decided
remaining work. [roadmap/open-questions.md](roadmap/open-questions.md) is the
short list of genuine questions that block progress (currently one). Detail
pages (the former `design/` proposals) sit beside them.

## articles/

Three long-form essays by the author on the reasoning behind XFTY — where it came
from, why isolated unit tests are worth the effort on Salesforce, and how to
write them. Opinion pieces kept for background;
[articles/README.md](articles/README.md) has the reading order. Nothing else in
the docs depends on them.
