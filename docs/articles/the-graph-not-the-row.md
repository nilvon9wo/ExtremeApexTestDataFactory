# The Graph, Not the Row: What Survives the Trip Off Salesforce

Nearly a decade ago I built XFTY, a declarative test-data framework for Salesforce Apex, and carried it into the stack at more than one job since. It builds whole object graphs — an Opportunity that needs an Account, that needs an Owner, that needs a Role — from a few lines of description instead of a hundred lines of imperative setup.

The design converged early. The first version wasn't even a library, just a pattern other developers copied by hand. The second was an overambitious rewrite with a worse DSL. The third — Provider, Template, Bundle, and an engine that walks the graph between them — is the one that stuck, and a decade of real use barely touched it beyond the extensions it was built for: new SObjects, new ways to calculate a default value. The one forced change was SFDX, which needed a level of indirection so a Provider could resolve across separate package boundaries. Last week I closed a few gaps that had bugged me the whole decade — record-type support chief among them — for real this time instead of working around them. That work turned out to be dependency ordering and topological sort: the same problem whether the node being inserted is an Account or a C# entity.

Ask what's actually *Salesforce* about any of it, and the honest answer is: less than you'd expect.

Every platform with related records hits the same wall. A realistic test scenario isn't an isolated row, it's a graph — hand-wire that graph in every test and your setup code outgrows the behavior you're testing, then breaks the moment someone adds a required field two hops away. Salesforce's version has extra spikes: governor limits, `@TestSetup` silently resetting your static state, a required lookup you didn't know existed failing a test in a class you've never opened. Those are real, and XFTY spends real effort on them.

```text
Template  →  Graph Engine  →  Persistence  →  Bundle
[generic]     [generic]        [platform]      [generic]
```

Only the stage that touches the database changes shape from platform to platform. Everything upstream and downstream of it is graph construction, not Apex.

Here are the six pieces of that pipeline that carried over cleanly when I mapped them onto C#. Apex on the left, the C# I'd write for the same idea on the right — a sketch of the shape, not an existing library. `EntityTemplate`, `Graph<T>`, `SharedAncestor<T>`: none of that ships with Entity Framework or the BCL, I'm naming the classes I'd write myself. Where EF's own machinery actually does the same trick under the hood, I've called that out inline.

## 1. Describe the graph, don't build it

A test doesn't say "insert an Account, then insert a Contact and point it at that Account." It says what a valid Account and Contact look like — defaults and required relationships — and hands that description to an engine that knows how to build it in the right order.

```apex
new XFTY_DummySObjectMasterTemplate(Account.Id)
    .put(Account.Name,
         new XFTY_IncrementingStringExpression("Account"))
    .putRequired(Account.OwnerId,
         new XFTY_DummyDefaultRelationship(new User()));
```

```csharp
new EntityTemplate<Account>()
    .Put(a => a.Name, new IncrementingString("Account"))
    .Require(a => a.OwnerId, new DefaultRelationship<User>());
```

## 2. Key relationships by field, not by type

A record can have several lookups to the same target type — `PrimaryContact`, `SecondaryContact`, and `BillingContact` may all point at `Contact`. Keying the template by the field that stores the lookup, rather than by the type it points to, keeps those three distinct with no special-casing.

```apex
.putRequired(Deal__c.PrimaryContact__c,   billingContact)
.putRequired(Deal__c.SecondaryContact__c, decisionMaker)
```

```csharp
.Require(d => d.PrimaryContactId,   billingContact)
.Require(d => d.SecondaryContactId, decisionMaker)
```

Apex gets the field as a runtime value for free from `Schema`. C# has no such token, so the template resolves `d => d.PrimaryContactId` to a `MemberInfo` at build time instead — the same trick EF's own fluent API uses internally. More typing, identical model.

## 3. Build the graph, not the row

The output isn't a flat pile of records. It's a tree that mirrors the object graph it just generated, so a caller can ask for either the related rows or the whole subgraph beneath them.

```apex
List<Contact> contacts =
    bundle.getList(Contact.AccountId);
XFTY_DummySObjectBundle accountGraph =
    bundle.getBundle(Contact.AccountId);
```

```csharp
IReadOnlyList<Contact> contacts =
    graph.Records<Contact>(c => c.AccountId);
Graph<Account> accountGraph =
    graph.Subgraph<Account>(c => c.AccountId);
```

