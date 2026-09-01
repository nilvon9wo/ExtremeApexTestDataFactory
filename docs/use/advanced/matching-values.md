# Keeping a Field Pair in Sync

A common validation-rule shape: two fields — on the same record, or on a parent
and child — must match, or one must be **derived** from the other. XFTY defines
the relationship **once**, in the Provider or on the call.

The `XFTY_CopyFrom*` classes below are just the bundled, straight-copy
implementations of [`XFTY_ContextAwareExpressionIntf` / `XFTY_DeferredExpressionIntf`](../../extend/custom-value-expressions.md).
When the second field is a *transformation* — a boolean from a date, a code
concatenated from a parent's fields, a status mirrored from a child's stage —
write your own small class against the same interface.

---

## Same record — a context-aware sibling

```apex
.put(Account.ShippingCountry, 'Germany')
.put(Account.BillingCountry, new XFTY_CopyFromSiblingExpression(Account.ShippingCountry))
```

Set `ShippingCountry` in one place (Provider default or override template);
`BillingCountry` follows. See [context-aware-values](../context-aware-values.md)
— and note the `put`-ordering rule if `ShippingCountry` is itself context-aware.

### …when it is a transformation, not a copy

```apex
.put(Contact.Description, new SiblingCountryLabel())   // "Billing: Germany"
```

```apex
@IsTest
public class SiblingCountryLabel implements XFTY_ContextAwareExpressionIntf {
    public Object get(XFTY_GenerationContext context) {
        String country = (String) context.siblingValue(Contact.MailingCountry);
        return 'Billing: ' + country;
    }
}
```

Writing and shipping one: [extend/custom-value-expressions](../../extend/custom-value-expressions.md).

---

## Parent and child — a shared ancestor plus a copied field

When many children must all carry a value that lives on their **one** shared
parent:

```apex
XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ', OwnerId = TEST_ADMIN.Id))
    .copyingRelatedField(Account.OwnerId);   // children get the Account's OwnerId, not its Id

new XFTY_DummySObjectMasterTemplate(Case.Id)
    .putRequired(Case.AccountId, XFTY_SharedAncestor.get('hq'));
```

Every `Case` now carries the shared Account's `OwnerId`. See
[shared-ancestors](../shared-ancestors.md).

---

## Child value up onto a parent

`XFTY_CopyFromDescendantExpression(childLookupField, sourceField)` copies a value *up* from
a generated child — under `DEFERRED` (or `.depthBatched()`), resolved at
`flush()`:

```apex
// on the Account Provider
.put(Account.Site, new XFTY_CopyFromDescendantExpression(Contact.AccountId, Contact.Department))
```

Any other insert mode throws — the whole graph has to exist first. See
[context-aware-values.md](../context-aware-values.md#reading-up-from-a-child) and
[roadmap/descendant-value-reads.md](../../roadmap/descendant-value-reads.md).

▶ Runnable: `XFTY_Ex_Adv_MatchingValuesTest`
