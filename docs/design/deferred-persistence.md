# Design: Deferred Persistence

Status: **proposal** - not started. Two related ideas that both move DML out of
the recursion:

1. **Depth-batched persistence** - a performance change to the existing engine.
2. **A reference-preserving insert mode** - a new, opt-in `XFTY_InsertModeEnum`
   value for tests that call the framework several times and want the whole set
   inserted (and Ids back-filled) at the end.

Neither requires rewriting `XFTY_DummySObjectFactory`.

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

### Questions

- **Opt-in or always-on?** Always-on gives everyone the win but changes insert
  order and (for a consumer asserting an exact DML count, or relying on a
  trigger firing mid-generation) is a visible behaviour change. Opt-in
  (`.depthBatched()` on the Provider) is safe for a first release.
- **Depth-computation cost.** `getPopulatedFieldsAsMap()` + describe of each
  field's `referenceTo`, cached per `SObjectType`. Load-test it.
- **Where it lives.** A `XFTY_DepthBatchedInserter` that takes the flat record set
  + a "is this in the pending set" test, unit-tested against hand-built graphs,
  then wired into `createBundle` after the structural build.

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

- `DEFERRED` generates like `NEVER` (no Ids) but **registers every generated
  record** in a static list, keyed by identity.
- `flush()` inserts the registered set - depth-batched (idea 1) - and because the
  records handed back are the *same instances*, their `Id` fields are now
  populated. Every lookup that was wired to another registered record is
  re-pointed.
- **Plays nice with mixed modes.** Records that were inserted by a `NOW` call
  (e.g. a reused setup utility) are not in the registry, already have Ids, and a
  `DEFERRED` record pointing at one keeps that Id untouched. `flush()` only
  touches the registry.
- Static, so it resets between test methods. A test that never calls `flush()`
  gets `NEVER` semantics - no surprise DML.

### Questions

- **Does `flush()` need the lookup / an insert mode?** It has the records and
  their wiring already; it just needs to insert. Probably no arguments.
- **Interaction with shared ancestors.** A shared ancestor resolved during a
  `DEFERRED` call registers like any other record; `flush()` inserts it once.
  This is also how a shared ancestor gets a *consistent* Id across
  `MOCK`-then-`NOW` usage (see shared-ancestors.md - the current on-demand path
  has a gap here).
- **`@TestSetup`.** Not supported - `@TestSetup` resets statics, so the registry
  would be empty. Documented, not worked around.

---

## Relationship to other roadmap items

- **Descendant value reads** ([context-aware-values.md](context-aware-values.md)
  decision 4) want the whole graph in memory before values are finalised.
  `DEFERRED` gives exactly that between `supply*()` and `flush()` - a value pass
  can run in `flush()` before the insert.
- **Declared shared ancestors** ([shared-ancestors.md](shared-ancestors.md)) can
  be "register these in the deferred set, then `flush()`".

So build idea 1 first (it's self-contained and testable), then idea 2 on top,
then descendant reads and declared ancestors reuse the `flush()` machinery.
