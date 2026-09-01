# Coverage Standards

## The framework must never make a consumer debug it

A test that fails because of an XFTY bug should say so loudly. A consumer whose
test fails has three possible culprits — their code under test, their own test,
and the framework — and almost no way to tell the framework apart from the other
two. So:

- **Any error that can trace back to the framework is loud** — a clear
  `XFTY_DummySObjectFtyProviderException` (or similar) naming the misconfigured
  field / relationship / call and the fix, never a silent `null` or an opaque
  downstream DML error. Example: `context.siblingValue(field)` throws, naming
  both fields and the `put` order, rather than returning a misleading `null`
  ([../use/context-aware-values.md](../use/context-aware-values.md)).
- **Accessors that can miss throw at the call site.**
  `XFTY_DefaultUserDataProvider.profileIdFor` / `roleIdFor` throw
  `UnknownReferenceException` rather than returning `null`.

---

## Line coverage is the floor; branch coverage is the goal

Salesforce measures only **line** coverage. That is the minimum, not the target.
The real target is **branch** coverage — every guard, every `switch`, every
ternary, both sides. Salesforce can neither measure nor enforce that, so it is on
the author: when you touch a method, make sure every branch has a test, not just
every line.

- The line-coverage target is **100%**, verified on an **org**: temporarily
  strip `@IsTest`, deploy `force-app` + `test-support`, run every suite
  (`XFTY_Unit`, `XFTY_Integration`, `XFTY_Load`, `XFTY_Examples`, `XFTY_OrgOnly`,
  and `XFTY_PersonAccount` on a Person-Account org)
  with `--code-coverage` (see
  [local-development](local-development.md#measuring-coverage)). The local Apex
  runtime's coverage numbers are **not** reliable — it under-reports classes
  exercised only through in-test Provider doubles — so it cannot stand in for the
  org check. Re-run the org check after any engine change or large rename.
- Branch coverage is reviewed by hand on every change.
- Remove dead code rather than covering it.

Scenarios still worth explicit tests as the engine grows: many-level graphs,
circular relationships beyond `PREVENT_CASCADE`, and the open items in
[../reference/known-issues.md](../reference/known-issues.md).

---

## Every doc example is a runnable test, mechanically enforced

Line and branch coverage are about the framework's own code. A separate,
equally real risk is the **docs drifting from the code they describe** — an
example that reads correctly but no longer compiles, or asserts something that
stopped being true.

`scripts/verify-doc-examples.py` closes that gap: it extracts every significant
call from every ```apex``` block on a page carrying a `Runnable:` line, and
fails if that exact call (whitespace- and case-normalised) is not present in
the test class(es) the page names. It runs in CI on every push and PR — a doc
example and its test cannot drift apart without breaking the build.

A fence marked `<!-- sketch -->` immediately above it is exempt — reserved for
illustrative project-specific code (a consumer's own `SObjectType`s, lookup-key
classes) that cannot run against the bundled `Account` / `Contact` / `User`
Providers. Everything else tagged ```apex``` is a promise: copy it, and it runs.
