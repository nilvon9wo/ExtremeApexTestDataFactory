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
ancestor survives across `supplyBundle()` calls **within one test method** - the
point of requirement 3.

No reset hook is needed and none will be added. Salesforce isolates every test
method: static state never survives from one test method to the next (nor from
`@TestSetup`, which is why XFTY documents not using it - see
[salesforce-considerations.md](../salesforce-considerations.md)). Each test method
starts with an empty registry.

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

### 1. What kicks off resolution (S0-S2)? — *direction given*

Ideal: fully implicit and lazy. `XFTY_SharedAncestor.get('acme-hq')` called
*anywhere* starts the whole chain resolving, and the consumer never has to call a
"begin" method. Apex may not make that clean (a `get` that triggers DML and
Provider execution as a side effect is surprising and hard to bound).

Fallback, and probably the design: hook the **first call into
`XFTY_DummySObjectProviderLookupIntf` to fetch a Provider**. That is the last
moment where "nothing has been generated yet" is still true, and any shared
ancestor necessarily relates to a Provider reachable from that lookup, so the
lookup is the natural coordination point. Concretely: `supplyBundle()` (or the
factory) runs S0-S2 once, lazily, the first time it needs a Provider from the
lookup, then proceeds.

Still open: whether to support **multiple `XFTY_DummySObjectProviderLookupIntf`
instances in play at once** in the same test. Leaning towards "not a supported
scenario" unless a real need appears.

### 2. Collection without executing Providers — *accepted*

S0 walks the relationship maps and recurses into each resolved Provider's Master
Template without generating anything - a second, read-only traversal of the
template graph. Accepted as reasonable; watch the downstream implications as it's
built.

### 3. Depth batching cost + cycles — *needs load testing*

