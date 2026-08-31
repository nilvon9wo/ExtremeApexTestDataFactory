# Provider Lookups

A [Provider](providers.md) knows *what* type it generates. A **Provider Lookup**
knows *which Provider* generates a given type (or variant). **Every project writes
its own** — a small class holding a complete, explicit map of lookup key →
Provider.

Why yours and not one XFTY ships:

- editing a class XFTY ships makes upgrades painful;
- in a multi-package org a lookup can only reference Providers that compile in
  its own context — which is the whole reason Providers resolve through an
  interface rather than one global registry.

---

## The pattern

`XFTY_ProviderLookups` supplies the mechanics, so your class is a few one-liners:

```apex
@IsTest
public class MyProjectLookup implements XFTY_DummySObjectProviderLookupIntf {
    private static final Map<XFTY_LookupKeyIntf, Type> PROVIDERS = new Map<XFTY_LookupKeyIntf, Type>{
        XFTY_LookupKey.get(Account.SObjectType)                         => MyAccountProvider.class,
        XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAcct') => MyPersonAccountProvider.class,
        XFTY_LookupKey.get(Contact.SObjectType)                         => MyContactProvider.class
    };
    private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> cache =
            new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

    public XFTY_DummySobjectProviderIntf get(SObjectType t)          { return XFTY_ProviderLookups.get(PROVIDERS, cache, XFTY_LookupKey.get(t)); }
    public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf key) { return XFTY_ProviderLookups.get(PROVIDERS, cache, key); }
    public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj)             { return XFTY_ProviderLookups.keysFor(PROVIDERS.keySet(), sObj); }
}
```

- Each registered Provider class needs a public no-arg constructor. For Providers
  that need constructor arguments, use
  `XFTY_ProviderLookups.of(Map<key, providerInstance>)`.
- `XFTY_ProviderLookups.ofTypes(map)` / `of(map)` also wrap a complete map
  directly for quick or in-test use.
- Lookup keys compare by value (`getHashKey()`), so they work as `Map` keys
  directly. Obtain them with `.get(...)`, never `new`.

`XFTY_DefaultSObjectProviderLookup` is exactly this pattern with XFTY's own three
Providers — the framework uses it for its self-tests, and it is the class to copy
as a starting point.

---

## The three methods

| Method | Returns |
|--------|---------|
| `get(SObjectType)` | the Provider for the plain type |
| `get(XFTY_LookupKeyIntf)` | the Provider for a specific variant |
| `keysFor(SObject)` | every registered key the record matches (a record can match more than one) |

`XFTY_ProviderLookups.resolve(lookup, sObj)` turns a `keysFor` match set into the
single most-specific key.

---

## The compilation boundary

A Provider Lookup is also a compile boundary. Different `SObject` types often live
in different unlocked or managed packages; referencing a type that is
unavailable in the current package fails compilation even if that Provider would
never run. Each package registers only the Providers valid in its context, so
XFTY can be shared across packages without cross-package compile dependencies.

---

Registering more than one Provider per type (record types, flavours):
[provider-variants](provider-variants.md).
