# Writing a Provider

A Provider teaches XFTY how to generate test data for one `SObject` type — its
default values, its relationships, and how they should be generated. Providers
are **declarative**: they describe what valid test data looks like, they do not
imperatively build records.

Related: [provider-lookups](provider-lookups.md) (registering Providers) ·
[provider-variants](provider-variants.md) (more than one Provider per type) ·
[bundled-providers](bundled-providers.md) (the three shipped Providers) ·
[custom-value-expressions](custom-value-expressions.md).

---

## The shape

A Provider implements `XFTY_DummySobjectProviderIntf`:

```apex
@IsTest
public class MyContactProvider implements XFTY_DummySobjectProviderIntf {
    public static final String DEFAULT_EMAIL_PREFIX = 'test.contact';
    public static final String DEFAULT_ACCOUNT_DESCRIPTION = 'Account for contact';

    private static final SObjectField PRIMARY_TARGET_FIELD = Contact.Id;

    private static final XFTY_DummySObjectMasterTemplate MASTER_TEMPLATE =
            new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(
                            new Account(Description = DEFAULT_ACCOUNT_DESCRIPTION)))
                    .put(Contact.Email, new XFTY_UniqueEmailExpression(DEFAULT_EMAIL_PREFIX))
                    .put(Contact.FirstName, new XFTY_IncrementingStringExpression('Contact First Name'))
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Contact Last Name'));

    public SObjectField getPrimaryTargetField() {
        return PRIMARY_TARGET_FIELD;
    }

    public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
        return MASTER_TEMPLATE;
    }

    public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
        return XFTY_DummySObjectFactory.createBundle(context, MASTER_TEMPLATE, templateSObjectList);
    }
}
```

Almost every Provider is this exact pattern. `createBundle`'s body is a one-line
forward — `XFTY_GenerationContext` bundles the Provider Lookup, insert mode, and
inclusivity so they travel as one argument; a Provider rarely inspects it.

---

## The Master Template

The declarative heart. It holds three keyed-by-`SObjectField` maps: default
values, required relationships, optional relationships. Fluent builders:

| Method | Adds |
|--------|------|
| `put(field, expression)` / `put(field, literal)` | a [value expression](../use/value-expressions.md) (a bare value is wrapped as `XFTY_LiteralExpression`) |
| `put(field,expression | literal | contextAwareExpression)` | a [context-aware value](../use/context-aware-values.md) |
| `putRequired(field, relationship)` | a required [relationship](../use/relationships.md) |
| `putOptional(field, relationship)` | an optional relationship |

`put(field, <relationship>)` (untyped) **throws** — it cannot tell required from
optional.

Keep it declarative — describe data, not algorithms. No conditional logic that
builds records by hand.

---

## Primary Target Field

Every Provider declares the field that identifies its primary records inside a
[Bundle](../use/bundles.md). For nearly every `SObject` this is `Id`:

```apex
private static final SObjectField PRIMARY_TARGET_FIELD = Contact.Id;
```

A configurable field (rather than a hard-coded `Id`) keeps the engine
independent of the few object types that identify records differently.

---

## Relationship design

For every relationship, ask: *can this object reasonably exist without the
related record?*

- **No** → `putRequired(field, new XFTY_DummyDefaultRelationship(...))`
- **Yes** → `putOptional(field, new XFTY_DummyDefaultRelationship(...))`

Prefer optional. Every required relationship enlarges every generated graph, adds
DML on insert, and slows every test. Model only genuinely-required relationships
as required.

The `SObject` passed to `XFTY_DummyDefaultRelationship` is an override template
for the generated parent; its remaining fields come from that parent's own
Provider.

---

## Discovering required fields

Creating a Provider is iterative:

1. Add the platform-required fields — required fields, Master-Detail
   relationships, mandatory lookups. Many IDEs surface these from the SObject
   describe (in Illuminated Cloud: open the generated Apex definition, search
   **Master Detail** and `Required: true`).
2. Attempt an insert, read the error, add the missing requirement, repeat —
   validation rules, Flows, triggers, and duplicate rules impose requirements
   the describe does not show.

Resist making everything required. Minimal Master Templates → smaller graphs →
faster tests.

---

## Testing a Provider

Every new Provider gets its own test class verifying: records generate; required
relationships populate; insertion succeeds where appropriate; optional
relationships behave; unique values stay unique. A failing Provider test is far
easier to diagnose than dozens of unrelated application tests failing because a
validation rule changed.

---

## Platform-specific types

- **Platform Events** — cannot be queried after publication; Providers should not
  assume record persistence.
- **`QueueSObject`** — behaves unlike ordinary relationship objects; verify
  generated data before relying on default relationship generation.

See [../reference/salesforce-considerations.md](../reference/salesforce-considerations.md).
