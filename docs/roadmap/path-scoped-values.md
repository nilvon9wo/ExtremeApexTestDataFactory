# Path-Scoped Value Overrides

Status: **✅ built** (`XFTY_PathValue`, `put(List<SObjectField>, value)` on
`XFTY_DummySObjectProvider`). Proposed 2026-08-31.

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
| `put(path, XFTY_ValueExpressionIntf)` | a value expression (runs once per generated ancestor) |
| `put(path, XFTY_ContextAwareExpressionIntf)` | evaluated against the ancestor as `recordBeingBuilt` — `XFTY_CopyFromSiblingExpression` / `XFTY_CopyFromAncestorExpression` etc. work relative to that ancestor |
| `putRequired(path, XFTY_DummyDefaultRelationshipIntf)` | the ancestor's own lookup gets a generated parent |
| `putOptional(path, XFTY_DummyDefaultRelationshipIntf)` | …optional on the ancestor |

## Semantics

- **Forces its whole path, regardless of the call's inclusivity.** Every
  relationship you name — the walk steps *and* a `putRequired`/`putOptional`
  target — is generated even at the default `NONE`. `includeOptional(...)` behaves
  the same way now (see [per-call-relationships](../use/per-call-relationships.md)).
  A path field that is not a relationship on the Provider throws — **never** a
  silent no-op.
- **A forced ancestor is generated fully formed.** When the call's inclusivity is
  `NONE`, a forced ancestor's *own* required relationships still fill in (a
  `putRequired(path, someUser)` at `NONE` gives you a valid User with its required
  chain). Everything **not** on a forced path stays at the call's inclusivity —
  the rest of the graph is unaffected.
- Threaded through `XFTY_GenerationContext` next to `forcedRelationshipPaths`;
  `forRelated(field)` drops the head and carries the rest one level down. The
  relationship prefix is also folded into `forcedRelationshipPaths` so an
  *optional* step on the way is promoted.
- Applied by `XFTY_PathValueApplier` onto a copy of the master template for the
  level being generated — after `XFTY_RelationshipForcer`. A path `put` on a
  field the ancestor's Provider already sets **wins** (it removes then re-puts).

## Implementation

`XFTY_PathValue` (core) · `XFTY_PathValueApplier` (engine, after
`XFTY_RelationshipForcer`) · 5 `put` / `putRequired` / `putOptional` overloads on
`XFTY_DummySObjectProvider` taking `List<SObjectField>` · `XFTY_GenerationContext.pathValues`
+ `withPathValues` + `withInclusivity` + `forRelated` filter · `XFTY_AncestorGenerator`
adds forced heads to the generated set regardless of inclusivity and bumps a
forced ancestor's own inclusivity to `REQUIRED` when the call asked for `NONE`.
`XFTY_PathValueTest` (10, incl. a five-level deep chain at `NONE` inclusivity).

## Notes

- `includeOptional(...)` gained the same "force regardless of inclusivity, fully
  formed" behavior in the same change — one rule for both.
- Mirror on the read side is already there — `XFTY_CopyFromAncestorExpression(path)`.
- Shared ancestors:
  - `put(path, literal | strategy | contextAware)` or `putRequired(path, plainRel)`
    that would **set a value on** a shared ancestor **throws** — the shared
    record is resolved once and shared, so a per-call value has no well-defined
    meaning. Configure it with `XFTY_SharedAncestor.put(name, ...)`.
  - `putRequired(path, XFTY_SharedAncestor.get(name))` — **wiring a shared
    ancestor in** as an ancestor's relationship value — is fine. On-demand needs
    no `require()`; a declared name still does.
  - `includeOptional(...)` *through* a shared ancestor is fine (it only forces).
