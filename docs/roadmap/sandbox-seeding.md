# Roadmap: Sandbox Data Seeding

Status: **📋 blocked on a project decision** —
[roadmap open question 1](README.md#1-does-xfty-commit-to-a-deployable-non-istest-distribution).
Seeding needs deployable (non-`@IsTest`) code. That is the same decision the
[namespace / AppExchange work](namespace-appexchange.md) faces, and it is
almost certainly **not** something a consumer can defer and switch later — you
cannot swap a file from another package after install. So XFTY has to commit,
once, to shipping `@IsTest`-only or shipping deployable.

This page is what seeding would look like *if* that decision goes toward
deployable.

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

## Why the split is hard

Salesforce likely will not let a consumer install the base without the layer
cleanly — you cannot replace a file from another package, so you may have to
delete the layer's files and everything depending on them. For a ~half-dozen-file
difference that may not be worth it.

If it genuinely cannot be done cleanly (the working assumption), there is no
per-consumer switch: the package either carries `@IsTest` or it does not. That is
[roadmap open question 1](README.md#open-questions).

The [namespace / AppExchange work](namespace-appexchange.md) forces the same
decision (step 4 there).

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
