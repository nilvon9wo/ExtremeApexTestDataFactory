# Roadmap: Sandbox Data Seeding

Status: **📋 proposed, feasibility unknown**. Needs an experiment before it can
be planned properly.

---

## The idea

XFTY's declarative model would also generate representative **sandbox** data, not
just test data. The obstacle: the framework is `@IsTest` today, which keeps it
(and consumers' Providers / value strategies) out of production code and its
limits. Seeding needs deployable, non-`@IsTest` code.

---

## The shape

Split XFTY into:

- a **deployable base** — engine, bundle, master template, lookup, the
  value/relationship interfaces + generators;
- a thin **`@IsTest` layer** on top — `XFTY_IdMocker`, the admin-user bootstrap,
  the bundled Default Providers.

Everyone installs the base; the layer is the add-on. A seeding consumer takes the
base plus a thin `XFTY_Seeder` (a list of `XFTY_DummySObjectProvider` configs →
`insert`).

---

## Why feasibility is unknown

Salesforce likely will not let a consumer install the base without the layer
cleanly — you cannot replace a file from another package, so you may have to
delete the layer's files and everything depending on them. For a ~half-dozen-file
difference that may not be worth it. **The experiment:** build both, install into
a scratch org both ways, see what breaks.

The [namespace / AppExchange work](namespace-appexchange.md) pushes toward the
same split (step 4 there).

---

## Prior seeder recipe (for reference)

From a lost implementation: strip `@IsTest`; take the Provider Lookup's keys as
the type list; chain one queueable per type running
`new XFTY_DummySObjectProvider(type, lookup).setQuantityPerTemplate(100).setInsertMode(NOW).setInclusivity(ALL).supplyList()`
with best-effort exception swallowing. A few types failed (federated users /
unique-value collisions on `User`); a real version needs per-type opt-out and a
way to reuse already-inserted ancestors.

**Publish-time `@IsTest` strip** as a lighter alternative: a source transform
before `sf package version create`, producing an `@IsTest` package and a
deployable one from the same source. Cheaper than a real module split if it can
be made reliable.
