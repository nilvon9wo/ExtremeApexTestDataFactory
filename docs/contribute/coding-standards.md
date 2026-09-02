# Coding Standards

The rules XFTY code is held to. They apply to anyone changing this repo — human
or AI. When a change is reviewed, this is the checklist.

---

## The three rules everything else serves

**Code must always:**

1. **Be lazy.** Do the least work needed. Never compute a value before you know
   it is wanted — no capturing an operand before a ternary or a short-circuit,
   no eager helper calls "to make it readable".
2. **Communicate intent.** The reader thinks about *what* the code does, not
   *how*. Names carry the meaning; comments do not compensate for bad names.
3. **Correctly balance separation and encapsulation.** Decomposition is driven by
   **intent**, not line count. Before extracting a method or class, answer *why
   should this be its own thing?* If the answer is only "it was long", you are
   about to make lasagne.

---

## Layout

### One expression per line

This means **add line feeds**. It does **not** mean one capture per expression,
one expression per method, or "refactor". You only add a named local when you are
breaking a nested call apart to name its pieces.

```apex
// nested calls -> one named local each; a fluent chain may be one local, broken before the dot
Integer bar = g(x);
Integer baz = f(bar);
Integer bat = a.b()
        .c();
Integer bab = foo(list[i]);
goo(baz, bat, bab);
```

```apex
// construct-then-call -> no local
new XFTY_Thing()
        .doIt();
```

### Compound conditions: capture the whole thing, keep it lazy

```apex
Boolean nothingToFill = expression == null
        || record.get(field) != null;
if (nothingToFill) {
    return;
}
```

Wrap the operator to the next line; keep the short-circuit intact. Do **not**
split the operands into separate `Boolean a = ...; Boolean b = ...;` — that
evaluates both eagerly.

### Ternaries: keep them, break them

Ternaries are preferred over `if`/`else` for choosing a value. Never write them
as one-liners. Break before `?` and before `:`, and indent:

```apex
this.insertMode = (insertMode == null)
        ? XFTY_InsertModeEnum.NEVER
        : insertMode;
```

Do not hoist an operand into a local before the ternary — it forces work that
one branch does not need.

### Methods and nesting

- More than **~10 lines** is too long.
- More than **two blocks deep** is too deep.
- If a method needs comments to divide it into sections, extract the sections.

### Comments

- No section-marker comments in production code — extract the section instead.
- In **tests**, the expected structural markers are `// Arrange`, `// Act`,
  `// Assert`, and `// Sanity Check` (a pre-Act assertion that the arranged
  state is what the test assumes). Use them.
- If a comment restates what a name could say, fix the name instead.
- A doc comment that just re-narrates the signature (`/** The record's Id. Throws
  if not resolved. */` over `getId()` whose throw says exactly that) is noise —
  delete it. Doc comments earn their place by explaining *why*, a non-obvious
  constraint, or a contract a caller cannot see from the signature.
- A class docstring is a few lines and one example, not an essay — the prose
  belongs in `docs/`.

### `this.`

Always explicit — `this.field`, `this.method()`.

### Magic arguments

A bare `true` / `false` / literal passed to a method communicates nothing. Name
it as a `private static final` constant:

```apex
private static final Boolean KEEP_ID = true;
private static final Boolean INCLUDE_RELATED_RECORDS = true;
// ...
record.clone(KEEP_ID, INCLUDE_RELATED_RECORDS, ...);
```

### Parameters

**At most three.** More than three means those values belong together — wrap them
in a named object and pass that.

---

## Naming and member order

### Classes are nouns; methods are verbs

A "doer" class is named for **what it produces**, not what it holds:
`XFTY_RecordCloneFactory` (makes clones), not `XFTY_RecordClones` (which reads as
"this *is* the clones"). `XFTY_DeferredInserter`, not `XFTY_DeferredInsert`.

### Member order within a class

1. Constants consumed by the primary constructor — alphabetised.
2. Instance variables consumed by the primary constructor — alphabetised.
3. The primary constructor. Its parameters **and** its assignments follow the
   order above.
4. The secondary / default constructor. Its parameters follow the same order.
5. (Singleton only) the instance-holding variable.
6. (Singleton only) `getInstance()`.
7. Public methods, in the order they are most likely used (narrative order), or
   alphabetical.
8. Private methods, declared **as close as possible to where they are used** —
   which may put them between public methods.
9. Private methods used equally by many methods go at the bottom (or into a
   helper class if the class is too long).

### Class length

More than **~250 lines** is a strong smell that the class does too much.

---

## Design

- **Polymorphism over branching.** A `null`/`instanceof`/type check that the same
  code makes in more than one place is a missing type. Introduce a strategy
  interface with one implementation per case; the caller stops choosing. A wall
  of near-identical `if (bad) throw` guards collapses the same way — one
  `reject(condition, reason)` helper, one line per rule.
- **Flyweight whenever possible.** Interned instances obtained through a
  `get(...)` factory, never `new`.
- **Explicit over stateful.** Reject registry / mutable-builder APIs. Prefer a
  complete, explicit `Map` plus a stateless utility. Where a collaborator needs
  values you do not yet all have, pseudo-closure the ones you have via the
  constructor; where it needs many things at once, a fluent builder is
  acceptable.
- **Immutability.** Clone aggressively; derive a new object rather than mutating.
- Remove dead code rather than working around it.

---

## Apex gotchas

- **Enum comparison:** use `==`, not `.equals()` — null-safe, idiomatic, and
  `.equals()` is not implemented in the Nimbus local runtime.
- **Identifier case collisions:** never name a local after an SObject type it
  references — `Account account` then `Account.Field` parses as
  `account.Field`. `list`, `map`, `set` are reserved and cannot be identifiers.
