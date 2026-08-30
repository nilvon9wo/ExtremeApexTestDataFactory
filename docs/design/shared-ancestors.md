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

### Phase S2 - ordered bulk insert

Group the collected top-level ancestor records by `SObjectType` and insert them
**in dependency order** (an SObjectType whose records point at another group's
records goes second). The dependency graph among *named* ancestors is small and
acyclic in practice; a topological sort over "ancestor A's record has a lookup to
ancestor B's record" is enough. Non-shared records generated underneath an
ancestor insert with that ancestor's group.

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
3. **Dependency ordering in S2.** Topological sort over named ancestors, or the
   simpler "insert Accounts before everything else" heuristic people rely on? A
   cycle (John.Account = HQ, HQ.PrimaryContact = John) - detect and error, or
   break with a second-pass update?
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
4. Nested ancestors; dependency ordering; cycle detection.
5. `reusing(...)`, `clear()`, docs, worked example.
