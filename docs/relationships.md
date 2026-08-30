# Relationships

One of XFTY's greatest strengths is its ability to generate complete object
graphs rather than isolated records.

Instead of manually constructing every related record, Providers describe the
relationships between `SObject` types and XFTY generates them automatically.

This guide explains:

- Relationship Providers
- Relationship Inclusivity
- Cascading
- Bundles
- Navigating generated data
- Performance considerations

---

# Relationship Providers

A relationship is defined with `XFTY_DummyDefaultRelationship` and placed in
either the *required* or the *optional* slot of the Master Template.

```apex
.putRequired(
    Contact.AccountId,
    new XFTY_DummyDefaultRelationship(
        new Account(
            Description = 'Integration Test Account'
        )
    )
)
```

Whenever a Contact requires an Account, XFTY automatically creates one.

> Earlier versions used two classes, `XFTY_DummyDefaultRelationshipRequired` and
> `XFTY_DummyDefaultRelationshipOptional`. These were merged into
> `XFTY_DummyDefaultRelationship`; requiredness is now decided by the slot
> (`putRequired` vs `putOptional`), which lets one
> implementation serve both roles.

The supplied `Account` acts as an Override Template for the generated Account.

Its remaining fields continue to be populated from the Account Provider's
Master Template.

---

# Why Relationship Providers Receive an SObject

At first glance it may seem unusual that relationship providers receive an
`SObject` rather than an `SObjectType`.

```apex
new XFTY_DummyDefaultRelationship(
    new Account(...)
)
```

instead of

```apex
Account.SObjectType
```

The reason is flexibility.

The supplied record acts as an Override Template for the generated
relationship.

This allows tests and Providers to customize related records while still
benefiting from the defaults defined by the related Provider.

## Choosing a Provider variant

