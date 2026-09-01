# Open Questions

**Only genuine questions that block progress.** Each ends in a question mark and
names what it blocks. Not "things to remember", not decided work, not standing
platform facts — those live in [README.md](README.md). Grouped by feature area; an
area with nothing blocked does not appear.

---

## Distribution / packaging

### Does XFTY commit to a deployable (non-`@IsTest`) distribution?

**Blocks:** [sandbox data seeding](sandbox-seeding.md) entirely;
[namespace / AppExchange](namespace-appexchange.md) step 4.

Shipping the engine as real deployable code — not `@IsTest` — is what sandbox
seeding needs and what a managed / AppExchange package requires. The cost: the
engine then needs real production test coverage, and so do every consumer's
custom Providers and value expressions.

A consumer almost certainly **cannot** install a deployable base and add the
`@IsTest` layer later (you cannot replace a file from another package). So this is
one decision for the project, not a per-consumer switch:

> **Ship `@IsTest`-only forever** (unlocked package, no seeding, no managed
> package) — **or ship deployable** (seeding and AppExchange become possible, and
> the coverage burden lands on the engine and on every consumer's extensions)?
