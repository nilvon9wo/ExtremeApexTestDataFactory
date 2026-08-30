# Possible Future Enhancements

What is *not* yet built. Anything implemented has moved into the guides
([Customization](customization.md), [Providers](providers.md),
[Relationships](relationships.md), [Internals](internals.md)) or a design doc.
For what changed and why, see [migration.md](migration.md).

---

## Shared Ancestors

Several children under *one* shared parent, and deep record-type hierarchies that
converge on a single root. Full design, with all open decisions resolved:
**[design/shared-ancestors.md](design/shared-ancestors.md)**.

Brings with it a **deferred, whole-graph generation pass** (build everything in
memory, then evaluate, then wire + insert once per depth) - the same machinery
that unlocks descendant-value reads and one mixed-type `insert` per graph depth.

---

## Descendant (Up-Flowing) Value Reads

[Context-aware values](design/context-aware-values.md) currently read *down* the
tree (from a generated ancestor) and *sideways* (a sibling field). Reading *up* -
a parent field derived from a generated child - can't ride the same pass because
the child does not exist when the parent is built.

Two options, tracked as decision 4 in
[design/context-aware-values.md](design/context-aware-values.md):

- a light `context.requestingChildTemplate` (the child's seed template, available
  when the factory builds a parent because a child asked for it) - covers
  "matching value the test set explicitly on the child";
- the full deferred pass (above), which covers everything.

---

## Sandbox Data Seeding

XFTY's declarative model would also generate representative sandbox data, but the
framework is `@IsTest` today, which keeps it (and consumers' Providers / value
strategies) out of production code limits. Seeding needs deployable code.

**The shape:** split into a deployable base (engine, bundle, master template,
lookup, the value/relationship interfaces + generators) and a thin `@IsTest`
layer on top (`XFTY_IdMocker`, the admin-user bootstrap, the bundled Default
Providers). Everyone installs the base; the layer is the add-on. A seeding
consumer takes the base plus a thin `XFTY_Seeder` (a list of
`XFTY_DummySObjectProvider` configs -> `insert`).

**Feasibility is unknown.** Salesforce likely won't let a consumer install the
base without the layer cleanly (you can't replace a file from another package;
you may have to delete the layer's files and everything depending on them). For a
~half-dozen-file difference that may not be worth it. Needs an experiment: build
both, install into a scratch org both ways, see what breaks. The namespace /
AppExchange work ([packaging.md](packaging.md)) pushes toward the same split.

**Prior seeder recipe** (from a lost implementation, for reference): strip
`@IsTest`; take the Provider Lookup's keys as the type list; chain one queueable
per type doing
`new XFTY_DummySObjectProvider(type, lookup).setQuantityPerTemplate(100).setInsertMode(NOW).setInclusivity(ALL).supplyList()`
with best-effort exception swallowing. A few types failed (federated users /
unique-value collisions on `User`); a real version needs per-type opt-out and a
way to reuse already-inserted ancestors.

**Publish-time `@IsTest` strip** as an alternative: a source transform before
`sf package version create`, producing an `@IsTest` package and a deployable one
from the same source. Cheaper than a real module split if it can be made reliable.

---

## Remaining coverage gaps

The framework is at 100% line coverage (see [packaging.md](packaging.md)). Deeper
scenarios still worth explicit tests as the engine grows: many-level graphs,
circular relationships beyond `PREVENT_CASCADE`, and the open items in
[known-issues.md](known-issues.md).
