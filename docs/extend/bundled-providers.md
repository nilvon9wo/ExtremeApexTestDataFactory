# The Bundled Providers

XFTY ships three Providers — `Account`, `Contact`, `User` — wired together by
`XFTY_DefaultSObjectProviderLookup`. They are deliberately generic starting
points. **Copy them into your project and adjust** rather than depending on their
exact defaults.

| Provider | Class |
|----------|-------|
| Business Account | `XFTY_DefaultAccountDataProvider` |
| Contact | `XFTY_DefaultContactDataProvider` |
| User | `XFTY_DefaultUserDataProvider` |
| Lookup wiring them | `XFTY_DefaultSObjectProviderLookup` |

`XFTY_DefaultSObjectProviderLookup` is also the copy-me example for
[writing your own lookup](provider-lookups.md) — it is the exact map-plus-utility
pattern with XFTY's three Providers, and the framework uses it for its own
self-tests.

---

## Test-user helpers

`XFTY_DefaultUserDataProvider` exposes `TEST_ADMIN_USER`, `profileIdFor(label)`,
and `roleIdFor(developerName)` for tests that need a specific `User`. Consumer
usage: [use/test-user-helpers](../use/test-user-helpers.md).

---

## Why copy, not depend

- `@IsTest` classes cannot be `abstract` or `virtual`, so there is no clean
  subclass hook.
- Your org's required fields, validation rules, and record types differ from the
  generic defaults — a copied Provider is where that knowledge lives.
- Depending on the shipped defaults couples your tests to XFTY's release notes.

The Person Account variant in `test-support/`
(`XFTY_PersonAccountDataProvider`) is a worked example of a second Provider for
one type — see [provider-variants](provider-variants.md).
