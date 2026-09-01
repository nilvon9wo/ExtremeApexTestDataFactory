# Design: Deferred Persistence

Status: **built**, merged to `4.0-beta` (`407d38a`), not on `master`. Two
related ways to move DML out of the recursion:

1. **Depth-batched persistence** - the opt-in `.depthBatched()` Provider flag: one
   mixed-type `insert` per dependency depth instead of one per Provider.
2. **The `DEFERRED` insert mode** - generate like `NEVER` over many
   `supplyBundle()` calls, then `XFTY_DeferredInserter.flush()` inserts the whole
   set (reusing idea 1's machinery) with Ids back-filled on the handed-out
   instances.

Neither required rewriting `XFTY_DummySObjectFactory` - both are a structural
build (`NEVER`) plus a bundle-walk in `XFTY_DeferredInsertBuffer`.

---

## Today's behaviour (measured)

`XFTY_DummySObjectFactory.createBundle` recurses per Provider, and each recursion
runs its own `insert` at the end. So a graph with **two different SObjectTypes at
the same depth** costs one `insert` per type, not one per depth:

`XFTY_DummySObjectFactoryDmlTest.insertStatementsForTwoParentTypesAtOneDepth`
generates a `Task` with an `Account` parent (`WhatId`) and a `Contact` parent
(`WhoId`) in `NOW` mode and asserts **3** insert statements - Account, Contact,
Task - not 2.

`MOCK` / `NEVER` / `LATER` are already free (empty inserts cost nothing), so this
only matters for `NOW` / `RELATED_ONLY`.

---

## 1. Depth-batched persistence

Same records, same graph - just **one mixed-type `insert` per dependency layer**
instead of one per Provider. The Task example drops from 3 inserts to 2; a record
with five parents of five types drops from 6 to 2.

### What is built

`XFTY_DepthBatchedInserter.insertAll(List<SObject> records, List<ParentLink> links)`
- `@IsTest`, in `core/`. Records are identified by **index** (Apex `SObject`
equality is by field value, not identity). A `ParentLink` is
`{childIndex, parentIndex, field}`.

The algorithm is Kahn-style, not depth memoisation: repeatedly take every record
whose parents are all already saved, point their lookups at the fresh parent Ids,
`insert` them as one layer, repeat. A layer that comes up empty while records
remain is a cycle - `CyclicGraphException`. Empty/null input is a no-op.

`XFTY_DepthBatchedInserterTest` (`XFTY_Integration`) pins the DML counts: flat set
= 1, two levels = 2, parents of different types at one layer = 2, chain = one per
link, one shared parent = once, cycle + self-reference throw. 100% line coverage
(strip-to-measure), every branch hand-checked.

### How it is wired

`.depthBatched()` on `XFTY_DummySObjectProvider` sets a flag. When it is set
**and** the mode is `NOW`, `supplyBundle()`:

1. runs generation with the context forced to `NEVER` and marked
   `context.batchedInsertPending` (carried down every derived context);
2. hands the finished top bundle to `XFTY_DeferredInsertBuffer.insertGraph(...)`.

`XFTY_DeferredInsertBuffer` walks the bundle - a tree, since the engine clones
every template and generates a distinct parent per child row - appending every
record and emitting a `ParentLink` for each child lookup still null after the
structural build (related-field lookups were wired from plain values already, so
only Id lookups are pending). Then `XFTY_DepthBatchedInserter.insertAll`.

`XFTY_DummySObjectBundle` gained `primaryRecords()` / `relationshipFields()` so the
walk needs no master templates. `XFTY_GenerationContext` gained
`batchedInsertPending` purely so `wireSharedAncestor` can refuse it.

**Opt-in, settled**: never always-on. It changes `insert` order and the order
triggers fire mid-generation, which many tests depend on.

Before merge (not decisions — work): a `XFTY_Load` measurement of the
bundle-walk cost at volume (`O(records + links)`), and shared-ancestor support
(refused today — the walk would have to handle a record reachable from two
places).

---

## 2. A reference-preserving insert mode

The need: *"a mode where a test or its helpers can invoke the
framework multiple times, yielding exactly the same result as if `NEVER` was set,
but then leverage object references so that we can retroactively fill the Ids
later before they actually start needing/using these values."*

Today `LATER` "behaves like `NEVER` while documenting that insertion will happen
later" - it has no flush. This makes that real.

```apex
XFTY_DummySObjectBundle a = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED).supplyBundle();
XFTY_DummySObjectBundle c = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED).supplyBundle();

XFTY_DeferredInserter.flush();   // inserts everything registered so far, one pass,
                               // and the Ids appear on the records already handed out
```

### What is built

`XFTY_InsertModeEnum.DEFERRED` + `XFTY_DeferredInserter` (static registry).

- A `DEFERRED` Provider call generates exactly like `NEVER` (context forced to
  `NEVER` + `forBatchedInsert()`), then `XFTY_DummySObjectProvider` calls
  `XFTY_DeferredInserter.register(bundle)` instead of inserting.
- `register` hands the bundle to a static `XFTY_DeferredInsertBuffer` (the same
  bundle-walk as `.depthBatched()`), accumulating records + links across every
  call - global indices, so one `flush()` covers many graphs.
- `flush()` runs `XFTY_DepthBatchedInserter.insertAll` over the whole set and
  then replaces the buffer, so the pending set is cleared. Because the records
  handed back are the *same instances*, their `Id` fields are now populated.
- **No cross-call identity problem.** The engine clones every template and
  generates a distinct parent per child row, so each bundle's records are fresh
  instances no other bundle shares. The walk is positional within one tree and
  never needs to reconcile a record seen twice - so the registry is just
  "append each bundle's forest, insert the union."
- **Mixed modes.** A record inserted by a `NOW` call is not in the registry and
  already has an Id; a `DEFERRED` record pointing at it was wired by Id during
  the structural build, so no edge is emitted and `flush()` leaves it alone.
- Static, so it resets between test methods. A test that never calls `flush()`
  gets `NEVER` semantics - no surprise DML.

`XFTY_DeferredInserterTest` (`XFTY_Integration`): no Ids until flush, 2-insert depth
batching, many graphs in one flush, no-flush = no DML, flush clears the set, a
`DEFERRED` record pointing at an already-saved record, a `NOW` insert interleaved
untouched by `flush()`, flush-between-calls to use earlier Ids, shared ancestor
throws. 100% line coverage.

### What `DEFERRED` does not do

It does not hand you a record's real Id *during* generation. If a later
`supplyBundle()` needs an earlier call's Id - as a template value, or to drive
record-type selection - `flush()` the earlier call first, then generate the
later one. Within one `flush()` group XFTY only wires the lookups it generated;
it never reorders the caller's own intent.

### Not done yet

- **Shared ancestors** - supported. Each is resolved in its own pre-phase before
  the `DEFERRED` build and carries a real / mock Id by flush time, so the walk
  treats it as an anchor. (Earlier this was refused; see
  [shared-ancestors.md](shared-ancestors.md).)
- **`@TestSetup`** - not supported (resets statics). Documented, not worked around.
- **A value pass inside `flush()`** for descendant/up-flowing reads — **built**
  (`XFTY_DescendantValuePass`, [descendant-value-reads.md](descendant-value-reads.md)).

---

## Relationship to other roadmap items

- **Descendant value reads** ([context-aware-values.md](context-aware-values.md)
  decision 4) want the whole graph in memory before values are finalised.
  `DEFERRED` gives exactly that between `supply*()` and `flush()` - a value pass
  can run in `flush()` before the insert.
- **Shared ancestors** ([shared-ancestors.md](shared-ancestors.md)) reuse the
  same depth-batched-insert primitive for each sub-graph's pre-phase, and a
  `DEFERRED` main call resolves its shared ancestors up front so their Ids are
  ready when it `flush()`es.

Both ideas are built. Descendant reads and shared ancestors reuse the `flush()`
machinery.
