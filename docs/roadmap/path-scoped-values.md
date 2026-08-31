# Roadmap: Path-Scoped Value Overrides

Status: **📋 proposed** (Brian's idea, 2026-08-31).

`includeOptional(List<SObjectField>)` already walks a path of relationship fields
into the generated ancestors to force each step required, for one call. The same
path mechanism could set **how a field on an ancestor is generated**, for one
call — without writing or editing that ancestor's Provider.

```apex
// Today: to change the generated Pricebook's Name you edit the Pricebook Provider,
// or pass an override template through a relationship template.
//
// Proposed:
new XFTY_DummySObjectProvider(Opportunity.SObjectType, lookup)
    .includeOptional(new List<SObjectField>{ Opportunity.Pricebook2Id })
    .put(
        new List<SObjectField>{ Opportunity.Pricebook2Id, Pricebook2.Name },
        new XFTY_DummyDefaultValueExact('Q3 Enterprise Pricebook')
    )
    .supply();
// -> the Opportunity's generated Pricebook2 has Name = 'Q3 Enterprise Pricebook'
```

The last field in the path is the target field; everything before it is the
relationship walk (same as `includeOptional`). The value can be any
`XFTY_DummyDefaultValueIntf` / `XFTY_ContextAwareValueIntf` / literal that plain
`put` accepts.

## Open questions

- **Does it force the path required, or only apply when the path is generated?**
  `includeOptional(path)` forces. A separate `put(path, value)` that *also*
  forces would surprise; one that only applies when the relationship is already
  generated is safer but needs the caller to also `includeOptional` it. Probably:
  `put(path, value)` does **not** force — pair it with `includeOptional` when you
  need the ancestor generated.
- **Multiple values on the same ancestor** — `put(path, ...)` twice with paths
  that share a prefix should land on the *same* generated ancestor instance, not
  two. The engine already generates one ancestor per relationship per row, so
  this is a matter of threading the path overrides into that single build.
- **Interaction with a relationship template** (`putRequired(field, new
  XFTY_DummyDefaultRelationship(new Pricebook2(Name = ...)))`). The template and
  a path `put` on the same field/ancestor both set values — one must win
  (path `put` last-wins seems right, matching override-template precedence).
- **Reads too?** Symmetric idea: `put(field, XFTY_CopyFromAncestor(path))`
  already reads down a path. A path-scoped *write* is the mirror.

## Relation to other work

- Parallels [descendant-value-reads.md](descendant-value-reads.md) (up-flowing
  reads) — this is a down-reaching write.
- Shares the path-walk engine with `includeOptional(List<SObjectField>)` in
  [../use/per-call-relationships.md](../use/per-call-relationships.md).
