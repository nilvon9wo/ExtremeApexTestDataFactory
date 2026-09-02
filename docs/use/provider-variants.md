# Choosing a Provider Variant

A single `SObjectType` can have several Providers — Business Account vs Person
Account, or arbitrary "flavours" a project defines. This page is about
**selecting** one as a consumer. **Registering** variants is an *extend* task —
[extend/provider-variants.md](../extend/provider-variants.md).

A variant is identified by a **lookup key** the project exposes, usually as a
constant:

<!-- sketch -->
```apex
MyProjectLookupKeys.PERSON_ACCOUNT   // an XFTY_LookupKeyIntf
```

---

## Three ways to pick one

### `withVariant(key)`

<!-- sketch -->
```apex
new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .withVariant(MyProjectLookupKeys.PERSON_ACCOUNT)
    .supply();
```

Must be called **before** any `put(...)` — the Master Template is derived from
the resolved Provider (it throws otherwise).

### The lookup-key constructor

<!-- sketch -->
```apex
new XFTY_DummySObjectProvider(MyProjectLookupKeys.PERSON_ACCOUNT, lookup)
    .supply();
```

Same effect as `withVariant`, and takes the `SObjectType` from the key.

### An override template that carries a record type

<!-- sketch -->
```apex
new XFTY_DummySObjectProvider(new Account(RecordTypeId = personRtId), lookup)
    .supply();
```

XFTY matches the template's `RecordTypeId` against the registered record-type
keys (resolved from the describe, no SOQL) and selects the matching Provider
automatically.

Don't combine the two: `withVariant(key)` *and* an override template that carries
a conflicting record type (or otherwise matches a different registered variant)
throws. Pick one.

---

## For a related record

When a relationship should generate a specific variant of its parent, pin it on
the relationship:

<!-- sketch -->
```apex
.putRequired(Case.AccountId, new XFTY_DummyDefaultRelationship(
        MyProjectLookupKeys.PERSON_ACCOUNT, new Account()))
```

Without an explicit key, the parent's variant is derived from the override
template the relationship carries.

▶ Runnable: `XFTY_Ex_ProviderVariantsTest` (flavour keys) · `XFTY_RecordTypeRealRtTest` (record types, org-only)

See also: [extend/provider-variants](../extend/provider-variants.md) · [relationships](relationships.md)
