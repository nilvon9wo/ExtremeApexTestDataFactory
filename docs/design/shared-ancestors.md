# Design: Shared Ancestors

Status: **proposal**. Builds on the merged relationship model from
[multi-variant-providers.md](multi-variant-providers.md).

---

## Problem

Every generated child currently gets its own generated parent.

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setQuantityPerTemplate(3)
    .setInclusivity(REQUIRED)
    .supplyBundle();
// => 3 Contacts, 3 Accounts
```

Real hierarchical data often wants the opposite: 3 Contacts under **one**
Account; an `OpportunityLineItem` and its `Opportunity` sharing **one**
`Account`; a batch of records all owned by the same `User`.

Tests can re-parent afterwards, but that defeats the point of declarative setup
and breaks as soon as the graph gets two levels deep.

---

## Shape of the solution

A second implementation of `XFTY_DummyDefaultRelationshipIntf`:

```apex
.putRequired(Contact.AccountId, XFTY_SharedAncestor.of(new Account()))
```

Because requiredness now lives on the Master Template slot, the same shared
ancestor can be required in one Provider and optional in another - which was the
main reason for merging `Required` + `Optional`.

Fluent configuration:

```apex
XFTY_SharedAncestor.of(new Account())
    .poolSize(2)          // round-robin across 2 shared parents instead of 1
    .scope(XFTY_SharingScope.TRANSACTION)   // default is BUNDLE
```

| Scope | One shared parent per... |
|-------|--------------------------|
| `BUNDLE` (default) | `supplyBundle()` call - covers `setQuantityPerTemplate` and multiple override templates |
| `TRANSACTION` | test method - covers parents shared across *separate* Provider calls (Opp + OLI) |

`TRANSACTION` scope uses a `static` cache and therefore inherits the framework's
existing `@TestSetup` caveat (see
[salesforce-considerations.md](../salesforce-considerations.md)).

---

## Engine changes

The interface gains one method:

```apex
Integer parentCountFor(Integer childCount);
```

- `XFTY_DummyDefaultRelationship` returns `childCount` (unchanged behaviour).
- `XFTY_SharedAncestor` returns `min(poolSize, childCount)`.

`XFTY_DummySObjectFactory`:

1. **createRelatedRecords** - generate `relationship.parentCountFor(childCount)`
   parents instead of always `childCount`. For `TRANSACTION` scope, first consult
   the static cache (keyed by `resolveLookupKey().getHashKey()` +, if we decide to,
   a hash of the override template) and only generate the shortfall.
2. **createRelationships** - wire `child[i].field <- parents[i // (childCount / parentCount)].id`
   (or simple `parents[i mod parentCount]` for a pool; the exact distribution is
   an open question, see below).

Transitive relationships of a shared parent are generated once, with it.

---
OO
## Bundle contract

`bundle.getBundle(field)` holds the true generated set (e.g. 1 Account).

`bundle.getList(field)` currently returns a list aligned 1:1 with the primary
records. Options:

- **A. Keep it aligned** - return `childCount` entries, repeating the shared
  instance. Preserves every existing caller; slightly surprising that
  `getList(field)[0] === getList(field)[1]`.
- **B. Return the deduplicated set** - `getList(field).size()` becomes the parent
  count. Cleaner, but breaks callers that index `getList(field)` in lockstep with
  `getList(Id)`.

Recommend **A** (compatibility), with `getBundle(field).getList(parentPrimaryField)`
as the deduplicated view.

---

## Open decisions

1. **`BUNDLE` only, or `BUNDLE` + `TRANSACTION`?** `TRANSACTION` is where the real
   power is (cross-provider hierarchies) but also where the `@TestSetup` /
   static-state sharp edges live. Ship `BUNDLE` first?
2. **`TRANSACTION` cache key** - lookup key alone (first override template wins,
   simple) or lookup key + serialized override template (predictable, more
   allocation)?
3. **Pool distribution** - contiguous blocks (`children 0-1 -> parent 0,
   children 2-3 -> parent 1`) or round-robin (`0,2 -> parent 0; 1,3 -> parent
   1`)? Blocks match how people think about "2 accounts, 4 contacts each".
4. **Naming** - `XFTY_SharedAncestor` / `XFTY_SharedAncestor.of(...)` vs
   `XFTY_DummyDefaultRelationship.shared(...)` vs a flag on the existing class.
   A flag keeps one type but muddies `parentCountFor`; a separate type is
   cleaner and matches "pluggable implementations of the relationship interface".
5. **Explicit shared instance** - also allow handing in an already-generated
   parent (`XFTY_SharedAncestor.reusing(existingAccount)`) so a test can parent
   generated records under a record it made itself?

---

## Rough implementation plan

1. `XFTY_SharingScope` enum; `parentCountFor` on the interface;
   `XFTY_DummyDefaultRelationship` returns `childCount`.
2. `XFTY_SharedAncestor` (BUNDLE scope, poolSize 1) + factory wiring + tests.
3. Pool size + distribution.
4. TRANSACTION scope + static cache + tests (incl. the `@TestSetup` note).
5. `reusing(existing)` if decision 5 is yes.
6. Docs: relationships.md, a new worked example, future-ideas.md.
