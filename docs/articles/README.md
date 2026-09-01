# Background & Philosophy

Longer-form essays on the thinking behind XFTY, by the author. They are personal
opinion pieces — first published on LinkedIn — kept here for context. They are
**not** part of the reference documentation, they don't track the current API,
and nothing in [`docs/use/`](../use/) or [`docs/extend/`](../extend/) depends on
them.

| Essay | What it covers |
|-------|----------------|
| [The Trivial Request That Changed How I Design Software](the-trivial-request.md) | Where XFTY came from: a single field flipped from optional to required in 2013, a factory class, two rewrites, and the through-line of every version — *remove another decision from the caller*. |
| [Why I Still Advocate for Unit Tests and the Test Pyramid in 2026](unit-tests-and-the-test-pyramid.md) | The case that lean testing has gone too far in monoliths — what the test pyramid actually buys you (shift-left defects, safe refactoring, tests as documentation, easier review). |
| [Unit Testable Apex: How to Stop Fighting the Salesforce Database](unit-testable-apex.md) | The practical how-to: dependency injection and hand-written test doubles instead of the Stub API, so an Apex "unit test" is actually isolated from the database. This is the style XFTY's `MOCK` mode is built to support. |

Read them in that order for the full arc: why the framework exists → why isolated
unit tests are worth the effort → how to actually write them.
