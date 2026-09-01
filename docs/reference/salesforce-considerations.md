# Salesforce Considerations

The most significant constraint on XFTY is simply that Salesforce is a heavily
limited platform, with extra limits on what and how much can run inside an Apex
test context. That is a Salesforce limitation, not an XFTY one; the exact ceilings
vary by org and are out of scope here.

The most *surprising* constraint — the one worth reading this page for — is the
interaction between Salesforce's `@TestSetup` mechanism and static variables.

---

# `@TestSetup` Is Not Supported

XFTY is **not compatible with Salesforce's `@TestSetup` annotation.**

Although `@TestSetup` is often presented as a best practice for reducing duplicated test setup, Salesforce implements it in a way that conflicts with how XFTY generates data.

Specifically, Salesforce resets static variables between the execution of `@TestSetup` and the individual test methods.

XFTY relies on static state for several internal value providers, including those responsible for generating:

- incrementing values
- unique values
- deterministic sequences

These static variables **are not used to communicate between tests**. Each test method still executes in its own isolated transaction.

Instead, they are used to ensure that values generated within a single test run remain consistent and unique.

Because Salesforce resets this state after `@TestSetup` completes, the framework can no longer guarantee those properties.

The result is that generated data may become unreliable or unexpectedly duplicated.

For this reason, XFTY intentionally does not support use from `@TestSetup`.

---

# Why Does XFTY Use Static Variables?

Several default value providers intentionally maintain internal state.

For example, an incrementing value provider should produce:

```text
Test 1
Test 2
Test 3
...
```

rather than repeatedly returning:

```text
Test 1
Test 1
Test 1
```

Similarly, providers responsible for generating unique email addresses or usernames must coordinate with previous values generated during the same test execution.

Maintaining this state internally keeps Provider implementations simple while ensuring generated data remains realistic.

---

# Recommended Pattern

Instead of using `@TestSetup`, prefer creating shared test fixtures using `static` variables on the test class itself.

For example:

```apex
private static final XFTY_DummySObjectProviderLookupIntf lookup = new TEST_DummySObjectFactoryOutletLookup();

private static final List<Account> TEST_ACCOUNT_LIST = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
            .setInsertMode(XFTY_InsertModeEnum.MOCK)
            .supplyList();

private static final Account TEST_ACCOUNT = TEST_ACCOUNT_LIST[0];
```

Individual test methods can then use these shared fixtures directly.

```apex
@IsTest
static void testExample() {
    System.assertNotEquals(null, TEST_ACCOUNT);
}
```

This approach has several advantages over `@TestSetup`.

- The data used by each test is immediately visible.
- Shared fixtures are declared alongside the tests that use them.
- XFTY's value providers continue to behave correctly.
- No additional framework support is required.

Most importantly, this pattern remains reliable because Apex does **not** use static variables to communicate between test methods.

Each test method executes in its own isolated transaction with its own copy of static state.

The only unsupported scenario is Salesforce's special handling of `@TestSetup`, which resets static variables between setup execution and the test methods that follow.

# When Static Fixtures Aren't Enough

Occasionally, test data cannot be declared as a static variable because it depends on the order of operations within the test.

In these situations, simply create helper methods that generate the required data.

These helper methods may be:

- private methods within the test class, or
- shared utility methods when multiple test classes need the same setup.

Although the helper executes each time it is called, this is rarely a performance concern when using mock data rather than performing database inserts.

Favor readability over premature optimization.

---

# Platform-Specific Behaviour

XFTY attempts to abstract many Salesforce quirks, but it cannot eliminate them entirely.

Provider authors should remain aware that features such as:

- Validation Rules
- Flows
- Apex Triggers
- Duplicate Rules
- Required Record Types
- Custom business logic

may impose additional requirements beyond what Salesforce metadata alone describes.

As these requirements evolve, the appropriate place to update them is the relevant Provider rather than individual tests.

This centralization is one of the primary benefits of XFTY.

---

# Future Considerations

Salesforce continues to evolve, and future platform changes may remove or introduce additional limitations.

Wherever possible, XFTY is designed so that platform-specific workarounds remain isolated within the framework rather than affecting test code.

Should Salesforce eventually address the interaction between `@TestSetup` and static variables, this limitation may be revisited.

---

# Summary

The only significant platform limitation currently known is the interaction between `@TestSetup` and static variables.

Avoiding `@TestSetup` ensures that XFTY can reliably generate deterministic, unique test data while keeping test setup concise through centrally maintained Providers.