Computing each record's depth means inspecting its populated lookup fields
(`getPopulatedFieldsAsMap()` + describe of each field's `referenceTo`). Before
committing to it:

- **Real load tests against worst-case graphs.** The feature must leave *plenty*
  of DML headroom - the code under test and the rest of the test's own setup both
  need DML too. Establish where it breaks and a safe working range.
- **Document the findings** so consumers know the limits.
- **Provide off-switches:** disable generation of a specific record, and disable
  the entire shared-ancestor feature, per run.

Cycles (`John.Account = HQ`, `HQ.PrimaryContact = John`) can't be one `insert`
either way - detect and either error or break with a follow-up `update`.

### 4. Insert mode — *honour the caller's mode*

A shared ancestor honours the top-level call's insert mode. It is **not** forced
to `NOW`.

Rationale: shared ancestors are not only about satisfying validation rules on
insert - they also express **data-integrity / shared-data models**. A test may
need "these three records all point at the *same* parent" to be true in memory
(`MOCK`, `NEVER`) without any DML at all. The sharing guarantee is independent of
persistence.

### 5. Reset between tests — *not needed*

Removed. Salesforce isolates every test method; static state never leaks between
them. No `clear()` hook. (See "The registry" above.)

### 6. `reusing(existingRecord)` — *needs a clearer proposal*

The idea: let a test hand XFTY a record it created itself and register it as a
named shared ancestor, so subsequent `XFTY_SharedAncestor.get('root')` references
resolve to *that* record instead of generating one:

```apex
MyHierarchyObj__c root = /* the test inserts its own root */;
XFTY_SharedAncestor.reusing('Root', root);   // from here, get('Root') == this record
```

Use cases: (a) the record already exists because of `@TestSetup`-free shared
setup logic the test ran itself; (b) an org-wide singleton (like the `Root` in
the acceptance scenario) that a prior step in the same test already inserted, so
regenerating it would violate the constraint. To be fleshed out into a concrete
API + semantics (what if it's called after the name already resolved?).

---

## Acceptance scenario: deep record-type hierarchy with a singleton root

A real case this design must satisfy (it also exercises lookup keys hard). The
test uses **custom** metadata, so it lives in `test-support/`, not the published
package.

**The shape.** One custom SObject that is its own parent (a self lookup, like
`Account.ParentId`). It has **at least 10 record types** forming a strict
hierarchy of levels, the top one called **`Root`**:

- Every non-root record has exactly one parent, and the parent's record type is
  **fully determined by the child's record type** - the hierarchy *narrows*
  downward (`Level3_RegionEast` always has a `Level2_Region` parent, never
  anything else), so from any leaf you can compute the entire chain of ancestor
  record types up to `Root`.
- Parent and child record types are always different.
- **`Root` is a singleton.** Exactly one record of type `Root` may exist in the
  org; a second insert fails.

Salesforce has no native "record type hierarchy", so `test-support/` supplies the
mapping itself - the simplest thing that works: a
`static Map<String, String> PARENT_RT_BY_CHILD_RT` (plus an Apex trigger or
validation rule enforcing the `Root` singleton). Nothing more elaborate is needed
for a test.

**What XFTY must do.** A test asks for one deep-level record:

```apex
MyHierarchyObj__c leaf = (MyHierarchyObj__c) new XFTY_DummySObjectProvider(
        XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Level9_Branch'),
        lookup
    )
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supply();
```

and XFTY generates the whole chain `Level9 -> Level8 -> ... -> Level1 -> Root`,
each record carrying the correct record type, **all converging on the one shared
`Root` record** - so two `supply()` calls for different leaves produce two chains
that share the same `Root` Id.

**Why this needs shared ancestors specifically.** Without them, each generated
parent gets its own generated grandparent, and every chain would try to insert
its own `Root` - the second `supply()` (or the second leaf in one call) blows up
on the singleton constraint. `XFTY_SharedAncestor.get('Root')` is the mechanism
that makes `Root` resolve once and be reused everywhere:

```apex
// test-support, one place
XFTY_SharedAncestor.get('Root').of(new MyHierarchyObj__c())
        .withKey(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Root'));

// the Level1 Provider's Master Template
.putRequired(MyHierarchyObj__c.Parent__c, XFTY_SharedAncestor.get('Root'))
```

**What it forces onto this design (new open decisions):**

7. **Record-type-aware parent selection.** Each level's Provider must, for its
   required self-parent relationship, resolve the parent Provider *by the parent
   record type* - i.e. the relationship's lookup key is a function of the current
   record's key, not a constant. Options: a distinct Provider + `XFTY_LookupKey`
   per level (10 tiny Providers, explicit, no new mechanism - probably the
   answer for a *test*), or a single Provider whose Master Template computes the
   parent key from `PARENT_RT_BY_CHILD_RT` (needs relationships to accept a
   key-producing callback, which is a real framework change).
8. **Chain depth vs. `PREVENT_CASCADE` / inclusivity.** Generating `Level9` pulls
   in eight ancestors + `Root`. `REQUIRED` inclusivity must recurse the whole way
   (it already does); confirm the shared-ancestor S0 collection walk also
   recurses parent-of-parent when the parent is itself shared-or-required.
9. **Singleton ancestors in general.** `Root` is the degenerate case of "there
   must be exactly one" - the shared-ancestor registry already gives that for
   free *within a transaction*; document that a consumer whose singleton is
   enforced across transactions (a real org-wide constraint) needs
   `reusing(existingRoot)` (decision 6) after the first test inserts it, or must
   run in a context where each test re-creates it.

---

## Rough implementation plan

1. `XFTY_SharedAncestor` + `XFTY_SharedAncestorRegistry` + `parentCountFor` on
   the relationship interface; `XFTY_DummyDefaultRelationship.parentCountFor`
   returns `childCount`. No factory behaviour change yet (a shared ancestor
   throws "not wired" if used).
2. Phase S3 wiring in the factory + a manual
   `XFTY_SharedAncestorRegistry.resolveAll(lookup, insertMode)` a test can call.
3. Phases S0-S2 automatic, triggered lazily from the first
   `XFTY_DummySObjectProviderLookupIntf` fetch (decision 1).
4. Nested ancestors; depth batching; cycle detection; load tests + documented
   limits + off-switches (decision 3).
5. `reusing(...)` (decision 6), docs, worked example (the deep-hierarchy scenario).

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