The three pieces above are the decade-old core — the part that clicked once and stayed put. The next three are about a week old, currently living on [the 4.0 beta branch](https://github.com/nilvon9wo/ExtremeApexTestDataFactory/tree/4.0-beta) rather than master — long-standing gaps I finally closed properly instead of working around — and they were genuinely hard to get right, which makes it more interesting that they turned out to be just as portable.

## 4. Three passes for values, not one

A field's value sometimes needs to see the rest of the record: an email built from a last name, a discount that depends on a sibling amount. Filling every field in one undefined pass makes that racy. XFTY fills values in a fixed order — plain values first, then values that can read an already-generated sibling field, and finally values that read a child record that doesn't exist until the graph is flushed. Reach forward instead of backward and the engine throws, naming the field and the fix, instead of handing back a silent wrong `null`.

The ordering is the idea; the syntax is incidental. Apex has no lambdas that can implement an arbitrary interface, so a context-aware value is a small named class. C# lets you inline the same thing:

```apex
public class EmailFromLastName
        implements XFTY_ContextAwareExpressionIntf {
    public Object generate(XFTY_GenerationContext ctx) {
        return (String) ctx.siblingValue(Contact.LastName)
            + '@example.com';
    }
}
// ...
.put(Contact.Email, new EmailFromLastName())
```

```csharp
.Put(c => c.Email, new ContextAware<string>(ctx =>
    $"{ctx.Sibling(c => c.LastName)}@example.com"))
```

## 5. Resolve shared ancestors once

Not every relationship should fan out into a fresh record per child. A hundred Deals in one test usually want *one* Region, not a hundred generated Regions. A shared ancestor is resolved once, dependency-ordered against any other shared ancestor it depends on, and every child is wired to that single record.

```apex
XFTY_SharedAncestor sharedRegion =
    new XFTY_SharedAncestor(Region__c.SObjectType, regionTemplate);
// ...
.put(Deal__c.RegionId, sharedRegion)
```

```csharp
var sharedRegion =
    new SharedAncestor<Region>(regionTemplate);
// ...
.Put(d => d.RegionId, sharedRegion);
```

## 6. Batch inserts by depth, not by call site

Naive graph construction inserts as it recurses — one round trip per record. Sorting the finished graph into dependency depths first (a textbook Kahn topological sort) means every record at the same depth can go in a single batch, regardless of how many types are at that depth.

| | Inserts |
|---|---|
| Naive | 40 |
| Depth-batched | 5 |

Same forty-record, five-level graph. The topological sort has nothing to do with Salesforce — the payoff is just larger on a platform that also caps how many DML statements one transaction gets to make.

---

## What doesn't make the trip

**The field token.** Apex's `Schema.SObjectField` is a runtime value handed to you for free. C# needs a compiled expression tree to get the same thing. TypeScript, ironically, needs less ceremony than either — `keyof T` gets you there with no reflection at all.

**Record types.** Salesforce's `RecordType` is a first-class schema citizen: one `Account` table, but a Business Account and a Person Account record type can each carry their own required fields, picklist values, and page layout, enforced by the platform itself. The nearest thing in EF is a *discriminator column* for table-per-hierarchy mapping — one physical table backing several C# subclasses, with a plain column (say, `Discriminator = "Car"` vs. `"Truck"`) telling EF which subclass to build a given row into. It's a much thinner concept wearing a similar name: a discriminator picks a shape for the ORM, a record type picks a business process for the platform, with real UI and validation consequences attached. This one doesn't port 1:1, and I wouldn't force it.

**The reason to skip the database.** On Salesforce, generating a record without inserting it dodges governor limits that will fail your test outright — but that's not even the main reason. The bigger one is Flows, validation rules, and triggers firing side effects that have nothing to do with what you're actually testing. That's not a Salesforce quirk, it's the actual line between a unit test and an integration test: if you can't stop the record from really landing in the database, you can't isolate your code from everything else that reacts to a database write, and "unit test" quietly becomes a polite name for an integration test. EF has the same problem at a smaller scale — database triggers, computed columns, cascading deletes — and mocking persistence is exactly what makes a real unit test possible there too. Only the governor limits are Salesforce-specific; the isolation argument doesn't get weaker off-platform, it's the same argument everywhere.

**The platform's own trap.** Salesforce's is `@TestSetup` quietly resetting static state between setup and the tests that follow it. You don't learn that from the docs — you learn it by writing a test that should obviously pass, watching it fail, and finding the data doesn't match what the framework was supposed to generate: values that were supposed to be unique turning up duplicated, say. The bug isn't in your code and it isn't in your test, it's in the layer between them, which is its own particular kind of hard to debug. The one comfort is that a bug like this fails loudly, in CI, before anything ships — assuming your tests aren't too sloppy to catch it in the first place. Whatever platform comes next has its own version of this trap. It can't be ported in ahead of time; it has to be found again.

---

I wrote XFTY because Salesforce testing needed it, a decade ago. Looking back, the core held up that whole decade because it was never really a Salesforce idea to begin with — Provider, Template, Bundle is just object-graph construction. Even the gaps I finally closed last week held up for the same reason: sequencing value generation and batching inserts by dependency depth are graph problems first, wherever the graph happens to live. That's a design problem, not a platform trivia question.

If you're solving the same problem in C#, TypeScript, or anything else with foreign keys, I'd like to compare notes.
