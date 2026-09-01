# Context-Aware Values

Most [value expressions](value-expressions.md) generate a field in isolation. A
**context-aware** value sees the rest of the record — a field copied from a
sibling, from a generated parent, or (under `DEFERRED`) from a generated child.

`XFTY_ContextAwareExpressionIntf` is a separate interface from
`XFTY_ValueExpressionIntf` (a context-aware value has no meaningful no-argument
`get()`), but `put(...)` accepts it directly.

---

## Copy a sibling field

```apex
.put(Account.ShippingCity, 'Berlin')
.put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
```

`BillingCity` is filled from whatever `ShippingCity` ends up being.

---

## Copy a field from a generated ancestor

One hop — a relationship field then the field to read:

```apex
.putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
.put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Site))
```

Several hops — a path of relationship fields ending in the field to read:

```apex
.put(OpportunityLineItem.Description, new XFTY_CopyFromAncestorExpression(new List<SObjectField>{
        OpportunityLineItem.OpportunityId, Opportunity.AccountId, Account.Name
}))
```

`XFTY_CopyFromAncestorExpression` returns `null` if any hop of the relationship was not
generated (e.g. an optional one skipped by the current inclusivity).

---

## Your own logic

Implement `XFTY_ContextAwareExpressionIntf` — one method:

```apex
public class IsAdultFlag implements XFTY_ContextAwareExpressionIntf {
    public Object get(XFTY_GenerationContext context) {
        Date birthdate = (Date) context.siblingValue(Contact.Birthdate);
        return birthdate != null && birthdate.addYears(18) <= Date.today();
    }
}
```

```apex
.put(Contact.Birthdate, Date.newInstance(2000, 1, 1))
.put(Contact.Description, new IsAdultFlag())
```

`context` exposes:

- **`siblingValue(field)`** — the final value of another field on this record.
  Prefer this over `context.recordBeingBuilt.get(field)`: it returns the same
  value but throws a clear error if `field` is another context-aware value that
  has not been generated yet, instead of handing back a misleading `null`.
- **`bundleSoFar`** — everything this generation call has built: the generated
  parents (`getList(relationshipField)`) **and** the sibling primary records
  (`getList(<primaryField>)`, e.g. `getList(Account.Id)`).
- **`rowIndex`** — which row of a multi-record generation this is.

---

## How it runs, and the one ordering rule

Values are filled in two passes: plain expressions first, then context-aware
  expressions **in the order they were `put(...)`**. So a context-aware value can
read any plain field, any wired lookup, and any *earlier* context-aware value.

Reading a *later* context-aware value — or a circular pair — throws a clear error
naming both fields and the `put` order that fixes it. It is never a silent
`null`. (A sibling that genuinely generated to `null` is returned as `null`; only
a not-yet-generated one throws.)

```apex
// wrong — BillingCity reads ShippingCity, but ShippingCity is put after it
.put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
.put(Account.ShippingCity, new XFTY_CopyFromSiblingExpression(Account.Site))   // throws at generation
```

An override-template value still wins over a context-aware expression.

---

## Reading up from a child

`XFTY_CopyFromDescendantExpression` copies a field from a generated **child** — the record
that references this one through the given lookup field:

```apex
// on an Account Provider, so a validation rule comparing the two passes
.put(Account.Site, new XFTY_CopyFromDescendantExpression(Contact.AccountId, Contact.Department))
```

The child does not exist when the parent is built, so this needs the whole graph
in memory first: **it only works under `DEFERRED` (or `.depthBatched()`)** and is
resolved when `XFTY_DeferredInserter.flush()` runs. A Provider that carries one
of these in any other insert mode **throws** — it does not silently leave the
field `null`.

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)   // Contact pulls in the Account
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supply();
XFTY_DeferredInserter.flush();   // the Account's Site is filled here
```

Works whether the child is a generated ancestor's requesting child or one of a
parent's `withChildren` rows. With more than one matching child the **first** is
read; with none, the value is `null`. Multi-hop paths and aggregates across
children are not built — see
[roadmap/descendant-value-reads.md](../roadmap/descendant-value-reads.md).

---

Design rationale: [roadmap/context-aware-values.md](../roadmap/context-aware-values.md).
Writing custom expressions as a distributable extension:
[extend/custom-value-expressions.md](../extend/custom-value-expressions.md).

▶ Runnable: `XFTY_Ex_ContextAwareTest`
