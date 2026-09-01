# Design: Shared Ancestors

Status: **implemented, one API, resolution auto-detected** (v4). Usage in
[use/shared-ancestors.md](../use/shared-ancestors.md).

> **Update (v4):** the "declared vs on-demand" split below was a real design
> stage, but the shipped API has **no `declared()` / `require()` / `context()`**.
> A test configures a shared ancestor with `put(name, ...)` (or
> `putIfAbsent(name, ...)`) and references it. Before a Provider generates, every
> shared ancestor configured this test method is resolved in one pre-phase
> (`XFTY_SharedAncestorResolver.resolveAllConfigured`), each honouring the
> call's insert mode. XFTY inspects each one's Provider's Master Template: **no
> relationships → flat**, resolved as a single record; **relationships → deep**,
> its sub-graph built once and depth-batch-inserted. `resolveNow(lookup, mode)`
> covers reading `getId(...)` before any `supply*()`. The rationale for two
> *behaviours* still stands; only the manual opt-in is gone.

Implemented (`XFTY_SharedAncestor`, `XFTY_SharedAncestorResolver`):

- `XFTY_SharedAncestor.get(name)` - flyweight, interned by name, static state so it
  resets between test methods (decision 5).
- `putAsTemplate(name, t)` / `put(name, key)` / `.fromVariant(key)` / `.copyingRelatedField(field)`
  configuration; reconfiguring after resolution throws. `putIfAbsent(name,
  template|lookupKey)` configures only if unconfigured (for a shared setup helper
  / superset config). For the full case - value expressions on the shared record,
  its own ancestors, path values, inclusivity - chain the same per-record `put`
  API straight onto `put(name, ...)`; `XFTY_SharedAncestorProvider` carries it and
  the resolver builds structurally then depth-batches. No multi-record knobs are
  on that type, so no runtime guard.
- Implements `XFTY_SharedRelationshipIntf extends XFTY_DummyDefaultRelationshipIntf`
  so it drops into `putRequired` / `putOptional`. The factory branches on the
  interface: one record resolved (generated once, or supplied via `put(...)`),
  every child pointed at it.
- `XFTY_SharedAncestor.put(name, record)` (decision 6), `getId(name)`,
  `resolveNow(lookup, mode)`.
- Pre-phase in `XFTY_DummySObjectProvider.supplyBundle` →
  `XFTY_SharedAncestorResolver.resolveAllConfigured`. S0 collect: depth-first over each
  configured ancestor, following its Provider's Master Template into nested
  shared ancestors, dependency-ordered; cycle → throw, depth > 10 → WARN
  (decision 8). Re-entrant hits (an ancestor's own generation reaching another)
  resolve themselves; a live cycle across that boundary still throws.
- S1 generate `NEVER` / `REQUIRED`; S2 depth-batched persist **per ancestor
  sub-graph**, honouring the mode (`NOW` insert / `MOCK` mock-Id / `NEVER` no-op;
  `DEFERRED` / `RELATED_ONLY` → `NOW` so the shared Id is ready), not re-inserting
  already-resolved anchors.
- The main build wires the pre-resolved record; shared ancestors now work with
  `.depthBatched()` / `DEFERRED` on the referencing call (previously refused).

**Developer control (done):** `disable(name)` (never resolve; FK left null),
`manualResolutionOnly()` (pre-phase off; lightweight ancestors lazy-resolve,
heavy ones the test resolves up front — the light-vs-heavy split is the old
"on-demand vs declared" distinction, auto-detected from the Master Template),
`resolveNow(lookup, mode, names)` (batch). The reachability walk was **rejected**
(Brian): it re-walks per `supply*()` call and would build independent ancestors
separately anyway — the manual knob is the answer for heavy loads.

**Known limit (documented, not fixed):** one S2 pass across *all* shared
ancestors at once - resolution depth-batches per sub-graph, so several
*independent* heavy shared ancestors cost a few extra `insert`s. Converging
chains are already one pass.

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
XFTY_SharedAncestor.put('acme-hq', new Account(Name = 'ACME HQ'));
XFTY_SharedAncestor.put('john', new Contact(LastName = 'Doe'));

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
[salesforce-considerations.md](../reference/salesforce-considerations.md)). Each test method
starts with an empty registry.

