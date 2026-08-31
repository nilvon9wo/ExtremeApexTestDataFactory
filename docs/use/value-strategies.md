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

▶ Runnable: `XFTY_Ex_ValueStrategiesTest` _(pending — Pass B)_

See also: [override-templates](override-templates.md) · [context-aware-values](context-aware-values.md)
