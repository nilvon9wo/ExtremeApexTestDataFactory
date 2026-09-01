# Override Templates

The most common customization. An **override template** is a partially-populated
`SObject` whose values replace those the Master Template would generate. Only the
fields you set are overridden; everything else is still generated.

---

## The simplest case

```apex
Contact result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setOverrideTemplate(new Contact(FirstName = 'Alice', LastName = 'Smith'))
    .supply();
```

If the Contact Provider normally generates
`FirstName = "Contact First Name 1"`, `LastName = "Contact Last Name 1"`,
`Email = "test.contact1@example.com"`, the result is `Alice` / `Smith` /
`test.contact1@example.com` — the email is still generated.

A single override template can go straight to the constructor, which derives the
`SObjectType` (and any record-type variant) from it:

```apex
new XFTY_DummySObjectProvider(new Contact(FirstName = 'Alice'), lookup)
    .supply();
```

See [generating-records → shorthand constructors](generating-records.md#shorthand-constructors).

---

## Precedence

Customization is applied in a fixed order:

```text
Master Template  →  put(...)  →  Override Template
```

If more than one customization touches a field, **the override template wins.**

```apex
.put(Contact.FirstName, new XFTY_LiteralExpression('Generated'))
.setOverrideTemplate(new Contact(FirstName = 'Alice'))
// -> "Alice", not "Generated"
```

An override value also wins over a [context-aware expression](context-aware-values.md).

---

## Override template vs `put(...)`

| Use an override template when… | Use [`put(...)`](value-expressions.md) when… |
|--------------------------------|--------------------------------------------|
| customizing one or two records | every generated record should differ |
| supplying an exact value | replacing the *generation expression* |
| making one test more readable | generating unique values, or customizing relationships |

Override templates describe **data**; `put(...)` describes **generation**.

---

## Removing values

Sometimes the Master Template supplies a value a test deliberately does not want
— testing a validation rule, a required-field error, a partially populated
record.

```apex
.removeFromMasterTemplate(Contact.Email)
```

This removes the field's generation entirely, rather than replacing it with
another value. For relationships, use
[`excludeRelationship(...)`](per-call-relationships.md) instead.

▶ Runnable: `XFTY_Ex_OverrideTemplatesTest`

See also: [generating-records](generating-records.md) · [value-expressions](value-expressions.md)
