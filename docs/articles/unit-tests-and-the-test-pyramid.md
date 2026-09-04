# Why I still advocate for Unit Tests and the Test Pyramids in 2026

It’s 2026 and Martin Fowler’s Test Pyramid is no longer “the flavour of the day”. Testing tends to be lean, whether from philosophy, time pressures, laziness, or sloppiness – perhaps a combination of all of these.

To some extent, in many contexts, such as the proliferation of microservices, this makes sense. We shouldn’t be testing just for the sake of testing. Microservices, frequently don’t have much functionality to test, nor many places for bugs to hide. Moreover, modern programming paradigms frequently avoid nulls, mutations, and side effects.

But this is not a good approach for every solution and I’m particularly concerned with lean testing in monolyths.

One might argue my resistance is one of “teaching old dogs new tricks”, but depending on perspective, I’m either older than that or not that old – and as mentioned, I will advocate for lean testing in certain contexts. However, I learned the value of the test pyramid the hard way – and I think much of it is being overlooked with modern trends despite it being faster and easier than ever to create a proper test pyramid.

To be anecdotal and nostalgic for a moment, when I started programming in BASIC on the Commodore Vic 20 and the Apple 2e, I never heard of automated testing. Programming was a matter of typing lines onto a command line and running the application and manually looking for bugs; of course this was not a professional approach and I was far too young to be a professional.

Fast forward 30 years to 2007 and I’ve finally been exposed to unit testing, but I didn’t know what it really meant. I was developing Apex on Salesforce, where the term “unit test” was used to describe every automated test, which were frequently (as I later learned) integration tests and load tests. I spent the next 6 years creating mostly integration tests – if I wrote a real unit test, it was only by “luck” that there was nothing to integrate with.

In 2013, I was working with Java engineers who drew the short straw and ended up on a Salesforce project. They pointed out that all the tests we were writing were actually integration tests, explained the difference, and wanted to know how to write real unit tests.

What happened next might only interest a small subset of Salesforce developers, so I’ll skip forward to mentioning that it was around this time that I learned about the Martin Fowler’s Test Pyramid – and learned to appreciate that this *is* the correct way to test software.

In short, the idea is to write lots of unit tests, some integration tests, and very few end-to-end tests. The idea is that tests get slower, more expensive, and more fragile as they get closer to the user interface, so most of your confidence should come from the bottom of the pyramid, not the top.

Having had previous experience with testing, I found my solutions became robust and my tests became more stable – and useful – once I began developing test pyramids.

First, I’d always start from the bottom of the pyramid – writing unit tests – and then work my way up. Even before the first line of test code was written, this was useful because it forced me to review every line of code, to make sure it made sense and was composed to the best of my ability. It made me consider every branching condition or possible null and prove there are no defects or gaps in my logic and that they were properly handled or documented.

Shift left: Each of these would never show up in production – or even on a QA’s doorstep – reducing the cost of diagnosing and resolving the concerns.

Because I had the unit tests, writing integration tests became easier. The unit tests would help shape the data I needed to provide to the integration tests, as I’d already have models I could reuse (perhaps with some tweaks to pass validation). Moreover, because I could trust the logic in the dependencies, I no longer needed to play plinko with the data, attempting to cover diverse branching logic – it was all covered: I just needed to make sure everything worked together as expected. Thus my solutions were very thoroughly covered.

But this was not coverage for coverage sake – when executed on the pipeline, they would prevent regressions. When the tests failed, the unit tests frequently provided much more precise information where (and sometimes even how) to resolve the issues than integration tests ever could. And when the tests did not fail and were not pointing out where the errors were, the coverage helped to eliminate the covered code as a likely source for errors in question. In short, debugging errors became quicker and easier.

But the benefits do not end there. Consider refactoring.

One of the most common arguments I hear these days against unit tests is that they get in the way of refactoring.

I disagree.

Unit tests provide the confidence needed to refactor safely. If a solution is not intended to behave completely different, unit tests help identify which code is safe to reuse and how it is expected to behave. When tests fail during a refactor, the developer performing the work has the context necessary to determine whether the failure represents an obsolete behavior that should be removed or a valuable use case that has accidentally been lost.

That is not an obstacle to change; it is a safeguard against unintended change.

There is another important benefit to tests, hinted at earlier: tests are documentation.

Well-written tests demonstrate how functionality is intended to be used and what outcomes are expected. When a developer encounters an unfamiliar method, they do not need to reverse-engineer every implementation detail to understand its purpose. They can look at the tests and see examples of the behavior that was considered correct when the functionality was written.

Will this bloat a pull request?

Certainly.

But is that really a good reason to skip writing the tests?

Do we honestly believe a reviewer can mentally compile a solution and reason through every possible execution path better than a suite of automated tests can?

Of course not!

A good set of tests makes code review easier. The tests provide evidence that the code behaves correctly, allowing reviewers to focus more of their attention on maintainability, readability, architecture, and design.

As for reviewing the tests themselves, they generally do not require the same level of scrutiny as production code. They should absolutely be spot-checked for sanity, adherence to platform best practices and team standards, appropriate use of test infrastructure, and for obvious gaps in coverage such as missing positive or negative paths, edge cases, and boundary conditions. They should also be reviewed—particularly in the age of AI-generated code—to ensure they are actually testing something meaningful. But if a test is failing or performs poorly, the pipeline will often expose that quickly.

None of this means every project requires an enormous suite of tests. Different architectures, technologies, and risk profiles call for different testing strategies. A simple microservice may require relatively few tests compared to a large business-critical monolith.

What concerns me is not lean testing itself, but the tendency to dismiss unit testing and the test pyramid altogether.

The Test Pyramid was not invented because developers enjoyed writing tests. It emerged because people repeatedly discovered that relying primarily on integration and end-to-end testing was slow, fragile, expensive, and difficult to maintain.

In 2026, it is easier than ever to write automated tests. Tooling is better, frameworks are better, and AI can assist with much of the boilerplate. Yet many teams seem to be moving away from the very practices that decades of experience taught us were effective.

The Test Pyramid may no longer be fashionable, but fashion was never the point.

The point was building reliable software, catching defects early, refactoring with confidence, and reducing the overall cost of change.

Those benefits have not disappeared. If anything, they matter more now than ever.