Each `XFTY_SharedAncestor` holds:

- `name`
- `overrideTemplate` (`SObject`) and optional explicit `XFTY_LookupKeyIntf`
- `relatedField` (nullable, as for `XFTY_DummyDefaultRelationship`)
- once resolved: the generated record (and, if useful, its sub-bundle)

`put(name, ...)` registers it. Because it is interned, configuration
should happen **once**; changing the template on an already-*resolved* ancestor
is a programming error and should throw. Re-configuring a not-yet-resolved
ancestor is allowed but logs a `System.debug(WARN)` (see `put(...)` below).

---

## The hard part: DML-frugal resolution

This whole section is about **declared** ancestors (decision 9). **On-demand**
ancestors skip it entirely - they generate inline with their sibling
relationships and need no pre-phase (see decision 9).

A *declared* ancestor can be deep and can be needed before the first top-level
generation call (or across several of them), so it cannot just be generated
inline inside `createRelatedRecords` - that method inserts one level at a time and
would produce one `insert` per ancestor. Declared ancestors get their own phase,
run **before** the main graph build, that batches.

### Phase S0 - collect

From the set the test `require(...)`d, walk each declared ancestor's Master
Template (and, recursively, the Master Templates of the Providers its
relationships resolve to) and collect every distinct **unresolved** declared
`XFTY_SharedAncestor`. Recursion terminates because ancestors are interned and
each is visited once.

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

## Design decisions (all settled)

Each is decided; nothing here blocks implementation. Kept for the rationale.
The one item that still wants *data* rather than a decision is decision 3 (load
test the depth-batch cost before committing the numbers).

### 1. What kicks off resolution (S0-S2)? — *superseded by decision 9*

Now largely answered by the declared-vs-on-demand split (decision 9):

- **Declared** ancestors resolve when the test's `XFTY_SharedAncestor.require(...)`
  call runs (top of the test) - or, at the latest, when the first generation call
  needs one.
- **On-demand** ancestors resolve lazily the first time a `get` or a relationship
  reaches them.

Either way the entry point is a `XFTY_SharedAncestor` call, not a hook buried in
the Provider Lookup. `supplyBundle()` / the factory still drives phases S1-S2 (the
batched build) the first time generation needs any registered-but-unresolved
ancestor.

**Multiple `XFTY_DummySObjectProviderLookupIntf` instances in one test** - not
actively supported, not actively prevented. If a resolved shared ancestor happens
to work when reached through two different lookups, the developer is welcome to
it; the framework won't add code to police or guarantee it.

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

### 6. Registering a record the test made itself — `put(name, record)`

Let a test hand XFTY a record it created itself and register it as a named shared
ancestor, so subsequent `XFTY_SharedAncestor.get('Root')` references resolve to
*that* record instead of generating one:

```apex
MyHierarchyObj__c root = /* the test inserts its own root */;
XFTY_SharedAncestor.put('Root', root);   // from here, get('Root') == this record
```

Name is `put(...)`, matching `XFTY_DummySObjectMasterTemplate.put` /
`XFTY_DummySObjectProvider.put` - the verb XFTY already uses for "register this
under that key". If `put(...)` overwrites a name that already has a *different*
record (or a configured-but-unresolved ancestor), log a `System.debug(WARN)` so
an accidental double-register is visible without failing the run; overwriting a
name that resolved to an equal record is silent.

Use cases: (a) the record already exists because of shared setup logic the test
ran itself (XFTY discourages `@TestSetup`); (b) an org-wide singleton (like the
`Root` in the acceptance scenario) that an earlier step in the same test already
inserted, so regenerating it would violate the constraint.

