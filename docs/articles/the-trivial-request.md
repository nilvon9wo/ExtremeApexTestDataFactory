# The Trivial Request That Changed How I Design Software

> *A personal essay, first published on LinkedIn. Written before the XFTY 4.0
> rework — the "record types and context-aware defaults" it names near the end as
> ideas still to explore are now built. Kept here for background, not as current
> documentation.*

For the business, it was the tiniest of changes, and a thing which should have been completely trivial. It should not have been complicated. It definitely should not have been interesting.

They wanted neither a new feature nor a bug fix. They needed neither a new table nor a field. There would be no change to the UI. All they wanted—all they needed—was to change one field from optional to required.

It was the kind of request you say “yes” to before you finish reading the email.

It sounded completely trivial.

They could hardly have imagined the downstream impact. Of course, they predicted some impact for the business, but they did not anticipate (perhaps never even learned of) the impact on the codebase, on the way Salesforce Apex developers build test data, and (ultimately) my entire approach to system design.

Circa 2013. I was working for [**EPAM**](https://www.epam.com/), assigned to a project for an FMCG (name withheld because of NDA; you’ve probably drank their products, but it isn’t important anyway). It was a [**Salesforce**](https://www.salesforce.com/) project. Among developers, Salesforce is infamous for its limits. In the Salesforce world, the 70% minimum test code coverage requirement – all passing – is less of a quality guideline and more of a hard, unforgiving brick wall between you and production deployment.

I don’t remember which field they changed, nor whether it was standard or custom, but I do remember it was on the Account standard SObject, one of the most used entities I’ve ever worked with. (You can think of Salesforce as a database on steroids, and SObjects as tables with OOP superpowers.) This project was typical in that regard.

Another thing that was typical: All the existing tests were [**integration tests**](https://www.geeksforgeeks.org/software-testing/software-engineering-integration-testing/). Salesforce literature commonly conflates unit tests and integration tests. Most Salesforce developers don’t know the difference, or even if they know, many don’t know true, isolated unit tests are even possible on the platform.

And here was the crux of the problem. By requiring this field on Account, every single test in the Salesforce org that depended on Accounts now required this field to be explicitly set in order to pass. Even tests that had almost nothing to do with Accounts suddenly collapsed, if they relied on inserting SObjects with either a direct or even an indirect requirement for an Account Id. All the tests needed to pass in order to deploy anything at all.

Lucky me: I drew the short straw to fix all those tests. I recognized right away this would be weeks' worth of work, and if done in a naïve way, the solution would be fragile—easily broken by the next similar change.

Fortunately, I already knew many [**Gang of Four (GoF) OOP Design Patterns**](https://www.geeksforgeeks.org/system-design/gang-of-four-gof-design-patterns/), including the [**Factory pattern**](https://www.tutorialspoint.com/design_pattern/factory_pattern.htm). This is one of the most obvious of all patterns. Once I saw repeated creations, it was a no-brainer to use it. The solution was simple: Create a factory class responsible for creating Accounts, Contacts, and other SObjects, and centralize the test data creation there.

At a high level, the basic signature looked like this:

```apex
public List<Account> create(Integer quantity, Boolean doInsert)
```

This gave me control over both how many records to create and whether to commit them to the database. If a test needed control of specific fields, I could simply add parameters to the method.

Very crude. Very effective.

More importantly, it bought me something the original code never could: one place to change instead of hundreds. The tests were fixed with neither much extra effort nor much extra time required.

## Where the Story Forks

This is not where the story ends, but where the story forks.

Not long after, EPAM lost the contract to a consultancy more deeply entrenched in the Salesforce market. When I joined Accenture in 2017, I started seeing this exact pattern—including the very same method signatures—being used on multiple Salesforce projects, despite the code otherwise being very WET (Write Everything Twice). By 2018, I saw the pattern reproduced in [**an official Salesforce Trailhead unit**](https://trailhead.salesforce.com/content/learn/modules/apex-testing-prepare-for-unit-testing/get-data-for-your-tests), and since then I’ve seen it replicated in countless orgs. I would venture to say it is among the most frequently cargo-culted code I’ve ever encountered.

However, as I said, this is where the story forks. The factory solved the immediate problem, but it also exposed the next layer of problems.

The factory solved the problem I had been given. The next time the business decided another field should become mandatory, I would only have one place to update instead of hundreds. At the time, I thought I had solved the problem. In reality, I had only solved the deployment problem.

Two limitations were immediately obvious, and I ignored them. I had thousands of failing tests to fix, not a framework to design.

Looking back, that restraint was probably as important as the design itself.

### The first crack: Variability.

One test needed an Account in the Technology industry. Another required a specific billing country. Another depended on record types that only existed in certain configurations. My original solution was predictable: add another parameter, or another overload. It worked... until it didn’t. At some point, the factory stopped being a simplification layer and started becoming a sprawling configuration catalogue for every possible shape of an Account. Soon the method signature looked less like a factory and more like a tax form—dense, bloated, and begging for simplification.

The obvious solution was to accept a partially populated SObject instead of a growing list of parameters. Apex conveniently allows named parameters when constructing SObjects, so a test could simply write:

```apex
new Account(
    Industry = 'Technology',
    BillingCountry = 'Germany'
)
```

… and let the factory fill in everything else. Accepting partially populated SObjects would solve one problem, but exposed another. The framework now needed to merge caller-supplied values with its own defaults. What had once been a few assignments inside a factory method would require reusable infrastructure. However, implementing this was not as quick and simple of thinking of it. It could not be done at the snap of the fingers. This problem sat with me.

The same capability would also be needed for relationship fields. Whether the value was Industry, BillingCountry, or AccountId, the framework needed a consistent way to preserve caller-supplied data while filling in everything else.

**It needed an engine.**

### The second crack: Structure.

Real business data rarely consists of isolated records. An Opportunity needs an Account. A Contact often needs one too. Some objects depend on entire chains of related records. Passing an AccountId into a factory method solved only the smallest part of the problem. Someone still had to create that Account. And if that Account depended on other records, someone had to create those too. I wasn't just manufacturing records anymore. I was manufacturing graphs of related objects. This was a much bigger design problem.

### A third problem was the one that annoyed me most: Isolation.

As a junior Salesforce developer only concerned with fixing tests, this problem was harder to spot. Salesforce documentation refers to all Apex tests as unit tests. In reality, most are integration tests, touching a real database. That distinction matters. Because once everything depends on the database, isolation stops being the default—you have to fight for it.

Once I learned to distinguish true/pure/atomic [**unit tests**](https://www.geeksforgeeks.org/software-testing/unit-testing-software-testing/), I wanted to write tests to prove my code works. I did not want the database, triggers, workflows, or validation rules involved -- unless I am explicitly testing those things.

Many features legitimately depend on records having an Id. The problem is that Salesforce normally assigns that Id only after the record is inserted into the database. What if I wanted the Id without depending on the slow database operation at all?

I already had a utility capable of generating realistic Salesforce Ids. Generating them wasn't the problem. Remembering to invoke it—and manually assigning those Ids to every record that needed one—was. That kind of repetitive plumbing was exactly what the factory was supposed to eliminate. Moreover, this added noise to the tests, obscuring their intent—exactly the kind of detail a factory is supposed to hide.

None of these problems were urgent in 2013. They were simply observations I filed away while I concentrated on the task in front of me. But ideas have a habit of lingering. Over the next few years I kept running into the same limitations, and once I finally had both the time and the experience to tackle them properly, I stopped thinking about another factory class. I started thinking about an engine.

## From Factory to Framework

The deployment problem had been solved years earlier. Nobody was asking for anything more. I was. The ideas I had deliberately postponed in 2013 never really went away. By 2017 I had accumulated four years of grievances about how Salesforce testing was typically done, and enough experience to believe I could do better. I wasn't interested in another factory class anymore. I wanted to explore what a coherent approach to testing on the platform might look like.

Once an engineering problem gets under my skin, it tends to stay there until I understand it properly. Every new Salesforce project gave me another example of the same underlying frustrations. Test data creation remained repetitive. Database access remained tightly coupled. "Unit tests" still weren't really unit tests. I wasn't looking for another helper class anymore. I wanted a coherent way to solve all of those problems together.

[**FakeForce (F45)**](https://github.com/nilvon9wo/fakeforce) was the result.

A pressure valve for years of accumulated frustration, FakeForce was never intended to be just a test data framework. It also experimented with abstracting DML behind injectable interfaces, normalizing DML results, providing selector examples that could be mocked during testing, and even bundled a trigger framework that reflected how I preferred to structure Salesforce applications. Looking back, it was probably more ambitious than it was mature.

It wasn't trying to become a product. It was trying to answer a much simpler question: "If I could redesign how I build and test Apex applications from scratch, what would it look like?"

The factory pattern was still there, but by this point I had stopped thinking about it as a factory. However, the intention had shifted. This was about treating object creation as a process rather than a constructor call: applying defaults, wiring relationships, and deciding what stage of its lifecycle the returned object should be in.

By this point, I had stopped thinking about the factory pattern as code that created objects. I had started thinking of them as the place where all knowledge of object creation belonged. Once all knowledge of how to construct an object lives in one place, future change becomes dramatically cheaper.

While building with this framework, I shifted away from asking whether an object had been inserted. The more important question was what guarantees the caller actually needed. Once enums started describing an object’s lifecycle, the factory’s promise changed. It was no longer “I’ll give you an inserted Account.” It became “I’ll give you an Account in the state you asked for.”

That shift mattered far more than the enum itself. The caller specified the desired end state, and the factory guaranteed the postconditions: Does the object have an Id? Are required fields populated? Are relationships wired? Is it safe to perform DML later?

Tests didn’t care how the object reached that state. They cared that the state was correct, full stop. And that was the real insight: not how objects were created, but what “created” was allowed to mean.

I wasn't applying design patterns for their own sake. I was applying them because each one solved a specific problem the design needed to address.

Around this engine, multiple design patterns found a natural place in the architecture. The [**Abstract Factory Pattern**](https://www.tutorialspoint.com/design_pattern/abstract_factory_pattern.htm) had solved object creation, but other problems called for different tools. [**Strategy Patterns**](https://www.tutorialspoint.com/design_pattern/strategy_pattern.htm) and [**Template Methods**](https://www.tutorialspoint.com/design_pattern/template_pattern.htm) described different ways of producing test data. [**Dependency Injection**](https://builtin.com/articles/dependency-injection) separated creation from persistence. [**Mock Objects**](https://www.geeksforgeeks.org/software-testing/software-testing-mock-testing/) allowed tests to request realistic Ids without touching the database.

(Fake Ids are only one piece of truly isolated unit testing. Production code that performs SOQL or DML still needs to depend on abstractions that can themselves be replaced during testing. FakeForce included infrastructure to support that style of testing, but Dependency Injection and [**Inversion of Control**](https://martinfowler.com/bliki/InversionOfControl.html) are much larger topics than this article can reasonably cover. The mechanics are Salesforce-specific. The underlying problem isn't. Every platform eventually has to decide how tightly its tests should be coupled to external infrastructure.)

FakeForce was more than an evolution of the original factory pattern which solved one immediate deployment problem back in 2013. Between then and 2017 I accumulated ideas, utilities, experiments, and frustrations across multiple projects. FakeForce was where I finally assembled many of them into a single proof of concept. The reusable test-data engine—the pièce de résistance—was built specifically for that project rather than evolved from the original factory.

Publishing it to GitHub led to useful discussions with other developers on Reddit, but the more important feedback came from experimenting with it myself. Even in toy projects, neither the architecture nor the interface held up. The underlying ideas felt sound, yet every extension reminded me how much the caller still needed to understand the framework's internal mechanics. Moreover, it was neither flexible nor extensible. It never became widely adopted, although it remains my most-starred GitHub repository.

## The solution to one set of problems inevitably exposed more.

## Problem Solution != Pleasant Abstraction

FakeForce did exactly what I intended it to do. It proved that defaults, relationship construction, lifecycle management, and isolated test data could all be unified behind a single engine. Templates eliminated parameter explosions, relationships could be wired consistently, and tests could request realistic Ids without touching the database.

But there was an important difference between solving the engineering problem and solving the usability problem. FakeForce had moved a great deal of construction logic into the framework, but it had not moved all of the knowledge. The caller still had to understand which strategies to choose, how relationships were built, and how those pieces interacted. The implementation was centralized, yet too much understanding remained distributed between the framework and its users.

Proving the ideas worked wasn't the same as producing an abstraction people would actually enjoy using.

When I stepped back and looked at FakeForce—not as its author, but as someone who might have to use and extend it—I noticed something unsettling. The framework still expected its users to understand too much about how it worked.

Consider:

```apex
List<Contact> contacts = F45_FTY_TestSObjectFactory.createTestList(
  new nSObjectPerRelatedSObjectStrategy( // Which strategy do I need?
    new Contact(LastName='Smith'), // Template
    3, // Quantity
    'AccountId', // Relationship field
    accounts // Parent records supplied manually
  ),
  F45_FTY_RecordInsertMode.MOCK // Desired lifecycle
);
```

If your eyes glaze over when you see this, good—you’re feeling exactly what I felt.

Every parameter made sense, if you knew what they were. However, every parameter represented another decision the caller had to make, and it was not obvious which values belonged where. None of those decisions were business decisions. They were framework decisions leaking into application code.

Although I initially looked at such code with brief surge of pride, soon followed the sinking feeling “I wouldn't want to explain this to a new hire”. Actually, I wouldn’t even want to try to remember what this did in a month or three.

The problem wasn't that it failed. The problem was everything the caller had to understand before they could write it. Creating different kinds of data and building relationships meant choosing different strategies, so the caller would need to know what strategies are available, why they exist and how those strategies interacted. Moreover, the caller needed to provide parent records manually, understand how they would be wired, and then provide all these parameters in the correct order. Notice, these are all caller responsibilities, which would appear in tests, not implementation details. Even though the framework had centralized object creation, the caller still carried a surprising amount of knowledge about the construction process.

None of that made FakeForce wrong. In fact, it solved every problem I had set out to solve.

It simply answered a different question than the one I would eventually learn to ask.

The initial factory pattern had hidden duplicated code. FakeForce had hidden duplicated construction logic. But the caller was still responsible for making too many decisions. That became the next problem.

I had spent years thinking about what the framework needed to know. I hadn't spent nearly as much time asking what the caller should not have to know. When I eventually designed [**Extreme Apex Test Data Factory (XFTY)**](https://github.com/nilvon9wo/ExtremeApexTestDataFactory/), I was trying to make it ask less of its caller.

The question changed.

It stopped being:

"How should the caller tell the framework to build this object?"

and became:

"What is the smallest amount of knowledge the caller should need?"

The answer turned out to be: surprisingly little.

```apex
XFTY_DummySObjectBundle resultBundle = new XFTY_DummySObjectProvider(Contact.SObjectType)
  .setOverrideTemplate(new Contact(LastName = 'Smith'))
  .setQuantityPerTemplate(3)
  .setInsertMode(XFTY_InsertModeEnum.MOCK)
  .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
  .supplyBundle();

List<Contact> contacts = resultBundle.getList(Contact.Id);

// Only if the tests need the accounts.
List<Account> accounts = resultBundle.getList(Contact.AccountId);
```

Notice what disappeared. I never selected a strategy. I never manually wired relationships. I never supplied parent records. I never told the framework what order to create objects. The framework inferred all of those things from the information it already had. I simply described the data I wanted.

A test shouldn't need to know which strategy class creates parent records. It shouldn't need to understand how relationships are wired together. It shouldn't need to think about the order objects are constructed or which defaults eventually win.

It should simply describe the data it needs. That sounds like a small API change. It isn't. It changes where the complexity lives. Likewise, relationships stopped being something the caller assembled manually. The caller described the shape of the data it wanted, and the framework constructed whatever object graph was necessary to satisfy that description. The API became about the desired state rather than the mechanics used to achieve it.

Internally, XFTY used the [**Interpreter Pattern**](https://www.tutorialspoint.com/design_pattern/interpreter_pattern.htm), the [**Composite Pattern**](https://www.tutorialspoint.com/design_pattern/composite_pattern.htm), and [**Builder Patterns**](https://www.tutorialspoint.com/design_pattern/builder_pattern.htm), among others—not because I wanted to collect design patterns, but because each one removed another decision from the caller. Strategy Pattern objects gave way to an Interpreter Pattern for default values. Relationship [**template methods**](https://www.tutorialspoint.com/design_pattern/template_pattern.htm) replaced explicit parent-management. Bundles replaced manually correlating related records. The implementation grew more capable precisely so the public API could become smaller.

Internally, XFTY was considerably more sophisticated than FakeForce. That wasn't a contradiction. It was the entire point. Complexity hadn't disappeared; it had moved from every test into one reusable abstraction, where it only had to be solved once.

For the first time, writing tests felt less like constructing data and more like describing it.

That distinction has stayed with me ever since. I started carrying XFTY from project to project. First into small experiments, then into professional work. Every new codebase followed roughly the same pattern: copy in the framework, define the templates the project needed, and move on to solving the actual business problem.

That was exactly what I had hoped for. The framework stopped demanding attention. I would occasionally add a template, implement a new default provider, or adapt it to changes in Salesforce itself, but the engine rarely needed reconsideration. Over the years it evolved, but mostly through refinement rather than redesign.

The real payoff, as a developer, is being able to forget about it.

There are still ideas I'd like to explore around record types and context-aware defaults. But those are refinements rather than reinventions. The architectural leap had already happened.

Looking back, I don't think the real achievement was building a better test-data framework. It was discovering that every successful iteration removed another responsibility from the caller.

The original factory pattern removed duplicated setup.

FakeForce centralized construction logic.

XFTY centralized construction decisions.

## What the Journey Actually Taught Me

What started this was never meant to be interesting.

A single field changed from optional to required, and what looked like a trivial adjustment turned into a deployment problem that exposed how brittle the surrounding test infrastructure really was. At that time, I wasn't trying to design a framework. I was trying to get a deployment through before thousands of failing tests blocked the business.

The Factory pattern solved that immediate issue. It gave me one place to fix what had previously been scattered across hundreds of tests. Solving that problem also made its limitations impossible to ignore.

Some of those problems were immediately obvious, even if I wasn't yet in a position to solve them. Others only emerged after living with the later designs. Each iteration answered one question while making the next easier to ask.

What followed wasn’t a single breakthrough, but a sequence of pressure points revealed over time. The original factory pattern centralized where test data was created. FakeForce centralized the mechanics of creating it. XFTY centralized the decisions involved in creating it. Each step didn’t invalidate the previous one. Every version was a snapshot of what I understood at the time. Extension exposed its limits.

The consistent theme was not the pattern itself, but the same underlying constraint: how much responsibility the caller should carry just to obtain valid data. That constraint started as a deployment problem. Over time, it became a design question.

That's probably the biggest lesson I took away from the experience.

Good engineering isn't just knowing what to build. It's knowing what not to build yet. Software design rarely arrives fully formed. Sometimes the most valuable thing isn't finding the perfect abstraction. It's recognizing today's abstraction is good enough, while keeping your eyes open for the one you'll eventually grow into.

All because someone decided a field should be required.
