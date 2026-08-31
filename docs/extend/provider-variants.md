# Registering Provider Variants

A single `SObjectType` can have several Providers, chosen by a **lookup key**.
The motivating case is Business Account vs Person Account — one type, two
genuinely different Master Templates. This page is about **registering** variants;
selecting one as a consumer is [use/provider-variants](../use/provider-variants.md).

---

## The key types

| Key | Selects by | Specificity |
|-----|-----------|-------------|
| `XFTY_LookupKey.get(type)` | `SObjectType` only (the default) | 0 |
| `XFTY_RecordTypeLookupKey.get(type, developerName)` | `SObjectType` + record type | 10 |
| `XFTY_FlavouredLookupKey.get(type, [recordType,] flavour).matching(predicate)…` | `SObjectType` + optional record type + arbitrary conditions on the record | 20 + predicate count |
| your own `XFTY_LookupKeyIntf` | anything | you choose |

All keys are flyweights — obtain with `.get(...)`, never `new`. A
`XFTY_FlavouredLookupKey` is interned by type + record type + flavour (its
predicates are *not* part of its identity); add its predicates with
`.matching(...)` **once**.

---

## Define keys in one place

A flavoured key is referenced from the Provider Lookup map *and* from every
relationship that pins that variant, so define each in a shared `*LookupKeys`
constants class:

```apex
@IsTest
public class MyProjectLookupKeys {
    public static final XFTY_LookupKeyIntf ENTERPRISE_ACCOUNT =
            XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise')
                    .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 1000));
    public static final XFTY_LookupKeyIntf PERSON_ACCOUNT =
            XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAccount');
}
```

```apex
private static final Map<XFTY_LookupKeyIntf, Type> PROVIDERS = new Map<XFTY_LookupKeyIntf, Type>{
    XFTY_LookupKey.get(Account.SObjectType) => BusinessAccountProvider.class,
    MyProjectLookupKeys.PERSON_ACCOUNT      => PersonAccountProvider.class,
    MyProjectLookupKeys.ENTERPRISE_ACCOUNT  => EnterpriseAccountProvider.class
};
```

---

## Resolution

- **Explicit:** `lookup.get(someKey)`.
- **Top-level generation** picks a variant via `withVariant(key)`, the
  lookup-key constructor, or an override template carrying a record type — see
  [use/provider-variants](../use/provider-variants.md).
- **A relationship with an explicit key:**
  `new XFTY_DummyDefaultRelationship(MyProjectLookupKeys.PERSON_ACCOUNT, new Account())`.
- **A relationship with only an override template:**
  `XFTY_ProviderLookups.resolve` collects every registered key whose
  `isInstanceOf(template)` is true and picks the most specific; the plain type
  key is the fallback. Two equally-specific matches is an error — supply an
  explicit key. `XFTY_RecordTypeLookupKey` matches the template's `RecordTypeId`
  from the describe (no SOQL). The derived key is memoised on the relationship.

Each top-level Provider still owns one Master Template, so one generation call
produces one variant. Provider-specific `createBundle` logic that inspects the
override template is no longer needed for record types.

Design record: [../roadmap/multi-variant-providers.md](../roadmap/multi-variant-providers.md).