**Resolved.** `put(...)` on an already-resolved name **warns and replaces** -
`System.debug(WARN)`, no exception. XFTY's job is to give a mechanism for sharing
an identified record, not to police how the developer uses it; there are
legitimate reasons to swap what is shared partway through a test. (The
implementation does this today.)

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

**What XFTY must do.** A test declares the spine it needs, then asks for one
deep-level record:

```apex
// configure the shared part of the chain (once, centrally)
XFTY_SharedAncestor.put('root', new MyHierarchyObj__c())
    .fromVariant(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Root'));

MyHierarchyObj__c leaf = (MyHierarchyObj__c) new XFTY_DummySObjectProvider(
        XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Level9_Branch'),
        lookup
    )
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supply();
```

and XFTY generates the whole chain `Level9 -> Level8 -> ... -> Level1 -> Root`,
each record carrying the correct record type (its own per-level Provider +
`XFTY_RecordTypeLookupKey`, decision 7), **converging on the one shared `Root`** -
so two `supply()` calls for different leaves produce two chains that share the
same `Root` Id. Here only `root` (and maybe `level1`) need to be *shared*; the
`Level2..Level9` records above them are ordinary per-chain ancestors.

**Why this needs shared ancestors specifically.** Without them, each generated
parent gets its own generated grandparent, and every chain would try to insert
its own `Root` - the second `supply()` (or the second leaf in one call) blows up
on the singleton constraint. A shared ancestor makes `Root` resolve once and be
reused everywhere:

```apex
// test-support, one place
XFTY_SharedAncestor.put('root', new MyHierarchyObj__c())
        .fromVariant(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Root'));

// the Level1 Provider's Master Template
.putRequired(MyHierarchyObj__c.Parent__c, XFTY_SharedAncestor.get('root'))
```

`Root`'s Provider has no ancestors of its own, so it resolves as a single shared
record; `Level1`, which pulls in `Root`, resolves as a depth-batched sub-graph.

**What it forces onto this design:**

### 7. Record-type-aware parent selection — *keys, not computed keys*

**Decided.** Selection is by explicit key. Each level's Provider pins its parent
with a key *constant* - `Level5`'s Master Template does
`.putRequired(Parent__c, <key-pinned relationship to level 4>)`, never a computed
one. No key-producing callback in relationships or Master Templates: removing
"hacky/leaky Master Template computations" is the whole point of lookup keys, and
a compute-the-key callback would put the leak right back.

It is **at least one Provider per record type**, not exactly one - a record type
can still fan out into several `XFTY_FlavouredLookupKey` variants (e.g.
`Level5` + `enterprise`, `Level5` + `smb`), each with its own Provider. The
deep-hierarchy scenario happens to use one plain `XFTY_RecordTypeLookupKey` per
level, but nothing stops a level from having flavours.

### 8. Chain depth — *as deep as it needs, with guard rails*

The chain recurses the full distance (`Level9 -> ... -> Root`); anything shorter
means an invalid record or a data-integrity gap, so depth itself is not
negotiable. But:

- **Warn on excessive depth** - a `System.debug(WARN)` past some threshold, so a
  runaway or accidental deep chain is visible.
- **Detect cycles.** Shared ancestors that reference each other
  (`a` needs `b`, `b` needs `a`) must be caught, not recursed forever. The
  `put(name, record)` map (decision 6) is the main mitigation: pre-registering
  one side of a would-be cycle breaks it, because that side resolves immediately
  instead of being generated. Without a pre-registration, detect the cycle in the
  S0 walk and throw.

### 9. Every test creates its own ancestors — *declared vs. on-demand*

**Tests can never share data** - Salesforce makes it impossible, by design.
Every test method is responsible for creating every ancestor it uses, whether it
wants to or not. `put(name, record)` doesn't change that; it just lets a test
supply a record it made itself *this method*.

The real problem is **overhead**: a test that only touches `Level9` shouldn't pay
to build a ten-deep chain it doesn't care about, and a test that needs nothing
shared shouldn't pay at all. Rejected: a blanket opt-out (gets ugly fast).
Preferred design - **two kinds of shared ancestor**:

