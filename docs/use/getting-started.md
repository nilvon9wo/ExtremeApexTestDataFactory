# Getting Started

This guide introduces the core concepts of XFTY and demonstrates the most common ways of generating test data.

After reading this guide you should be comfortable:

- generating records
- customizing individual fields
- creating related records
- understanding Bundles
- choosing insert modes
- deciding when relationships should be created

More advanced topics such as implementing Providers and writing custom value expressions are covered in later guides.

---

# Creating Your First Record

The simplest way to use XFTY is to request an object from a Provider.

```apex
XFTY_DefaultSObjectProviderLookup providerLookup = new XFTY_DefaultSObjectProviderLookup();

Contact contact = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
    .supply();
```

This creates a single `Contact`.

By default:

- one object is generated
- no records are inserted
- no related records are generated
- default values are supplied automatically

The returned object is immediately ready for use in your test.

---

# Providers

A Provider is responsible for generating test data for a particular `SObject` type.

For example:

- a `Contact` Provider knows how to create Contacts
- an `Account` Provider knows how to create Accounts
- an `Opportunity` Provider knows how to create Opportunities

Tests never need to know *how* these objects are constructed. They simply request the object type they need.

Internally, Providers use centrally-defined Master Templates to populate required fields and relationships.

---

# Provider Lookups

A Provider only knows *what* type of object you want.

A Provider Lookup knows *which Provider* should be used to generate it.

```apex
XFTY_DefaultSObjectProviderLookup providerLookup = new XFTY_DefaultSObjectProviderLookup();

XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup);
```

Separating Providers from Provider Lookups allows applications to register different Provider implementations without modifying the framework itself.

Many projects simply create a single lookup implementation containing every supported `SObject`.
However, when using SFDX packages, it may be desirable -- or even necessary -- to create separate Lookup files for each package.

---

# Override Templates

Most tests only care about one or two fields.

Instead of constructing an entire record, provide an Override Template containing only the values relevant to your test.

```apex
Contact contact = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
    .setOverrideTemplate(new Contact(
            FirstName = 'Alice',
            LastName = 'Smith'
        ))
    .supply();
```

XFTY preserves the supplied values while generating everything else automatically.

For example, if the Master Template specifies a default email address, that value will still be generated.

If the Override Template specifies an email address, the Override Template always wins.

---

# Shorthand Constructors

Three constructor overloads save a call for the most common starting points:

```apex
// from a template — derives the SObjectType (and any record-type variant) from it
new XFTY_DummySObjectProvider(new Contact(FirstName = 'Alice'), providerLookup);

// from a list of templates — derives the SObjectType from the first
new XFTY_DummySObjectProvider(new List<Contact>{ new Contact(), new Contact() }, providerLookup);

// from a lookup key — derives the SObjectType from the key and pins that variant
new XFTY_DummySObjectProvider(XFTY_LookupKey.get(Contact.SObjectType), providerLookup);
```

They are exactly equivalent to the `(SObjectType, lookup)` constructor followed
by `setOverrideTemplate(...)` / `setOverrideTemplateList(...)` / `withVariant(...)`.
Lookup keys and variants are covered in [provider-variants](provider-variants.md).

---

# Generating Multiple Records

There are two ways to create multiple records.

The simplest is to specify a quantity.

```apex
List<Contact> contacts = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
        .setQuantityPerTemplate(5)
        .supplyList();
```

This generates five Contacts using the same template.

If each generated record should differ, use an Override Template List instead.

```apex
List<Contact> contacts = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
        .setOverrideTemplateList(new List<Contact>{
            new Contact(FirstName='Alice'),
            new Contact(FirstName='Bob')
        })
        .supplyList();
```

When both a quantity and an Override Template List are supplied, every template is generated the requested number of times.

---

# Creating Related Records

Relationship generation is controlled independently from persistence.

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
        .setInsertMode(XFTY_InsertModeEnum.MOCK)
        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        .supplyBundle();
```

The resulting Bundle contains both the requested Contacts and any related records generated during the operation.

```apex
Contact contact = (Contact) bundle.getList(Contact.Id)[0];
Account account = (Account) bundle.getList(Contact.AccountId)[0];
```

```text
Bundle
├── Contact
└── Account
```

The generated Contact automatically references the generated Account.

---

# Understanding Bundles

Bundles are the primary data structure returned by XFTY.

Rather than returning only the requested records, Bundles contain the entire object graph created during generation.

For example, generating an `OpportunityLineItem` may also generate:

```text
OpportunityLineItem
└── Opportunity
    └── Account
```

Bundles make every generated object available without requiring additional SOQL queries.

Lists are extracted using the relationship field that produced them.

```apex
List<Account> accounts = (List<Account>) bundle.getList(Opportunity.AccountId);
```

Nested Bundles can also be traversed.

```apex
XFTY_DummySObjectBundle opportunityBundle = bundle.getBundle(OpportunityLineItem.OpportunityId);
```

---

# Insert Modes

Generating objects and inserting objects are separate concerns.

XFTY supports six insert modes.

| Mode | Description |
|------|-------------|
| NEVER | Generate records without Ids. |
| MOCK | Generate realistic Salesforce Ids without DML. |
| RELATED_ONLY | Insert only related records. |
| NOW | Insert every generated record. |
| LATER | Behaves like NEVER while documenting that insertion will happen later. |
| DEFERRED | Generate like NEVER over many calls; `XFTY_DeferredInserter.flush()` inserts them all at once. |

For most tests:

| Test type | Recommended mode |
|------------|-----------------|
| Unit Test | MOCK |
| Integration Test | NOW |

Because generated mock Ids are not valid Salesforce records, tests should never attempt to perform DML on objects created with `MOCK`.

---

# Relationship Inclusivity

Relationship generation is controlled independently from insertion.

| Mode | Description |
|------|-------------|
| NONE | Create no related records. |
| REQUIRED | Create only required relationships. |
| ALL | Create required and optional relationships. |
| PREVENT_CASCADE | Create only the first level of relationships. |

`REQUIRED` is recommended for most tests.

It produces enough related data for records to be valid without generating unnecessary object graphs.

---

# Which Supply Method Should I Use?

Every Provider ultimately generates a Bundle.

The convenience methods simply extract data from that Bundle.

| Method | Returns |
|---------|---------|
| `supply()` | First generated record |
| `supplyList()` | Primary generated records |
| `supplyBundle()` | Entire generated object graph |

If your test only needs the requested records, `supply()` or `supplyList()` are usually sufficient.

If your test needs to inspect related records, use `supplyBundle()`.

---

# Next Steps

Now that you understand the basic workflow, each feature has its own page — see
the [feature matrix](README.md).

- [override-templates](override-templates.md) · [value-expressions](value-expressions.md) · [context-aware-values](context-aware-values.md) — customizing generated data
- [relationships](relationships.md) · [per-call-relationships](per-call-relationships.md) · [shared-ancestors](shared-ancestors.md) · [bundles](bundles.md) — object graphs
- [insert-modes](insert-modes.md) · [deferred-insert](deferred-insert.md) — persistence
- [advanced/](advanced/) — combining features

To teach XFTY about a new `SObject` type, see [extend/providers](../extend/providers.md).
Platform behaviours that constrain XFTY (notably `@TestSetup`) are in
[reference/salesforce-considerations](../reference/salesforce-considerations.md).