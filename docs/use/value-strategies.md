# Value Strategies

An [override template](override-templates.md) replaces a generated *value*. A
**value strategy** changes *how a value is generated* — for every record the
Provider produces.

---

## `put(...)` a strategy

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .put(Contact.FirstName, new XFTY_DummyDefaultValueIncrementingString('Test Contact'))
    .supplyBundle();
// -> "Test Contact 1", "Test Contact 2", "Test Contact 3", ...
```

---

## Implicit exact values

`put(...)` also accepts a bare value — anything that is not already a strategy or
a relationship is wrapped in `XFTY_DummyDefaultValueExact` automatically.

```apex
.put(Account.Type, 'Customer')
.put(Account.NumberOfEmployees, 500)
```

is exactly

```apex
.put(Account.Type, new XFTY_DummyDefaultValueExact('Customer'))
.put(Account.NumberOfEmployees, new XFTY_DummyDefaultValueExact(500))
```

This works both on Provider Master Templates and on `XFTY_DummySObjectProvider`.

---

## The bundled strategies

| Strategy | Produces |
|----------|----------|
| `XFTY_DummyDefaultValueExact` | the same value every time |
| `XFTY_DummyDefaultValueIncrementingString` | `prefix` + an incrementing suffix |
| `XFTY_DummyDefaultValueUniqueString` | guaranteed-unique strings |
| `XFTY_DummyDefaultValueUniqueStringLength` | unique strings of a fixed length |
| `XFTY_DummyDefaultValueUniqueEmail` | unique email addresses |
| `XFTY_DummyDefaultIncrementingDecimal` | incrementing decimals |

---

## Setting a value on a generated ancestor

`put` (and `putRequired` / `putOptional`) also takes a **path** —
`[rel1, ..., relN, targetField]` — to control how a field on a *generated
ancestor* is produced, for this one call, without editing that ancestor's
Provider.

The value is whatever the field forms accept — **not just an exact value**:

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)

    // an exact value
    .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace')

    // a strategy - the generated Account gets a unique name
    .put(new List<SObjectField>{ Contact.AccountId, Account.Name },
         new XFTY_DummyDefaultValueUniqueString('Acct'))

    // a context-aware value - evaluated against that ancestor
    .put(new List<SObjectField>{ Contact.AccountId, Account.Description },
         new XFTY_CopyFromSibling(Account.Name))

    // a relationship - give the ancestor its own generated parent
    .putRequired(new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
         XFTY_SharedAncestor.get('mr-smith'))

    .supply();
```

`put(path, ...)` **forces its whole path**, whatever the inclusivity — every
relationship named is generated even at the default `NONE`, and a forced
ancestor is generated fully formed (its own required relationships fill in).
Everything **not** on a named path stays at the call's inclusivity. A path field
that is not a relationship on the ancestor's Provider throws — never a silent
no-op. A path `put` wins over a value the ancestor's Provider already sets.

You **cannot** `put` a plain value *onto* a [shared ancestor](shared-ancestors.md)
— that throws; configure it with `.of(...)`. You **can** point a forced
relationship at one (as the `mr-smith` line above).

This shares the path-walk with
[`includeOptional(path)`](per-call-relationships.md#reaching-deeper--a-path).
Full detail: [../roadmap/path-scoped-values.md](../roadmap/path-scoped-values.md).

---

## Override template vs `put(...)`

| Use an [override template](override-templates.md) when… | Use `put(...)` when… |
|---------------------------------------------------------|----------------------|
| customizing one or two records | every generated record should differ |
| supplying an exact value | replacing the generation strategy |
| making one test more readable | generating unique values, or customizing relationships |

Override templates describe **data**; `put(...)` describes **generation**.

---

## Performance

An override template lets the Master Template generate a value that is then
replaced. When generating very large graphs, `put(...)` can skip generating
values that will never be used. Most tests should prefer readability.

---

## Custom strategies

Anything with real logic is a small `XFTY_ContextAwareValueIntf` (reads other
fields — see [context-aware-values](context-aware-values.md)) or a plain
`XFTY_DummyDefaultValueIntf`. Shipping one as a reusable extension:
[extend/custom-value-strategies.md](../extend/custom-value-strategies.md).

▶ Runnable: `XFTY_Ex_ValueStrategiesTest` · `XFTY_PathValueTest`

See also: [override-templates](override-templates.md) · [context-aware-values](context-aware-values.md) · [per-call-relationships](per-call-relationships.md)
