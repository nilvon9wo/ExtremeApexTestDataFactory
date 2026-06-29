# XFTY (Extreme Apex Test Data Factory)

XFTY is a flexible test data generation library for Salesforce Apex.

Instead of every test manually constructing valid `SObject`s (and their required related records), XFTY lets you describe only the data your test actually cares about. It generates everything else using centrally-defined defaults.

Tests stay concise, validation rule changes become far easier to accommodate, and common test data logic is defined in one place instead of being duplicated throughout your codebase.

---

# Why XFTY?

As Salesforce projects grow, so does the amount of code required just to create valid test data.

A simple `Contact` may require an `Account`. Later, a validation rule means the `Account` also requires additional fields or related records. Over time, hundreds or thousands of tests can end up duplicating nearly identical setup code.

XFTY centralises that knowledge.

Instead of every test knowing how to create a valid `Contact`, the library does. Individual tests override only the fields they actually care about.

Some additional goals of XFTY include:

* Centralised test data definitions
* Minimal boilerplate in tests
* Configurable relationship creation
* Support for both integration tests and true unit tests
* Mock Id generation without touching the database
* Extensible architecture for supporting additional `SObject` types

---

# Quick Start

The simplest use case is to request an object from a provider.

```apex
XFTY_DefaultSObjectProviderLookup DEFAULT_SOBJECT_PROVIDER = new XFTY_DefaultSObjectProviderLookup();
XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER);
Contact contact = (Contact) provider.supply();
```

By default:

* one object is created
* no database operations are performed
* no related records are created
* all required default values are supplied automatically

---

# Customising Individual Records

Tests usually only care about a few fields.

Rather than constructing a complete `Contact`, simply provide an override template containing the fields you care about.

```apex
Contact contact = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER)
        .setOverrideTemplate(new Contact(FirstName = 'Fred'))
        .setInsertMode(XFTY_InsertModeEnum.MOCK)
        .supply();
```

XFTY preserves the supplied values while automatically generating any remaining required data.

---

# Creating Related Records

Relationship generation is controlled independently of persistence.

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType,DEFAULT_SOBJECT_PROVIDER)
        .setInsertMode(XFTY_InsertModeEnum.MOCK)
        .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
        .supplyBundle();

Contact contact = (Contact) bundle.getList(Contact.Id)[0];
Account account = (Account) bundle.getList(Contact.AccountId)[0];

System.assertEquals(account.Id, contact.AccountId);
```

The returned `XFTY_DummySObjectBundle` contains both the primary objects and every related object generated during creation.

Nested bundles allow navigation through deeper relationship hierarchies when required.

---

# Insert Modes

XFTY separates object generation from persistence.

| Mode           | Behaviour                                                              |
| -------------- | ---------------------------------------------------------------------- |
| `NEVER`        | Create objects without Ids.                                            |
| `MOCK`         | Generate realistic mock Ids without performing DML.                    |
| `RELATED_ONLY` | Persist only related records.                                          |
| `NOW`          | Persist all generated records.                                         |
| `LATER`        | Behaves like `NEVER`, while documenting the intention to insert later. |

This makes it equally suitable for integration-style tests and isolated unit tests.

---

# Relationship Inclusivity

Relationship generation is independently configurable.

| Mode              | Behaviour                                        |
| ----------------- | ------------------------------------------------ |
| `NONE`            | Do not create related records.                   |
| `REQUIRED`        | Create only required relationships.              |
| `ALL`             | Create both required and optional relationships. |
| `PREVENT_CASCADE` | Create only the first level of relationships.    |

Because relationships are generated recursively, XFTY can automatically build complete object graphs while still allowing tests to control how much data is created.

---

# Advanced Customisation

Sometimes you want to change how records are generated rather than simply overriding individual field values.

The `put(...)` methods allow you to replace the default generation strategy for individual fields.

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER)
        .setQuantityPerTemplate(2)
        .setInsertMode(XFTY_InsertModeEnum.MOCK)
        .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
        .put(Contact.FirstName, new XFTY_DummyDefaultValueIncrementingString('Test'))
        .put(Contact.AccountId, new XFTY_DummyDefaultRelationshipRequired(
                new Account(Description = 'Integration Test Account')
        ))
        .supplyBundle();
```

This example:

* generates two `Contact` records
* gives each an incrementing first name
* automatically creates an `Account` for each contact
* customises the generated `Account`
* assigns mock Ids without performing any database operations

Several default value strategies are included, including exact values, incrementing strings and unique email generation. Additional strategies can be added simply by implementing `XFTY_DummyDefaultValueIntf`.

---

# Reading Generated Data

When `supplyBundle()` is used, generated data is organised by relationship.

```apex
List<Contact> contacts = (List<Contact>) bundle.getList(Contact.Id);
List<Account> accounts = (List<Account>) bundle.getList(Contact.AccountId);
XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
```

This makes it straightforward to inspect both primary objects and automatically generated related records.

---

# Supporting New SObject Types

Support for a new `SObject` is added by implementing `XFTY_DummySobjectProviderIntf` and registering it with an implementation of `XFTY_DummySObjectProviderLookupIntf`.

A factory outlet defines:

* the primary object type
* default field values
* default relationship behaviour

A typical implementation looks like this:

```apex
@IsTest
public class TEST_DummyContactFactoryOutlet implements XFTY_DummySobjectProviderIntf {
    private static final SObjectField PRIMARY_TARGET_FIELD = Contact.Id;

    public SObjectField getPrimaryTargetField() {
        return PRIMARY_TARGET_FIELD;
    }

    public TEST_DummySObjectBundle createBundle(
        List<SObject> templateSObjectList,
        XFTY_InsertModeEnum insertMode,
        XFTY_InsertInclusivityEnum inclusivity) {

        TEST_DummySObjectMasterTemplate masterTemplate =
            new TEST_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
                .put(Contact.FirstName, new XFTY_DummyDefaultValueIncrementingString('Contact First Name'))
                .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString('Contact Last Name'))
                .put(Contact.Email, new XFTY_DummyDefaultValueUniqueEmail('test.contact'))
                .put(Contact.AccountId, new XFTY_DummyDefaultRelationshipRequired(
                        new Account(Description = 'Account for contact')
                ));

        return XFTY_DummySObjectFactory.createBundle(
            masterTemplate,
            templateSObjectList,
            insertMode,
            inclusivity);
    }
}
```

Factory outlets remain small, declarative, and focused entirely on describing default data rather than constructing records imperatively.

---

# Design Philosophy

XFTY was created to address a common problem in long-lived Salesforce projects: test data becomes scattered throughout the codebase.

When validation rules, workflows or object relationships change, updating hundreds or even thousands of tests can become a significant maintenance task.

Rather than treating test data as imperative setup code, XFTY treats it as declarative templates that can be centrally maintained and selectively customised. Individual tests specify only what makes them unique, while the library supplies everything else.
