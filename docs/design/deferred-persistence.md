# Design: Deferred Persistence

Status: **built** on branch `deferred-persistence` (not merged). Two related ways
to move DML out of the recursion:

1. **Depth-batched persistence** - the opt-in `.depthBatched()` Provider flag: one
   mixed-type `insert` per dependency depth instead of one per Provider.
2. **The `DEFERRED` insert mode** - generate like `NEVER` over many
   `supplyBundle()` calls, then `XFTY_DeferredInsert.flush()` inserts the whole
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

Same records, same graph - just **one mixed-type `insert` per dependency depth**
instead of one per Provider:

1. Structural build with no DML (this is exactly what `NEVER` produces today).
2. Assign each record a **depth** = longest chain of populated lookup fields, that
   point at another record in the pending set, down to a leaf.
3. From deepest depth to 0: `insert new List<SObject>{ ...every record at this
   depth, any types... }`, re-pointing lookup fields to the fresh Ids between
   depths.
4. A cycle can't be one `insert` - `update` one side afterwards, or error.

The Task example drops from 3 to 2. A wide graph (a record with five parents of
five types) drops from 6 to 2.

### What is built

`XFTY_DepthBatchedInserter.insertAll(List<SObject> records, List<Edge> edges)` -
`@IsTest`, in `core/`. Records are identified by **index** in `records` (Apex
`SObject` map/list membership is value-based, so an index is the only safe handle
on an instance). Each `Edge` is `{childIndex, parentIndex, lookupField,
parentSourceField}` - `parentSourceField` null means wire from the parent's Id,
non-null means wire from that field (the related-field relationship form).

`insertAll` computes each record's depth = longest chain of edges to a leaf
(memoised DFS, `visiting`/`done` state to detect cycles), groups by depth, then
inserts shallowest depth first, re-pointing each child's lookup to its now-inserted
parent between depths. A cycle (including a self-reference) throws
`CyclicGraphException`. Empty/null `records` is a true no-op (0 DML).

`XFTY_DepthBatchedInserterTest` (`XFTY_Integration`) pins the DML counts: flat set
= 1, two levels = 2, five mixed-type parents at one depth = 2, deep chain = one
per level, shared parent inserted once. 100% line coverage (strip-to-measure),
every branch hand-checked.

### How it is wired

`.depthBatched()` on `XFTY_DummySObjectProvider` sets a flag. When it is set
**and** the mode is `NOW`, `supplyBundle()`:

1. runs generation with the context forced to `NEVER` and marked
   `context.depthBatched` (carried down every derived context);
2. hands the finished top bundle to `XFTY_DeferredInsertBuffer.insertGraph(...)`.

`XFTY_DeferredInsertBuffer` walks the bundle - which is a tree, since the engine
generates a distinct parent per child row - registering every record in visit
order and emitting an `Edge` for each child lookup still null after the structural
build (related-field lookups are already wired from plain values, so only Id
lookups are pending). It then calls `XFTY_DepthBatchedInserter.insertAll`.

`XFTY_DummySObjectBundle` gained `primaryTargetField` (set by `createBundle`) and
`relationshipFields()` so the walk can navigate without the master templates.
`XFTY_GenerationContext` gained the `depthBatched` flag purely so
`wireSharedAncestor` can refuse the unsupported combination early.

**Opt-in, settled** (Brian, repeatedly): never always-on. It changes `insert`
order and the order triggers fire mid-generation, which many tests depend on.

Still open: **depth-computation cost** at volume (the walk is O(records + edges));
load-test alongside the `XFTY_Load` suite. **Shared ancestors + depth-batching** -
refused for now; needs the walk to handle a record reachable from two places.

---

## 2. A reference-preserving insert mode

The need (Brian's words): *"a mode where a test or its helpers can invoke the
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

XFTY_DeferredInsert.flush();   // inserts everything registered so far, one pass,
                               // and the Ids appear on the records already handed out
```

### What is built

`XFTY_InsertModeEnum.DEFERRED` + `XFTY_DeferredInsert` (static registry).

- A `DEFERRED` Provider call generates exactly like `NEVER` (context forced to
  `NEVER` + `forBatchedInsert()`), then `XFTY_DummySObjectProvider` calls
  `XFTY_DeferredInsert.register(bundle)` instead of inserting.
- `register` hands the bundle to a static `XFTY_DeferredInsertBuffer` (the same
  bundle-walk as `.depthBatched()`), accumulating records + edges across every
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

`XFTY_DeferredInsertTest` (`XFTY_Integration`): held without Ids until flush,
2-insert depth batching, many graphs in one flush, no-flush = no DML, flush
clears the set, a `DEFERRED` record pointing at an already-inserted record,
shared ancestor throws. 100% line coverage.

### Not done yet

- **Shared ancestors + `DEFERRED`** - refused, same as `.depthBatched()`. The
  design once hoped `DEFERRED` would give a shared ancestor a consistent Id
  across `MOCK`-then-`NOW`, but the tree-walk assumes no shared instances. Needs
  the walk to handle a record reachable from two places.
- **`@TestSetup`** - not supported (resets statics). Documented, not worked around.
- **A value pass inside `flush()`** for descendant/up-flowing reads (below).

---

## Relationship to other roadmap items

- **Descendant value reads** ([context-aware-values.md](context-aware-values.md)
  decision 4) want the whole graph in memory before values are finalised.
  `DEFERRED` gives exactly that between `supply*()` and `flush()` - a value pass
  can run in `flush()` before the insert.
- **Declared shared ancestors** ([shared-ancestors.md](shared-ancestors.md)) can
  be "register these in the deferred set, then `flush()`".

Both ideas are built. Descendant reads and declared shared ancestors can now
reuse the `flush()` machinery.
