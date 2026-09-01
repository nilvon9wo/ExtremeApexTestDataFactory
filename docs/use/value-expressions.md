# Value Expressions

An [override template](override-templates.md) replaces a generated *value*. A
**value expression** changes *how a value is generated* — for every record the
Provider produces.

---

## `put(...)` an expression

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .put(Contact.FirstName, new XFTY_IncrementingStringExpression('Test Contact'))
    .supplyBundle();
// -> "Test Contact 1", "Test Contact 2", "Test Contact 3", ...
```

---

## Implicit exact values

`put(...)` also accepts a bare value — anything that is not already an expression or a relationship is wrapped in `XFTY_LiteralExpression` automatically.

```apex
.put(Account.Type, 'Customer')
.put(Account.NumberOfEmployees, 500)
```

is exactly

```apex
.put(Account.Type, new XFTY_LiteralExpression('Customer'))
.put(Account.NumberOfEmployees, new XFTY_LiteralExpression(500))
```

This works both on Provider Master Templates and on `XFTY_DummySObjectProvider`.

---

## The bundled expressions

| Expression | Produces |
|----------|----------|
| `XFTY_LiteralExpression` | the same value every time |
| `XFTY_IncrementingStringExpression` | `prefix` + an incrementing suffix |
| `XFTY_UniqueStringExpression` | guaranteed-unique strings |
| `XFTY_UniqueStringOfLengthExpression` | unique strings of a fixed length |
| `XFTY_UniqueEmailExpression` | unique email addresses |
| `XFTY_IncrementingDecimalExpression` | incrementing decimals |

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

    // an expression - the generated Account gets a unique name
    .put(new List<SObjectField>{ Contact.AccountId, Account.Name },
         new XFTY_UniqueStringExpression('Acct'))

    // a context-aware value - evaluated against that ancestor
    .put(new List<SObjectField>{ Contact.AccountId, Account.Site },
         new XFTY_CopyFromSiblingExpression(Account.Name))

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
— that throws; shape it where it is registered
(`XFTY_SharedAncestor.put('hq', …).put(field, …)`). You **can** point a forced
relationship at one (as the `mr-smith` line above).

This shares the path-walk with
[`includeOptional(path)`](per-call-relationships.md#reaching-deeper--a-path).
Full detail: [../roadmap/path-scoped-values.md](../roadmap/path-scoped-values.md).

---

## Override template vs `put(...)`

| Use an [override template](override-templates.md) when… | Use `put(...)` when… |
|---------------------------------------------------------|----------------------|
| customizing one or two records | every generated record should differ |
| supplying an exact value | replacing the generation expression |
| making one test more readable | generating unique values, or customizing relationships |

Override templates describe **data**; `put(...)` describes **generation**.

---

## Performance

An override template lets the Master Template generate a value that is then
replaced. When generating very large graphs, `put(...)` can skip generating
values that will never be used. Most tests should prefer readability.

---

## Custom expressions

Anything with real logic is a small `XFTY_ContextAwareExpressionIntf` (reads other
fields — see [context-aware-values](context-aware-values.md)) or a plain
`XFTY_ValueExpressionIntf`. Shipping one as a reusable extension:
[extend/custom-value-expressions.md](../extend/custom-value-expressions.md).

▶ Runnable: `XFTY_Ex_ValueExpressionsTest` · `XFTY_PathValueTest`

See also: [override-templates](override-templates.md) · [context-aware-values](context-aware-values.md) · [per-call-relationships](per-call-relationships.md)