| Kind | Generated | Constraints |
|------|-----------|-------------|
| **Declared** | Only if the test **declares** it needs it, up front (`XFTY_SharedAncestor.require('root', 'level1', ...)` at the top of the test). | May have ancestors of its own; may be heavy. |
| **On-demand** | Lazily, the first time it's referenced during generation. | Must be **lightweight and have no ancestors of its own**. |

A declared ancestor that a test **did not declare** is never generated, and any
attempt to reach it - `XFTY_SharedAncestor.get('level4')`, or a relationship that
resolves to it during generation - throws an **explicit error** naming the
ancestor and telling the author to add it to the `require(...)` call. No silent
fallback, no lazy generation for the declared kind. (On-demand ancestors are the
opposite: reaching one that hasn't been built yet just builds it.)

**On-demand ancestors build in synergy with their siblings.** An on-demand
`XFTY_SharedAncestor.get('mr-smith')` is just an `XFTY_DummyDefaultRelationshipIntf`
implementation that memoises its resolved record by name - so it drops into
`putRequired` / `putOptional` next to ordinary relationships and rides the *same*
generation pass and the *same* DML:

```apex
.putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
.putOptional(Contact.CompanyPresident__c, XFTY_SharedAncestor.get('mr-smith'))
```

The only thing that makes `mr-smith` special is that its record is cached under
that name for reuse by this record's other fields, other records, and other
Master Templates. This works because `get(...)` returns the shared relationship
interface. It relies on `mr-smith` being an on-demand type - lightweight, no
ancestors of its own - so it can be resolved inline; a *declared* name asked for
here would hit the "not declared" error instead. So `get(...)` first checks which
kind the name is.

Declared ancestors don't ride the sibling pass - they are pre-resolved in
phases S0-S2 (they may be deep or heavy, and must exist before the first
top-level generation call). On-demand ancestors need no pre-phase at all.

### The four invariants a shared ancestor must always keep

No matter how it is referenced (sibling field, ancestor, descendant, a different
`supplyBundle()` call) and no matter the insert mode(s) involved:

1. the record is **created exactly once**;
2. it has **one consistent Id** - real or mocked, never both, never changing;
3. that Id is populated **everywhere** it is expected in the generated records;
4. the shared record itself appears **everywhere** it is expected in the
   bundle / graph (including `bundle.getBundle(field)`, not just `getList(field)`).

**Both gaps that once existed here are fixed** (see
[reference/known-issues.md](../reference/known-issues.md#fixed-kept-for-context)):

- **Mixed insert modes.** A `MOCK`-resolved shared ancestor referenced from a
  later `NOW` call now **throws a clear "consistent insert mode" error** instead
  of drifting a mock Id into real DML. Pin the mode up front with
  `XFTY_SharedAncestor.get(name).resolveNow(lookup, mode)`.
- **Bundle placement (invariant 4).** `getBundle(field)` on a shared-ancestor
  field returns a single-record sub-bundle (`getResolvedBundle()`), consistent
  with `getList(field)`.

**`XFTY_SharedAncestor.getId('name')`** - the resolved record's `Id`, for anywhere
an `Id` is what's wanted (an override template field, an assertion, a lookup the
Master Template sets directly rather than through a relationship). Same
kind-dependent behaviour as `get(...)`:

| Name is... | `getId('name')` does |
|------------|----------------------|
| on-demand | resolves it now if needed (generating + caching), returns the `Id` |
| declared, and `require`d | returns the cached `Id` |
| declared, not `require`d | throws the "not declared" error |
| unknown | throws |

`getId` needs to know the **insert mode**, because it may be called while a test
is still *building* an override template - before any `XFTY_DummySObjectProvider`
call has fixed one. Mocking an `Id` by default and hoping a later `NOW` run
reconciles it is too fragile - it invites `INVALID_CROSS_REFERENCE` /
"id value of incorrect type" errors when a mock `Id` leaks into real DML, and
mock-vs-real drift is exactly the class of bug this framework exists to prevent.

So the insert mode is **declared with the ancestors**, up front:

```apex
XFTY_SharedAncestor.context(XFTY_InsertModeEnum.NOW).require('root', 'level1');
// ... now get('root') / getId('root') resolve against NOW
```

`getId` (or `get`) for an unresolved on-demand name with **no context established**
throws a clear error asking the author to set one. Inline resolution during a
`supplyBundle()` already has the mode (the generation call's) and needs no
`context(...)`.

This is the narrow, shared-ancestor slice of the larger **"bring a generation
context into the build"** question. `XFTY_GenerationContext`
([architecture.md](../contribute/architecture.md#the-generation-context)) already carries the
insert mode, the Provider Lookup, and - during the value pass - the record being
built and its ancestor bundle; the shared-ancestor `context(mode)` declaration
plugs into it.

A test that declares nothing and uses only on-demand ancestors pays only for what
it references. A test working deep in a hierarchy declares the spine it needs and
gets a clear error the moment it touches a level it forgot. This also gives
decision 1 its trigger: the `require(...)` call (or the first on-demand `get`) is
where S0-S2 start.

There is no cross-test case to handle. Every test method runs in its own
transaction and all of its DML is rolled back when it finishes; data another test
(or `@TestSetup`) created does not exist during this one, and cannot be made to.
So a shared ancestor is always generated fresh within the test that needs it -
`XFTY_SharedAncestor` only has to keep it consistent *within* that single test.

---

## Implementation plan — status

1. ~~`XFTY_SharedAncestor` + interned registry~~ — **done**. The `parentCountFor`
   interface method was skipped: the factory's
   `instanceof XFTY_SharedRelationshipIntf` branch already means "0 to generate,
   just wire".
2. ~~Deep vs flat behaviour + the main-build wiring~~ — **done**, but
   **auto-detected from the Provider's Master Template**, not a manual
   `require(...)`. The "undeclared → throw" error is gone (there is nothing to
   declare). `resolveNow(lookup, mode)` is the pre-`supply` `getId` entry point.
3. ~~Phases S0-S2, triggered from the first `supply*()`~~ — **done**
   (`XFTY_SharedAncestorResolver`). S2 is one depth-batched pass per ancestor
   sub-graph, not one across the whole set — **documented as a known limit**
   (converging chains are already one pass). Resolving only the *reachable*
   ancestors was **rejected** (see "Developer control" above).
4. ~~Nested ancestors; depth-warning + cycle detection (incl. the re-entrant
   boundary)~~ — **done**. ~~Off-switches (decision 3)~~ — **done**
   (`disable(name)` / `manualResolutionOnly()` / batch `resolveNow`). Load tests
   + documented volume limits — still to do.
5. ~~`put(name, record)` / `putIfAbsent(name, ...)`~~ — **done**. Docs — **done**
   ([use/shared-ancestors.md](../use/shared-ancestors.md),
   `XFTY_SharedAncestorTest` + `XFTY_SharedAncestorHierarchyTest`).
6. ~~Packaged defaults so a shipped Provider's shared ancestors work without the
   test registering them~~ — **done**. `XFTY_SharedAncestorDefaultsIntf` on the
   lookup (or `XFTY_ProviderLookups.of(providerMap, defaults)`);
   `XFTY_SharedAncestorResolver.applyLookupDefaults` calls it before resolution,
   `putIfAbsent` so a test still overrides.
   The deep-record-type-hierarchy acceptance test is **done**:
   `XFTY_HierarchyNode__c` (test-support: self-parent lookup, 10 record types,
   `XFTY_HierarchyNodeRootSingleton` trigger) +
   `XFTY_SharedAncestorDeepHierarchyTest` (`test-support/orgonly/`, scratch
   org) — two `Level9` leaves, `REQUIRED` + `NOW`, whole chain generated with the
   right record types, both converging on the one shared singleton `Root`.

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