The related record's `SObjectType` normally identifies which Provider generates
it. When a type has several Provider variants (see
[Providers → Record Types](providers.md#record-types)), pin one with a lookup
key:

```apex
new XFTY_DummyDefaultRelationship(
    XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAccount'),
    new Account()
)
```

Without an explicit key, the Provider Lookup derives one from the override
template - matching a registered record-type key against the template's
`RecordTypeId`, and otherwise falling back to the plain type. The derived key is
computed once and reused.

---

# Required Relationships

Required relationships describe data that must exist in order for generated
records to be considered valid.

For example, if every Contact must belong to an Account, the relationship
should be marked as required.

```apex
.putRequired(
    Contact.AccountId,
    new XFTY_DummyDefaultRelationship(
        new Account()
    )
)
```

Required relationships are generated whenever relationship generation includes
required data.

---

# Optional Relationships

Optional relationships provide richer test data without making those
relationships mandatory.

```apex
.putOptional(
    Contact.OwnerId,
    new XFTY_DummyDefaultRelationship(
        new User()
    )
)
```

Optional relationships are generated only when the Provider is configured with

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.ALL)
```

---

# Choosing Required vs Optional

It can be tempting to declare every relationship as required so that generated
records are as complete as possible.

Avoid doing this.

Every required relationship increases the size of the generated object graph.

As object graphs become larger they consume more heap, require additional DML
when records are inserted, and increase test execution time.

As a rule of thumb:

- Required relationships should exist only when records cannot reasonably be
  created without them.
- Optional relationships should be used whenever relationships merely make test
  data more realistic.

Keeping the required graph as small as possible produces faster and more
focused tests.

---

# Relationship Inclusivity

Relationship generation is controlled independently of insertion.

Four levels of inclusivity are available.

| Mode | Description |
|------|-------------|
| NONE | Do not generate related records. |
| REQUIRED | Generate only required relationships. |
| ALL | Generate required and optional relationships. |
| PREVENT_CASCADE | Generate only the first level of relationships. |

---

# NONE

`NONE` disables automatic relationship generation.

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.NONE)
```

The generated records are still populated with default field values, but every
relationship becomes the responsibility of the test.

This mode provides the greatest control, but also offers the least protection
against future changes to validation rules.

---

# REQUIRED

`REQUIRED` is recommended for most tests.

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
```

Only relationships that are genuinely required are generated.

This keeps generated data relatively small while ensuring records remain valid.

---

# ALL

`ALL` generates both required and optional relationships.

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.ALL)
```

This produces the richest object graphs and is useful for integration tests or
tests that navigate complex relationship hierarchies.

Because every optional relationship may itself generate additional
relationships, this mode should be used sparingly.

---

# PREVENT_CASCADE

Relationship generation is normally recursive.

Suppose an `OpportunityLineItem` requires an `Opportunity`, and an
`Opportunity` requires an `Account`.

Using `REQUIRED` or `ALL` generates:

```text
OpportunityLineItem
└── Opportunity
    └── Account
```

Sometimes recursive relationship generation is undesirable.

Some object models naturally contain circular relationships. For example:

```text
Account
└── Primary Contact
        └── Account
```

Without intervention, each Provider would continue generating relationships
indefinitely.

`PREVENT_CASCADE` prevents this by allowing the initial Provider to create its
direct relationships while instructing every subsequently invoked Provider to
behave as though relationship inclusivity were `NONE`.

The resulting graph becomes:

```text
Account
└── Contact
```

rather than recursively expanding further.

Although this also reduces the size of generated object graphs, preventing
recursive relationship generation is its primary purpose.

---

# Cascading Relationships

Providers generate relationships recursively.

Suppose an Opportunity Line Item requires an Opportunity.

The Opportunity, in turn, requires an Account.

Generating the Opportunity Line Item therefore creates all three records.

```text
OpportunityLineItem
└── Opportunity
    └── Account
```

Each Provider remains responsible only for its own object type.

Together they cooperate to produce complete object graphs.

---

# Bundles

Every generation operation ultimately produces a
`XFTY_DummySObjectBundle`.

Bundles contain:

- the requested records
- directly related records
- indirectly related records
- the relationships between them

Think of a Bundle as the complete result of a generation operation rather than
simply a collection of records.

---

# Extracting Lists

Lists are retrieved using the field that produced them.

```apex
List<Contact> contacts =
    (List<Contact>) bundle.getList(Contact.Id);

List<Account> accounts =
    (List<Account>) bundle.getList(Contact.AccountId);
```

The same relationship field used to define the relationship is used to retrieve
the generated records.

---

# Navigating Bundles

Bundles may themselves contain additional Bundles.

```apex
XFTY_DummySObjectBundle opportunityBundle = bundle
        .getBundle(OpportunityLineItem.OpportunityId);
```

Once inside the nested Bundle, additional relationships can be explored.

```apex
List<Account> accounts = (List<Account>) opportunityBundle
        .getList(Opportunity.AccountId);
```

This makes it straightforward to inspect generated object graphs without
performing SOQL.

---

# Bundle Example

Suppose a Provider generates an Opportunity Line Item.

The resulting Bundle might look like:

```text
Bundle
│
├── OpportunityLineItem
│
└── Opportunity
     │
     └── Account
```

Every generated object is immediately available to the test.

---

# Relationship Generation and Insert Modes

Relationship generation and insertion are independent concerns.

For example:

```apex
.setInclusivity(REQUIRED)
.setInsertMode(MOCK)
```

creates the complete required object graph while assigning mock Salesforce Ids
without performing DML.

Likewise,

```apex
.setInclusivity(NONE)
.setInsertMode(NOW)
```

inserts only the explicitly requested records.

Keeping these concerns separate gives tests precise control over both the size
of generated object graphs and database interaction.

---

# Performance Considerations

Relationship generation is intentionally conservative.

Every additional relationship increases:

- object count
- heap usage
- DML (when records are inserted)
- trigger execution
- Flow execution
- overall test duration

For this reason:

- Prefer `REQUIRED` over `ALL`.
- Keep required relationships to a minimum.
- Use `PREVENT_CASCADE` when deep relationship trees are unnecessary.
- Use `NONE` only when the test intentionally wants complete control over every
  relationship.

---

# Best Practices

- Model only genuinely required relationships as required.
- Prefer optional relationships for convenience rather than validity.
- Use `REQUIRED` as the default inclusivity.
- Use `ALL` only when tests truly need richer object graphs.
- Navigate generated data using Bundles instead of additional SOQL queries.
- Keep relationship graphs shallow whenever possible.

---

# Next Steps

Now that you understand how XFTY generates object graphs, the next guide
explains how those Providers are implemented.

Topics include:

- Master Templates
- Primary Target Fields
- Provider Lookups
- Supporting new `SObject` types
- Provider registration
- Discovering required fields