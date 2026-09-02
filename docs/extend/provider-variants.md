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

## Predicates on a flavoured key

`.matching(...)` takes any `XFTY_SObjectPredicateIntf` — a one-method interface
(`Boolean isSatisfiedBy(SObject)`). Repeated `.matching(...)` calls are an
**AND**.

**Ready-made single-field conditions** — `XFTY_FieldPredicate`:

| Factory | Matches when |
|---------|-------------|
| `equalTo(field, value)` / `notEqualTo(field, value)` | `field` == / != `value` (null-aware) |
| `greaterThan(field, value)` / `lessThan(field, value)` | numeric, `Date`/`Datetime`, else lexicographic; false if either side is null |
| `isNull(field)` / `isNotNull(field)` | `field` is / is not null |
| `inSet(field, Set<Object>)` | `field` is one of the set (null set → matches nothing) |

(`XFTY_FieldPredicate` is a thin facade — each factory wires up a purpose-built
class such as `XFTY_FieldGreaterThanPredicate` or `XFTY_FieldInSetPredicate`, and
`notEqualTo` / `isNotNull` are a negated `equalTo`. Use those classes directly if
you prefer.)

**AND / OR / NOT** — `XFTY_Predicates`, for anything beyond the implicit AND:

```apex
XFTY_FlavouredLookupKey.get(Account.SObjectType, 'strategic')
        .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
                XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
        }))
        .matching(XFTY_Predicates.negate(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')));
```

`allOf(list)` / `anyOf(list)` / `negate(one)` return an `XFTY_SObjectPredicateIntf`,
so they nest. An empty `allOf` is vacuously true; an empty `anyOf` is never
satisfied.

**Your own predicate** — when the ready-made ones do not express the condition,
implement the interface. No base class, no registration:

<!-- sketch -->
```apex
public class CreatedThisFiscalYearPredicate implements XFTY_SObjectPredicateIntf {
    public Boolean isSatisfiedBy(SObject record) {
        Date created = (Date) record?.get('CreatedDate');
        return created != null && created >= Date.today().toStartOfMonth().addMonths(-11);
    }
}
```

▶ Runnable: `XFTY_PredicatesTest` (the tree above) · `XFTY_FieldEqualToPredicateTest` / `XFTY_FieldGreaterThanPredicateTest` / `XFTY_FieldInSetPredicateTest` / `XFTY_ValueComparisonTest` (the field conditions)

---

## Define keys in one place

A flavoured key is referenced from the Provider Lookup map *and* from every
relationship that pins that variant, so define each in a shared `*LookupKeys`
constants class:

<!-- sketch -->
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

<!-- sketch -->
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
- **An explicit key *and* an override template that disagree:** if the template
  independently matches a *different* refined variant (e.g. `withVariant(PERSON_ACCOUNT)`
  with a business-record-type template), that is a contradiction and throws
  rather than silently letting the explicit key win. A template that carries no
  discriminator is fine — the explicit key stands.

Each top-level Provider still owns one Master Template, so one generation call
produces one variant. Provider-specific `createBundle` logic that inspects the
override template is no longer needed for record types.

---

## Your own lookup key

`XFTY_LookupKeyIntf` is four methods — implement it directly when a variant is
chosen by something the shipped keys don't model (a multi-field rule, a namespace
prefix, whatever). `isInstanceOf(SObject)` is what template-derived resolution
calls; `getSpecificity()` decides who wins when several keys match (return more
than `20` to outrank a flavoured key). Register the instance in the Provider map
like any other key.

<!-- sketch -->
```apex
public class WholesaleAccountKey implements XFTY_LookupKeyIntf {
    public SObjectType getSObjectType()    { return Account.SObjectType; }
    public Boolean isInstanceOf(SObject r) {
        return r?.getSObjectType() == Account.SObjectType
                && r.get('Segment__c') == 'Wholesale'
                && r.get('AnnualRevenue') != null;
    }
    public String getHashKey()             { return 'Account::wholesale'; }
    public Integer getSpecificity()        { return 30; }
}
```

---

Design record: [../roadmap/multi-variant-providers.md](../roadmap/multi-variant-providers.md).