- **Empty DML is free:** `insert new List<X>()` costs 0 DML statements, 0 rows —
  do not guard it.
- **`Set<SObjectField>` from a keySet:** `new Set<SObjectField>(map.keySet())`,
  `keySet().clone()`, and `keySet().contains(f)` all misbehave under Nimbus —
  build the set with `.addAll(map.keySet())`.

---

## Testing and coverage

- **Line coverage ~100%**, verified by stripping `@IsTest` and running with
  `--code-coverage` (see [local-development](local-development.md#measuring-coverage)).
- **Branch coverage is the real goal** — every guard, `switch`, and ternary,
  both sides, checked by hand. The platform cannot measure it.
- **The framework must never make a consumer debug it.** Any error that could
  trace back to XFTY is loud: a clear `XFTY_DummySObjectFtyProviderException`
  naming the misconfiguration and the fix — never a silent `null` or an opaque
  downstream DML error. Accessors that can miss throw at the call site.
- **One test class per unit under test**, sitting beside it (suites group by
  class). `XFTY_Foo.cls` → `XFTY_FooTest.cls`; do not let one test class cover a
  whole subsystem. Split a class that mixes DML-free and DML-backed methods.
- **One behaviour per test method.** A positive and a negative case are two
  behaviours — two methods. Every assertion must be about the single value
  captured in the Act; an assertion that re-invokes the code under test (with
  other inputs) is a second Act in disguise and a *tell* that the test is doing
  too much.
- **The Act is exactly one statement.** Declare the result variable in Arrange,
  assign it in Act, read it in Assert. Nothing acts in Assert.
- **Wrap the Act in `Test.startTest()` / `Test.stopTest()`** — always; it costs
  nothing and demarcates the code under test. **Add `System.runAs(TEST_ADMIN)
  { … }` around it only when the test does DML or SOQL, or the code under test
  reads the running user** (FLS/CRUD enforcement, sharing, `UserInfo`,
  `OwnerId`/`CreatedById`). A pure `Boolean` on an in-memory SObject needs no
  `runAs` — see `XFTY_LookupKeyTest`. `TEST_ADMIN` is
  `XFTY_DefaultUserDataProvider.TEST_ADMIN_USER`; it re-inserts a User per test
  method, so it is not free.
- **Names:** `test<MethodUnderTest>_when<Condition>_<expectedOutcome>` —
  `testIsSatisfiedBy_whenTheFieldIsBlank_returnsFalse`,
  `testOf_whenTheListIsNull_throws`. For an end-to-end / scenario test,
  `<MethodUnderTest>` is the entry point exercised (`testSupply_…`,
  `testSupplyBundle_…`, `testFlush_…`).
- **Parameterised tests:** a thin `@IsTest` method is one call to a shared runner
  that holds the `// Arrange` / `// Act` / `// Assert`; the `@IsTest` methods are
  just the data rows. (`check-apex-style.py` exempts a single-call test body from
  the marker rule for exactly this.) Helper names: the runner is `test<Method>(…,
  expected)` (no `@IsTest`); fixtures are `create…`; shared assertions are
  `assert…`.
- **`Assert.*`, never `System.assert*`.** Expecting a throw: capture it in Act
  (`try { act(); } catch (XFTY_SpecificException ex) { thrown = ex; }` — the
  *exact* type, never bare `Exception`) and assert on `thrown` in Assert
  (`Assert.isNotNull(thrown, …)` then check its message).
- **Test doubles are code too.** Do not paste near-identical
  `XFTY_DummySObjectProviderLookupIntf` inner classes — use
  `XFTY_ProviderLookups.of(map)` behind a named fixture helper. Collapse
  near-identical Provider doubles into one parameterised inner class.
- **The gold-standard shape:** class-level constants (incl. `TEST_ADMIN` where
  it is needed), thin data-row `@IsTest` methods, one `test<Method>(…)` runner
  holding `// Arrange` / `// Act` / `// Assert`, and `create…` / `assert…`
  helpers at the bottom. `XFTY_FieldEqualToPredicateTest` and
  `XFTY_ValueComparisonTest` are the live examples.
- Everything in `## Style` applies: `Assert` calls broken off chained builders,
  no one-line ternaries, named constants over magic numbers, `~250` / `~10` line
  bars.

```apex
// data rows
@IsTest
static void testIsSatisfiedBy_whenFieldEqualsValue_returnsTrue() {
    testIsSatisfiedBy('Technology', new Account(Industry = 'Technology'), true);
}
@IsTest
static void testIsSatisfiedBy_whenFieldDiffersFromValue_returnsFalse() {
    testIsSatisfiedBy('Technology', new Account(Industry = 'Retail'), false);
}
// runner — one Act statement, wrapped; no runAs (no DML/SOQL)
static void testIsSatisfiedBy(Object configuredValue, SObject record, Boolean expectedResult) {
    // Arrange
    XFTY_SObjectPredicateIntf predicate = XFTY_FieldEqualToPredicate.of(Account.Industry, configuredValue);
    // Act
    Test.startTest();
    Boolean actualResult = predicate.isSatisfiedBy(record);
    Test.stopTest();
    // Assert
    Assert.areEqual(expectedResult, actualResult);
}
```

---

## Working in the repo

- Fix defects **on the working branch, in their own commits**, separate from
  feature work.
- **Never** `git checkout <ref> -- .` or `git checkout <file>` to undo an edit —
  it also discards unrelated changes to that file. Restore specific content with
  `git show <ref>:<path>` or a scripted text edit.
- Commit trailers where applicable:
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` and `Claude-Session:`.
