# Design: Deferred Whole-Graph Pass

Status: **proposal** - not started. This is the keystone for three separate
roadmap items, so it is worth doing once, carefully.

Unlocks:

- **descendant (up-flowing) value reads** -
  [context-aware-values.md](context-aware-values.md) decision 4;
- **declared shared ancestors and deep shared chains** -
  [shared-ancestors.md](shared-ancestors.md) phases S1-S3;
- **one mixed-type `insert` per graph depth** instead of one per Provider per
  level - the "Wider applicability" note in shared-ancestors.md.

---

## How the engine works today

`XFTY_DummySObjectFactory.createBundle` is recursive and **interleaves structure
with persistence**:

```
createBundle(context, masterTemplate, templates):
    createRelatedRecords(...)          # recurse: each nested createBundle
                                       #   builds AND inserts its own level
    fill plain values on the primaries
    wire lookups
    context-aware value pass (down-flowing + sibling only)
    insert / mock-id the primaries
```

So a Contact needing an Account and a Campaign costs **three** `insert`
statements (Account, Campaign, Contact), and a value can only look at records that
were finished before it - never at a descendant.

---

## The deferred model

Split into four phases over the **whole** graph:

### Phase 1 - structural build (no DML, no Ids)

Recurse exactly as today to discover every record and every relationship, but
**never insert and never assign Ids**. Produce the full `XFTY_DummySObjectBundle`
tree with every record present in memory, lookups still unset.

Shared ancestors resolve here too - `resolveSharedRecord` runs with insert mode
forced to a non-persisting value for this phase.

### Phase 2 - value passes, whole graph visible

1. **sibling + down-flowing** (as today, but now every ancestor across the whole
   graph exists, not just the current call's);
2. **up-flowing** - walk the graph once and evaluate descendant-reading
   strategies (`XFTY_CopyFromDescendant`, custom `XFTY_ContextAwareValueIntf`
   that reads `context.descendantBundle`). A single pass suffices because every
   record is in memory; order within the pass does not matter for copy semantics.

### Phase 3 - depth-batched persistence

1. Assign every record a **depth** = longest chain of lookup fields (that point at
   another record in the pending set) from it down to a leaf.
2. From the deepest depth up to 0: `insert` (or `XFTY_IdMocker.addIds`, or skip
   for `NEVER` / `LATER`) **every record at that depth in one call, mixed
   SObjectTypes**.
3. Between depths, re-point lookup fields to the freshly-assigned Ids (the
   current phase-2/phase-3 split already does this per level - it stops grouping
   by type).
4. A cycle (A points at B, B points at A) can't be one `insert` - `update` one
   side afterwards, or error.

`RELATED_ONLY` inserts every depth except 0; `PREVENT_CASCADE` bounds phase 1 as
today.

### Phase 4 - return the bundle

Unchanged shape; `getList` / `getBundle` still work.

---

## Open decisions

1. **Rewrite vs. wrapper.** Rewrite `XFTY_DummySObjectFactory` in place, or add a
   `XFTY_DeferredFactory` that phase-1s by calling the existing recursion in a
   "structure only" mode and takes over from there? The wrapper limits blast
   radius but duplicates traversal logic.
2. **"Structure only" mode.** Phase 1 needs the current recursion to build
   without inserting. Either a flag on `XFTY_GenerationContext`
   (`insertMode == a new STRUCTURAL sentinel`?) or a separate code path. The
   sentinel is cheap but leaks a non-user mode into the enum.
3. **Depth computation cost.** Reading each record's populated lookup fields
   (`getPopulatedFieldsAsMap()` + describe of each field's `referenceTo`) to find
   in-set targets. How much describe traffic is acceptable? Cache per
   `SObjectType`.
4. **Is this always on, or opt-in?** Always-on is simpler and gives everyone the
   DML win, but it is a big behaviour change (Id assignment timing, DML
   statement count, insert order) that could surprise a consumer relying on
   today's per-level inserts. Opt-in (`.deferred()` on the Provider, or a new
   insert mode) is safer for a first release.
5. **Interaction with `@TestSetup`-style multi-call tests.** Today each
   `supplyBundle()` is independent. The deferred pass is still per-call unless
   shared ancestors span calls (they already do, via static state) - confirm
   nothing else needs to.
6. **Governor budget.** The `XFTY_Load` suite must gain worst-case graphs and
   assert the depth-batched insert really is O(depth) not O(records), plus CPU
   for the depth sort. Establish and document limits (shared-ancestors.md
   decision 3).

---

## Migration impact

Breaking if always-on (decision 4): Id assignment moves to the end, DML statement
count drops, insert order changes from "deepest Provider first" to "deepest
depth first". A consumer asserting an exact DML count, or relying on a trigger
side effect of a mid-generation insert, would notice. Opt-in avoids this for the
first release.

---

## Rough plan

1. `XFTY_DummySObjectBundle` gains a flat "every record in the tree" view (walk
   once) - needed by phases 2 and 3.
2. Phase 3 in isolation: a `XFTY_DepthBatchedInserter` that takes a flat record
   set + the pending-set membership test, computes depths, inserts depth by
   depth, re-points lookups. Unit-tested against hand-built graphs.
3. Structure-only mode for phase 1.
4. Wire phases 1 -> 3 behind `.deferred()` (opt-in). Run the whole existing suite
   under `.deferred()` too, to prove equivalence.
5. Phase 2 up-flow pass + `XFTY_CopyFromDescendant` + `context.descendantBundle`.
6. Declared shared ancestors (`require(...)`) on top - they are just "resolve
   these before phase 1".
7. Load tests, documented limits, decide always-on vs opt-in from the numbers.
