# Test-User Helpers

`XFTY_DefaultUserDataProvider` — one of the [bundled Providers](../extend/bundled-providers.md)
— exposes helpers for tests that need a specific `User`.

| Member | Returns |
|--------|---------|
| `TEST_ADMIN_USER` | an inserted System Administrator `User`, ready for `System.runAs(...)` |
| `profileIdFor(String profileLabel)` | the `Profile` Id for a profile **label** (cached for the transaction) |
| `roleIdFor(String roleDeveloperName)` | the `UserRole` Id for a role **developer name** (cached for the transaction) |

---

## Running as an admin

```apex
System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
    // setup that needs elevated permissions
}
```

---

## A user with a specific profile and role

```apex
User regionalManager = (User) new XFTY_DummySObjectProvider(User.SObjectType, lookup)
    .setOverrideTemplate(new User(
        ProfileId  = XFTY_DefaultUserDataProvider.profileIdFor('Standard User'),
        UserRoleId = XFTY_DefaultUserDataProvider.roleIdFor('Regional_Manager')
    ))
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .supply();
```

---

## They throw on a miss

`profileIdFor(...)` and `roleIdFor(...)` **throw**
`XFTY_DefaultUserDataProvider.UnknownReferenceException` when the org has no
matching Profile / UserRole — not a `null` that later surfaces as an opaque
`INVALID_CROSS_REFERENCE_KEY` on insert. If a role is genuinely optional for your
test, query for it first
(`[SELECT Id FROM UserRole WHERE DeveloperName = :name]`) rather than catching
the exception.

▶ Runnable: `XFTY_Ex_TestUserHelpersTest` (`TEST_ADMIN_USER`) · `XFTY_DefaultDataProviderOrgTest` (`profileIdFor` / `roleIdFor`, org-only)

See also: [extend/bundled-providers](../extend/bundled-providers.md)
