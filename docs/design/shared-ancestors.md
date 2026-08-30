# Design: Shared Ancestors

Status: **proposal** (v2 - rewritten after feedback). Builds on the merged
relationship model from [multi-variant-providers.md](multi-variant-providers.md).

---

## Requirements

1. **Deterministic, not pooled.** A shared ancestor is *one* record. Every field
   that references it gets the same Id.
2. **Named and interned.** `XFTY_SharedAncestor.get('John')` returns the one
   instance for that name (flyweight), from anywhere.
3. **Built once per transaction.** The record is generated (and inserted) the
   first time it is needed and cached on the instance; later references - in the
   same or a different `supplyBundle()` call - reuse it.
4. **Cross-template, cross-SObject.** The same `XFTY_SharedAncestor.get('John')`
   can sit in `Contact.ReportsToId` on the Contact Master Template *and*
   `Case.ContactId` on the Case Master Template. Different fields, different
   Master Templates, different owning SObjects - one John.
5. **Fills either slot.** It implements `XFTY_DummyDefaultRelationshipIntf`, so it
   goes in `putRequired(...)` or `putOptional(...)` like any relationship.
6. **DML-frugal.** Resolving N shared ancestors must not cost N DML statements.
   If 'John' and 'Jane' are both Contacts, they insert together.

Consumption:

```apex
// somewhere central
XFTY_SharedAncestor.get('acme-hq').of(new Account(Name = 'ACME HQ'));
XFTY_SharedAncestor.get('john').of(new Contact(LastName = 'Doe'));

// any Master Template, any field
.putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acme-hq'))
.putOptional(Case.ContactId,    XFTY_SharedAncestor.get('john'))
```

---

## The registry

`XFTY_SharedAncestorRegistry` - a `static Map<String, XFTY_SharedAncestor>`.
`XFTY_SharedAncestor.get(name)` interns through it. Being static, a resolved
ancestor survives across `supplyBundle()` calls in the same test - the point of
requirement 3 - and inherits the framework's existing `@TestSetup` caveat
(see [salesforce-considerations.md](../salesforce-considerations.md)).

Each `XFTY_SharedAncestor` holds:

- `name`
- `overrideTemplate` (`SObject`) and optional explicit `XFTY_LookupKeyIntf`
- `relatedField` (nullable, as for `XFTY_DummyDefaultRelationship`)
- once resolved: the generated record (and, if useful, its sub-bundle)

`of(...)` / `withKey(...)` configure it. Because it is interned, configuration
should happen **once**; a second `of(...)` with a different template on an
already-resolved ancestor is a programming error and should throw.

---

## The hard part: DML-frugal resolution

A shared ancestor cannot be generated inline inside `createRelatedRecords`,
because that method inserts one level at a time and would produce one `insert`
per ancestor. Resolution needs its own phase, run **before** the main graph
build, that batches.

### Phase S0 - collect

Walk the Master Template(s) about to be used (and, recursively, the Master
Templates of the Providers those relationships resolve to) and collect every
distinct **unresolved** `XFTY_SharedAncestor`. Recursion terminates because
ancestors are interned and each is visited once.

Nested case: `XFTY_SharedAncestor.get('john')` is a Contact; the Contact Provider
requires an Account which is itself `XFTY_SharedAncestor.get('acme-hq')`.
Collecting 'john' surfaces 'acme-hq'.

### Phase S1 - generate in memory

For each collected ancestor, run its Provider's `createBundle` with insert mode
forced to **`NEVER`**, inclusivity as configured. Record graphs, no DML.

### Phase S2 - depth-batched bulk insert

The goal is the **fewest possible `insert` statements**, so batch by dependency
*depth*, not by `SObjectType`. Apex allows one `insert` to carry many types -
`insert new List<SObject>{ account, contact, contract }` - as long as nothing in
the list points at an un-inserted record in the *same* list.

1. Assign every collected record (shared ancestors *and* the non-shared records
   generated underneath them in S1) a depth = longest path from it to a leaf via
   lookup fields that point at another record in the set.
