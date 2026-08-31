# Context-Aware Values

Most [value strategies](value-strategies.md) generate a field in isolation. A
**context-aware** value sees the rest of the record — a field copied from a
sibling, or from a generated parent.

`XFTY_ContextAwareValueIntf` is a separate interface from
`XFTY_DummyDefaultValueIntf` (a context-aware value has no meaningful no-argument
`get()`), but `put(...)` accepts it directly.

---

## Copy a sibling field

```apex
.put(Account.ShippingCity, 'Berlin')
.put(Account.BillingCity, new XFTY_CopyFromSibling(Account.ShippingCity))
```

`BillingCity` is filled from whatever `ShippingCity` ends up being.

---

## Copy a field from a generated ancestor

One hop — a relationship field then the field to read:

```apex
.putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
.put(Contact.Department, new XFTY_CopyFromAncestor(Contact.AccountId, Account.Site))
```

Several hops — a path of relationship fields ending in the field to read:

```apex
.put(OpportunityLineItem.Description, new XFTY_CopyFromAncestor(new List<SObjectField>{
        OpportunityLineItem.OpportunityId, Opportunity.AccountId, Account.Name
}))
```

`XFTY_CopyFromAncestor` returns `null` if any hop of the relationship was not
generated (e.g. an optional one skipped by the current inclusivity).

---

## Your own logic

Implement `XFTY_ContextAwareValueIntf` — one method:

```apex
public class IsAdultFlag implements XFTY_ContextAwareValueIntf {
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

Values are filled in two passes: plain strategies first, then context-aware
strategies **in the order they were `put(...)`**. So a context-aware value can
read any plain field, any wired lookup, and any *earlier* context-aware value.

Reading a *later* context-aware value — or a circular pair — throws a clear error
naming both fields and the `put` order that fixes it. It is never a silent
`null`. (A sibling that genuinely generated to `null` is returned as `null`; only
a not-yet-generated one throws.)

```apex
// wrong — BillingCity reads ShippingCity, but ShippingCity is put after it
.put(Account.BillingCity, new XFTY_CopyFromSibling(Account.ShippingCity))
.put(Account.ShippingCity, new XFTY_CopyFromSibling(Account.Site))   // throws at generation
```

An override-template value still wins over a context-aware strategy.

Reading a field on a generated **child** (up-flowing) is not supported — the
child does not exist when the parent is built. See
[roadmap/descendant-value-reads.md](../roadmap/descendant-value-reads.md).

---

Design rationale: [roadmap/context-aware-values.md](../roadmap/context-aware-values.md).
Writing custom strategies as a distributable extension:
[extend/custom-value-strategies.md](../extend/custom-value-strategies.md).

▶ Runnable: `XFTY_Ex_ContextAwareTest` _(pending — Pass B)_
