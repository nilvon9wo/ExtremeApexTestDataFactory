# Open Questions

**Only truly open questions that block progress.** Not "things to remember", not
decided work, not standing platform facts — those live in
[README.md](README.md) (Remaining work / Standing constraints). Every entry here
ends with a question mark and names what it blocks.

Organized by feature area. Empty under a heading means nothing is blocked there.

---

## Distribution / packaging

### Does XFTY commit to a deployable (non-`@IsTest`) distribution?

**Blocks:** [sandbox data seeding](sandbox-seeding.md) entirely;
[namespace / AppExchange](namespace-appexchange.md) step 4.

Shipping the engine as real deployable code — not `@IsTest` — is what sandbox
seeding needs and what a managed / AppExchange package requires. The cost: the
engine then needs real production test coverage, and so do every consumer's
custom Providers and value strategies.

A consumer almost certainly **cannot** install a deployable base and add the
`@IsTest` layer later (you cannot replace a file from another package). So this
is one decision for the project, not a per-consumer switch:

> **Ship `@IsTest`-only forever** (unlocked package, no seeding, no managed
> package) — **or ship deployable** (seeding and AppExchange become possible, and
> the coverage burden lands on the engine and on every consumer's extensions)?

An experiment would sharpen it: build both layerings, install each into a scratch
org, see exactly what breaks. But the decision is a direction, not a fact to
discover.

---

## Context-aware values

_None._ (Sibling ordering, ancestor reads, and descendant reads are all decided —
see [context-aware-values.md](context-aware-values.md) and
[descendant-value-reads.md](descendant-value-reads.md).)

## Relationships / shared ancestors

_None._ Every decision in [shared-ancestors.md](shared-ancestors.md) is settled;
cycle detection behaviour is decided (it throws — see
[README.md](README.md#remaining-work-decided-needs-building)).

## Deferred persistence

_None._ Shared-ancestor support and the load-test are work items, not questions.
