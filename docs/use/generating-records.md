# Generating Records

The three `supply*()` methods and the ways to ask for more than one record.

---

## One record

```apex
Contact result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .supply();
```

By default: one record, not inserted, no related records, default values filled.

---

## Which supply method?

Every Provider produces a [Bundle](bundles.md); the supply methods pull data out
of it.

| Method | Returns |
|--------|---------|
| `supply()` | the first generated primary record |
| `supplyList()` | all primary records |
| `supplyBundle()` | the whole generated object graph |

Use `supply()` / `supplyList()` when the test only needs the requested records;
`supplyBundle()` when it needs related records too.

---

## Many copies of one template

```apex
List<Contact> results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setQuantityPerTemplate(5)
    .supplyList();
```

---

## Different values per record

```apex
List<Contact> results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setOverrideTemplateList(new List<Contact>{
        new Contact(FirstName = 'Alice'),
        new Contact(FirstName = 'Bob')
    })
    .supplyList();
```

Each template inherits its remaining values from the Master Template.

### Combining the two

`setQuantityPerTemplate(2)` with a two-template list produces four records, and
quantity is applied **outside** the template loop:

```text
Alice, Bob, Alice, Bob        (not Alice, Alice, Bob, Bob)
```

---

## Shorthand constructors

Three overloads save a call for the common starting points:

```apex
// from a template — derives the SObjectType (and any record-type variant) from it
new XFTY_DummySObjectProvider(new Contact(FirstName = 'Alice'), lookup);

// from a list of templates — derives the SObjectType from the first
new XFTY_DummySObjectProvider(new List<Contact>{ new Contact(), new Contact() }, lookup);

// from a lookup key — derives the SObjectType from the key and pins that variant
new XFTY_DummySObjectProvider(XFTY_LookupKey.get(Contact.SObjectType), lookup);
```

They are exactly equivalent to the `(SObjectType, lookup)` constructor followed
by `setOverrideTemplate(...)` / `setOverrideTemplateList(...)` /
`withVariant(...)`. Lookup keys and variants: [provider-variants](provider-variants.md).

---

## Going further

This page is only the "how many, from what template" part. The rest of what a
Provider call can do, each on its own page:

| You want to… | Page |
|---|---|
| control the field values (expressions, overrides, precedence) | [value-expressions](value-expressions.md), [override-templates](override-templates.md) |
| derive a value from a sibling, an ancestor, or a child | [context-aware-values](context-aware-values.md) |
| generate the **parent** records a record needs (and how deep) | [relationships](relationships.md) |
| force or exclude a specific relationship for this one call | [per-call-relationships](per-call-relationships.md) |
| generate **child** records hanging below the primaries | [child-records](child-records.md) |
| share **one** parent across many generated records | [shared-ancestors](shared-ancestors.md) |
| pick a record-type or other Provider variant | [provider-variants](provider-variants.md) |
| choose whether/when records are inserted (`MOCK` / `NOW` / …) | [insert-modes](insert-modes.md) |
| build a graph across several calls and insert it once | [deferred-insert](deferred-insert.md) |
| read every generated record back without SOQL | [bundles](bundles.md) |
| a test-context `User` (admin, or by profile / role) | [test-user-helpers](test-user-helpers.md) |

Combinations of these are worked in [advanced/](advanced/).

▶ Runnable: `XFTY_Ex_GeneratingRecordsTest`

See also: [override-templates](override-templates.md) · [insert-modes](insert-modes.md) · [bundles](bundles.md)
