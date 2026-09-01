# Per-Call Relationship Exceptions

[Inclusivity](relationships.md#inclusivity) is one setting for the whole call.
When a single test needs **one exception** — generate a particular optional
relationship, or skip one that would otherwise be generated — override it per
relationship on the `XFTY_DummySObjectProvider` instance.

---

## The simplest case

```apex
new XFTY_DummySObjectProvider(Opportunity.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .includeOptional(Opportunity.Pricebook2Id)   // generate this optional one too
    .excludeRelationship(Opportunity.OwnerId);    // do not generate this one
```

- **`includeOptional(field)`** generates one named relationship for this call,
  **whatever the inclusivity** — including the default `NONE` — and generates it
  *fully formed* (its own required relationships fill in). Everything not named
  stays at the call's inclusivity. Throws during generation if `field` is not a
  relationship on the Provider it resolves to.
- **`excludeRelationship(field)`** makes one relationship — required or
  optional — non-existent for this call: not generated, not attached, not left
  as an orphan reference. Throws if `field` is not a relationship (use
  [`removeFromMasterTemplate(...)`](override-templates.md#removing-values) for
  plain value fields).

Both act only on the instance they are called on — a different Provider using the
same Master Template still generates the relationship. `includeOptional` is
applied to a per-call copy of the Master Template, so it is order-independent;
call `excludeRelationship` before any `put(...)` (same ordering rule as
[`withVariant`](provider-variants.md)).

---

## Reaching deeper — a path

`includeOptional` also takes a **path** of relationship fields, forcing every
step for this call only:

```apex
new XFTY_DummySObjectProvider(Opportunity.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .includeOptional(new List<SObjectField>{ Opportunity.Pricebook2Id, Pricebook2.OwnerId });
```

generates the Opportunity's Pricebook (optional) **and** that Pricebook's Owner
(optional), leaving everything else at `REQUIRED`. Each step must be a
relationship on the Provider it resolves to; an unknown step throws during
generation. Whether a step is a plain relationship or a
[shared ancestor](shared-ancestors.md) makes no difference.
`includeOptional(field)` is shorthand for the one-element path.

---

## Setting a *value* on a generated ancestor

The same path walk also sets **how a field on an ancestor is generated** —
`put(path, value)`, where the value is an exact value, a strategy, a
context-aware value, or a relationship. That is a value concern, so it lives
with the other `put` forms:
[value-strategies → setting a value on a generated ancestor](value-strategies.md#setting-a-value-on-a-generated-ancestor).

▶ Runnable: `XFTY_Ex_PerCallRelationshipsTest` · `XFTY_PathValueTest`

See also: [relationships](relationships.md) · [provider-variants](provider-variants.md)