2. From the deepest level up to depth 0, `insert` **all records at that level in
   one call, mixed types**. Re-point lookup fields to the freshly-assigned Ids
   between levels (the existing phase-2/phase-3 split already does this per
   level - it just needs to stop grouping by type).
3. A cycle (A points at B, B points at A) can't be one insert either way -
   detect it and break it with a follow-up `update` of one side, or error.

This is the same batching the main factory could use for the whole graph, not
just shared ancestors - see "Wider applicability" below.

`RELATED_ONLY` / `LATER` interact here - S2 respects the top-level call's mode.

### Phase S3 - main build

The normal graph build runs. When `createRelatedRecords` meets an
`XFTY_SharedAncestor`, `parentCountFor(childCount)` returns 0 (nothing to
generate) and wiring reads `ancestor.getResolvedRecord().Id` for every child.

---

## Interface change

`XFTY_DummyDefaultRelationshipIntf` gains:

```apex
Integer parentCountFor(Integer childCount);   // standard: childCount; shared: 0
```

The factory treats `parentCountFor == 0` as "already resolved - just wire it". An
`isShared()` / `getResolvedRecord()` pair on a narrower interface
(`XFTY_SharedRelationshipIntf extends XFTY_DummyDefaultRelationshipIntf`) keeps
the base contract clean.

---

## Bundle contract

`bundle.getList(field)` stays aligned 1:1 with the primary records (every entry
the same shared instance). `bundle.getBundle(field)` exposes the ancestor's
sub-graph once.

---

## Open decisions

1. **Where do S0-S2 run?** In `XFTY_DummySObjectProvider.supplyBundle()` (knows
   the entry Master Template) or inside `XFTY_DummySObjectFactory` (recursive
   already, but no "run starts here" hook)?
2. **Collection without executing Providers.** S0 wants the shared ancestors
   *reachable* from a Master Template without generating anything - walk the
   relationship maps, resolve each Provider, recurse into its Master Template. A
   second traversal of the template graph. Acceptable?
3. **Depth batching in S2.** Computing each record's depth means inspecting its
   populated lookup fields to see which point at another record in the pending
   set - `getPopulatedFieldsAsMap()` + describe of each field's referenceTo.
   Feasible; how much describe cost is acceptable? A cycle (John.Account = HQ,
   HQ.PrimaryContact = John) - detect and error, or break with a second-pass
   `update`?
4. **Insert mode.** Does a shared ancestor honour the *first* caller's insert
   mode, or does the registry default to `NOW` (sharing across calls only makes
   sense for inserted records)?
5. **Reset between tests.** Static state needs `XFTY_SharedAncestorRegistry.clear()`
   for isolation - consumer's job (Apex has no per-method static reset hook)?
6. **`reusing(existingRecord)`** - seed the registry with a record the test
   inserted itself?

---

## Rough implementation plan

1. `XFTY_SharedAncestor` + `XFTY_SharedAncestorRegistry` + `parentCountFor` on
   the relationship interface; `XFTY_DummyDefaultRelationship.parentCountFor`
   returns `childCount`. No factory behaviour change yet (a shared ancestor
   throws "not wired" if used).
2. Phase S3 wiring in the factory + a manual
   `XFTY_SharedAncestorRegistry.resolveAll(lookup, insertMode)` a test can call.
3. Phases S0-S2 automatic from `supplyBundle()`.
4. Nested ancestors; depth batching; cycle detection.
5. `reusing(...)`, `clear()`, docs, worked example.

---

## Wider applicability: depth-batched insert for the whole factory

The S2 batching - one mixed-type `insert` per dependency depth instead of one per
`SObjectType` per level - is not specific to shared ancestors. Today
`XFTY_DummySObjectFactory` recurses per Provider and each recursion inserts its
own single type, so a Contact needing an Account *and* a Campaign costs three
`insert` statements. A depth-batched flush (collect the whole in-memory graph,
depth-sort, one `insert` per depth) would cut that to two (or one, when the
Campaign has no un-inserted dependency).

This is a larger change - it moves insertion out of the recursion into a final
pass - and would want its own proposal, but shared ancestors and this share the
same depth-sort + mixed-`insert` primitive, so building that primitive once for
S2 sets it up.
