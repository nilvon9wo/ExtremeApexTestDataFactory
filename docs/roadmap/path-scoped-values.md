# Path-Scoped Value Overrides

Status: **✅ built** (`XFTY_PathValue`, `put(List<SObjectField>, value)` on
`XFTY_DummySObjectProvider`). Brian's idea, 2026-08-31.

`includeOptional(List<SObjectField>)` walks a path of relationship fields into the
generated ancestors to force each step required, for one call. `put(path, value)`
uses the same path mechanism to set **how a field on an ancestor is generated**,
for one call — without touching that ancestor's Provider.

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace')
    .supply();
// -> the generated Account has Industry = 'Aerospace'
```

`path` is `[rel1, rel2, ..., targetField]`: every element but the last is a
relationship on the way, the last is the field the value lands on.

## What "value" can be

Every kind plain `put` / `putRequired` / `putOptional` accept:

| Call | Effect on the ancestor's field |
|---|---|
| `put(path, Object literal)` | a constant |
| `put(path, XFTY_DummyDefaultValueIntf)` | a value strategy (runs once per generated ancestor) |
| `put(path, XFTY_ContextAwareValueIntf)` | evaluated against the ancestor as `recordBeingBuilt` — `XFTY_CopyFromSibling` / `XFTY_CopyFromAncestor` etc. work relative to that ancestor |
| `putRequired(path, XFTY_DummyDefaultRelationshipIntf)` | the ancestor's own lookup gets a generated parent |
| `putOptional(path, XFTY_DummyDefaultRelationshipIntf)` | …optional on the ancestor |

## Semantics

- **Follows inclusivity**, exactly like `includeOptional`. The ancestor still has
  to be generated — pair with `setInclusivity(REQUIRED)` / `ALL`, or the field is
  already required. A `put(path, ...)` on an ancestor that is not generated is a
  silent no-op.
- The relationship walk **is** forced: each path's prefix (everything but the
  target) is folded into the forced-relationship paths, so an *optional*
  relationship on the way is promoted to required (again, under `REQUIRED`
  inclusivity).
- Threaded through `XFTY_GenerationContext` next to `forcedRelationshipPaths`;
  `forRelated(field)` drops the head and carries the rest one level down.
- Applied by `XFTY_PathValueApplier` onto a copy of the master template for the
  level being generated — after `XFTY_RelationshipForcer`. A path `put` on a
  field the ancestor's Provider already sets **wins** (it removes then re-puts).

## Implementation

`XFTY_PathValue` (core) · `XFTY_PathValueApplier` (engine) · 5 `put` / `putRequired`
/ `putOptional` overloads on `XFTY_DummySObjectProvider` taking `List<SObjectField>`
· `XFTY_GenerationContext.pathValues` + `withPathValues` + `forRelated` filter.
`XFTY_PathValueTest` (8).

## Possible follow-ups

- **Force regardless of inclusivity.** A `put(path, ...)` clearly signals intent
  to have that ancestor; requiring `setInclusivity(REQUIRED)` too is a small
  foot-gun. Same argument applies to `includeOptional`. One decision for both.
- Mirror on the read side is already there — `XFTY_CopyFromAncestor(path)`.
