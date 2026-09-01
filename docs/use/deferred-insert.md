# Deferred & Depth-Batched Insert

> On `4.0-beta` (like the rest of 4.0; `master` is frozen). Design rationale:
> [roadmap/deferred-persistence.md](../roadmap/deferred-persistence.md).

Two ways to move DML out of the per-Provider recursion.

---

## `DEFERRED` — generate over many calls, insert once

```apex
XFTY_DummySObjectBundle accounts = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .setQuantityPerTemplate(3)
    .supplyBundle();

XFTY_DummySObjectBundle contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .supplyBundle();

XFTY_DeferredInserter.flush();   // every graph from every DEFERRED call, inserted now
```

`DEFERRED` generates exactly like `NEVER` — no Ids, no DML — but registers every
record. `flush()` inserts everything registered so far, **depth-batched** (one
`insert` per dependency depth, across all the graphs), and because the records
handed back are the same instances, their `Id` fields are now populated.

- A test that never calls `flush()` gets `NEVER` semantics — no surprise DML.
- Records inserted by a `NOW` call in between are left untouched; a `DEFERRED`
  record pointing at one keeps that Id.
- `flush()` clears the registry — generation after a `flush()` starts fresh.
- Not supported with `@TestSetup` (it resets statics).
- [Shared ancestors](shared-ancestors.md) work — each is resolved up front.
- `flush()` also resolves any [`XFTY_CopyFromDescendantExpression`](context-aware-values.md#reading-up-from-a-child)
  value (a parent field read up from a generated child).

### It does not give you an Id mid-generation

If a later call needs the real Id of a record an earlier call produced,
`flush()` the earlier call first:

```apex
XFTY_DummySObjectBundle parents = parentProvider.setInsertMode(XFTY_InsertModeEnum.DEFERRED).supplyBundle();
XFTY_DeferredInserter.flush();                                    // parents now have Ids

Id parentId = parents.getList(Account.Id)[0].Id;
childProvider.setOverrideTemplate(new Contact(AccountId = parentId))
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED).supplyBundle();
XFTY_DeferredInserter.flush();
```

---

## `.depthBatched()` — one `insert` per depth in a single `NOW` call

By default `NOW` runs one `insert` per Provider: a `Task` with an `Account`
parent and a `Contact` parent costs three. `.depthBatched()` collapses that to
one `insert` per dependency depth — the `Task` example drops to two:

```apex
new XFTY_DummySObjectProvider(Task.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .depthBatched()
    .supplyBundle();
```

The generated records are identical; only the number and **order** of `insert`
statements changes. It is opt-in for exactly that reason — a test that asserts an
exact DML count, or depends on the order its triggers fire during generation,
should leave it off.

- Only affects `NOW` (other modes do no framework DML).
- Shared ancestors and `XFTY_CopyFromDescendantExpression` values both work under
  `.depthBatched()` — the whole graph exists before the batched insert.
- A lookup cycle (A → B, B → A) cannot be one `insert` order and throws
  `XFTY_DepthBatchedInserter.CyclicGraphException`.

▶ Runnable: `XFTY_Ex_DeferredInsertTest`

See also: [insert-modes](insert-modes.md) · [advanced/deep-setup-chains](advanced/deep-setup-chains.md)
