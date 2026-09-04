# Unit Testable Apex: How to Stop Fighting the Salesforce Database

I’ll bet a month’s salary, you can’t answer this question:

*How do you create [unit tests](https://www.geeksforgeeks.org/software-testing/unit-testing-software-testing/) in Salesforce?*

***WRONG!***

If you actually got it correct, I’ll wager double or nothing you’ve spent significant time developing with some other technology/platform, such as, but not necessarily, Java or C#.

I can hear the objections already.

There is a plethora of documentation describing how to do 'unit tests' (scare quotes intended) on Salesforce. And, of course, if you’ve deployed Apex, you’ve written them. The thing is, most of what you’ve composed were not unit tests. Or if they were, it was by accident—you just happened to test a class that didn't integrate with anything.

The truth of the matter is that Salesforce lies (or as some might prefer to say “simplifies” or “blurs distinctions”). The documentation and community commonly refer to all Apex tests as “unit tests”, even if it is an [integration test](https://www.geeksforgeeks.org/software-testing/software-engineering-integration-testing/), a load test, a process test, or some other “test” which might not be better described or even worthy of the term test.

However, unit tests predate Salesforce and on other tech stacks, in other communities, have a much more specific meaning: Unit tests are tests that verify one specific thing: a single unit. If a database is involved (including Salesforce’s underlying data store), if other classes are involved, if validation rules, workflow rules, process builder, or flows are executing, you no longer have a unit test, you have an integration test.

Don’t get me wrong: Integration tests are a good thing, and an important thing – you need them to prove your entire solution works as a whole. However, they are a different thing.

Some will tell you true unit tests on Salesforce are impossible: they are wrong.

Others will tell you they are a waste of time: also *wrong*.

The wisest will frequently point to the Stub API: Maybe they actually know what they are talking about, but they are *wrong* too.

This group may understand what a true unit test is, but the Stub API is still *wrong* because it is:

- Not type-safe: You lose compile-time checking.
- Condition-heavy: It forces logic into your mocks.
- Built on code injection: A technique most platforms reserve as a last resort.

I’m not here to argue that the [Stub API](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_stub_api.htm) should be thrown out with the trash.

I am here to tell you there is a better way and show you how to achieve it.

## From Static to Instant

Before I can teach you to create better unit tests, I need to teach you to create unit testable code.

It is really easy:

*All you really need to do is delete `static` from everywhere.*

...

Okay, if you actually did that, your code probably doesn't compile anymore.

The truth is, it is easy, but it is not *that* easy. If you want to get technical, what we are about to do is known as [**dependency injection**](https://www.geeksforgeeks.org/system-design/dependency-injectiondi-design-pattern/) and [**inversion of control**](https://martinfowler.com/bliki/InversionOfControl.html), but you can just think of this as changing static methods to instance methods to make your dependencies replaceable. A static method is permanently attached to its implementation. An instance method can be replaced with another implementation.

Let’s say for a very simple example, you have:

```apex
public class Foo {
    public Result doSomething(Input input) {
        return Bar.doSomething(input);
    }
}

public class Bar {
    public static Result doSomething(Input input) {
        Result result;
        // do something with input
        return result;
    }
}
```

(Never mind what types `Input` or `Result` are: this applies regardless of the method signature.)

Right now, Foo *depends on* Bar.

We need to make the dependency replaceable and expose that dependency to Foo. You’ll have two choices how to do each of these. Once we've done this, we'll be able to replace Bar with a tiny fake implementation that runs instantly, never touches the database, and gives us complete control over every scenario we want to test.

### Replaceability (Mockability)

First, we need to modify `Bar`.

You can choose between introducing an [**interface**](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_interfaces.htm) or making `Bar` extensible.

#### Introduce an Interface

```apex
public interface IBar {
    Result doSomething(Input input);
}

public class Bar implements IBar {
    public Result doSomething(Input input) {
        Result result;
        // do something with input
        return result;
    }
}
```

This is the traditional [Object Oriented Programming](https://www.geeksforgeeks.org/dsa/introduction-of-object-oriented-programming/) approach. When you know how to use them, interfaces are incredibly useful. But right now, this adds another abstraction that provides no value until you actually have multiple implementations. It also gives you an extra file to maintain. Not least, it will also become very annoying when you’re navigating the code in your IDE.

So, unless you actually need the interface for production, I *strongly* recommend:

#### Make it Virtual

```apex
public virtual class Bar {
    public virtual Result doSomething(Input input) {
        Result result;
        // do something with input
        return result;
    }
}
```

In OOP terminology, we’ve simply changed both the class and the method from [`final`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_keywords_final.htm) to [`virtual`](https://www.apexhours.com/virtual-classes-and-virtual-methods-in-apex/) by adding the keyword to both the class and the method. This allows us to [`override`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_extending.htm) (replace) the method. We’ll get back to that later.

(I don’t want to go into it here, but I would urge you *never* to use `virtual` classes and methods to replace functionality for production purposes. Always favour composition over inheritance.)

### Dependency Injection and Inversion of Control

Now, we need to modify `Foo`.

Again, we’ll have two choices (or four, if you permeate between interfaces and virtual methods).

#### Constructor Injection

```apex
public class Foo {
    // If you don’t use an interface, just change `IBar` to `Bar`.
    private final IBar bar;

    /*
     * This is the primary constructor.
     * It will allow us to do magic later.
     * This does not need to be private, but I prefer to keep it private
     * if the production code will never be responsible for replacing the dependencies.
     */
    @TestVisible
    private Foo(IBar bar) {
        this.bar = bar;
    }

    /*
     * This is the default constructor.
     * This allows your upstream consumers to use `Foo` without knowing about its dependencies
     * – or changing when the dependencies change.
     *
     * On other platforms (such as C# or Java) you would probably use a dependency injection framework
     * with a “container” to inject these dependencies, but on Salesforce, this involves creating a messy
     * and confusing god object which usually creates more problems than it solves.
     * On Salesforce, I usually prefer keeping these dependencies self-contained.
     */
    public Foo() {
        this(new Bar());
    }

    public Result doSomething(Input input) {
        return this.bar.doSomething(input);
    }
}
```

#### Side Injection

```apex
public class Foo {
    @TestVisible
    private final Bar bar = new Bar();

    public Result doSomething(Input input) {
        return this.bar.doSomething(input);
    }
}
```

While this is much more concise, I tend to prefer constructor injection because it forces you to update the tests when the dependencies change. Otherwise, you may accidently change your unit tests into integration tests with unexpected results. For example, if `Foo` suddenly gains a second dependency next month, constructor injection immediately breaks the tests until you decide how that dependency should behave. Side injection makes it much easier to accidentally leave one dependency "real" and quietly turn a unit test into an integration test.

### Static Isn’t Just `static`

You won’t find all the static by searching your code base for `static`.

Salesforce API is full of static methods.

DML and SOQL are all static.

Third party packages may also contain static methods. And even when their API is not static, the classes may lack interfaces and instance methods may not be virtual.

In all such cases, the solution is the same: put a [wrapper](https://www.tutorialspoint.com/design_pattern/adapter_pattern.htm) on it. Wrappers aren't just for testing. They isolate your application from any APIs beyond your control, making future changes much easier.

We won’t go into details here, but in short, you can do things like this:

```apex
public virtual class AccountSelector {
    public virtual List<Account> getByIds(Set<Id> ids) {
        return [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :ids
        ];
    }
}
```

and

```apex
public virtual class InjectableDml {
    public virtual void doInsert(List<SObject> sObjects) {
        insert sObjects;
    }
}
```

Better to use frameworks for these, especially the DML because Salesforce didn’t provide an interface for the return types, but that’s well beyond the scope of this article.

## How to Mock

Now, that your dependencies are being injected, we can create [mocks](https://martinfowler.com/bliki/TestDouble.html) for them.

Because Salesforce doesn’t offer generics and has weak reflection, this is going to be very manual, but also – unlike the StubAPI – it is going to be both typesafe and unconditional.

How you create your mocks is going to depend in part on how you implemented the dependency.

### Mocking With an Interface

```apex
public class BarMock implements IBar {
    public Input receivedInput;
    public Result returnedResult;
    public Result doSomething(Input input) {
        this.receivedInput = input;
        return this.returnedResult;
    }
}
```

### Mocking With Virtual Methods

```apex
public class BarMock extends Bar {
    public Input receivedInput;
    public Result returnedResult;
    public override Result doSomething(Input input) {
        this.receivedInput = input;
        return this.returnedResult;
    }
}
```

These are *almost* identical.

If you use `virtual` (that keyword I promised to get back to earlier), you need to:

1. `extend` instead of `implement`
2. include the keyword `override`

Notice what we didn't have to do:

- register anything
- configure the Stub API
- invoke methods by name
- use reflection

They're just Apex classes.

Moreover, you’ll notice there are no `if` statements here. You generally don’t want conditional logic in your mocks, as this makes the mocks more difficult to reason about and can introduce an unexpected and difficult to debug source of failures within the tests.

Instead we give the tests an API which they can use to control the mocks: a field where they can set the return value, and a field where they can (optionally) spy on the received value. (Technically, you don’t need to capture the received values and whether you should spy on these values is a debatable topic which goes beyond the scope of this article).

Of course, these mocks may be a bit too simple for some scenarios. Most obviously, it will be a problem if you need to invoke `doSomething` multiple times or need `doSomething` to throw an exception. But for such scenarios, we just need to create a slightly more sophisticated mock:

```apex
public class BarCanFailMock extends Bar {
    public List<Input> receivedInputs = new List<Input>();
    public List<Result> returnedResults;
    public Integer throwOnInvocation = -1;
    public Exception thrownException;
    public override Result doSomething(Input input) {
        this.receivedInputs.add(input);
        Integer callCount = this.receivedInputs.size();
        if (callCount == this.throwOnInvocation) {
            throw thrownException;
        }

        return this.returnedResults[callCount - 1];
    }
}
```

Okay, I’ve violated my guideline to avoid `if`. However, this `if` isn't implementing business logic; it's implementing test configuration. Moreover, the point is to keep the mock as simple as possible and keep as much of the logic as possible, in your tests.

At this point, we haven't written a single test. We've simply rearranged our code so that it can be unit tested. That may seem like a lot of work, but we've also made the code more modular, more replaceable, and less tightly coupled. The ability to write true unit tests is really just a side effect of better design.

## How to Test

At long last, we can finally write a true unit test.

```apex
@IsTest
public class FooTest {
    @IsTest
    public static void shouldReturnResultFromBar() {
        // Arrange
        Result expected = new Result();
        BarMock mockBar = new BarMock();
        mockBar.returnedResult = expected;

        Foo subject = new Foo(mockBar);
        Input input = new Input();

        // Act
        Result actual = subject.doSomething(input);

        // Assert
        Assert.areEqual(expected, actual);
        Assert.areEqual(input, mockBar.receivedInput);
    }
}
```

If you've been writing Apex for years, this test may look almost disappointingly simple. That's precisely the point. We're no longer spending most of our effort constructing the environment so that we can test the code. We're testing the code directly.

The test is almost boring.

That's exactly what you want.

Even if this “toy” involved records once we mock out the necessary dependencies, there would be:

- No validation rules to worry about.
- No flows running behind your back.
- No triggers firing.
- No database state to construct.
- No governor limits being consumed.
- No unrelated failures because somebody modified a completely different part of the system.

(I leave database-free, record-based testing as an exercise for the reader.)

When this test fails, the first place to look is Foo.

Suppose we also want to verify that Foo correctly handles an exception.

That becomes equally straightforward, using a different mock.

```apex
@IsTest
private class FooTest {
    @IsTest
    static void shouldPropagateException() {
        // Arrange
        BarMock mockBar = new BarCanFailMock();
        mockBar.throwOnInvocation = 1;
        mockBar.thrownException = new MyException();

        Foo subject = new Foo(mockBar);
        Input input = new Input();

        // Act
        MyException caughtException;
        try {
            subject.doSomething(input);
        }
        catch (MyException expected) {
            caughtException = expected;
        }

        // Assert
        Assert.isNotNull(caughtException);
    }

    private with sharing class MyException extends Exception{}
}
```

Need Bar to return different values on successive calls?

Populate returnedResults.

Need to verify every invocation?

Inspect receivedInputs.

Need completely different behaviour?

Write another mock.

They're just Apex classes.

As your application grows, your tests stay focused. Each test explicitly controls every dependency, making failures easier to understand and dramatically reducing the amount of setup required.

Does this mean you should never write integration tests? Absolutely not. Integration tests verify that your selectors query the database correctly, your DML wrappers perform DML correctly, your services collaborate correctly, and your application behaves as expected inside Salesforce. You should have integration tests.

You should also have unit tests. They serve different purposes.

True unit testing on Salesforce isn't impossible. It simply requires writing your code in a way that makes dependencies replaceable.

Once you start writing code this way, the tests almost write themselves.
