# Test Suites

XFTY defines `ApexTestSuite`s so you can run only what you need.

| Suite | Location | What's in it | When to run |
|-------|----------|--------------|-------------|
| `XFTY_Unit` | `force-app` | Every class that generates with `MOCK` / `NEVER` / `LATER` only — no framework DML, no dependency on org data. Includes the whole generation engine. | Constantly, while developing. Fastest. |
| `XFTY_Integration` | `force-app` | The classes that do real DML — `NOW` / `RELATED_ONLY` insert modes and the bundled Providers persisting records. Sensitive to org config. | Before a commit; in CI. |
| `XFTY_Load` | `test-support` | `XFTY_LoadTest` — volume and governor-budget ceilings (CPU, heap, DML-per-level). Assertions assume a quiet org, so it is **not** shipped in the package. | On demand, and when changing the engine. Slowest. |
| `XFTY_Examples` | `test-support` | `XFTY_Ex_*Test` — the runnable versions of every [use/](../use/) doc example. Guards the documented public API. | With the docs; in CI. |

```bash
sf apex run test --suite-names XFTY_Unit --result-format human            # fast loop
sf apex run test --suite-names XFTY_Unit --suite-names XFTY_Integration   # pre-commit
sf apex run test --suite-names XFTY_Load                                  # engine changes (needs test-support deployed)
sf apex run test --suite-names XFTY_Examples                              # doc examples
```

Keep test classes single-purpose — suites group by class. A class that mixes
DML-free and DML-backed methods is split (e.g. `XFTY_DummySObjectFactoryTest`
keeps the no-DML matrix; `XFTY_DummySObjectFactoryDmlTest` has the `NOW` /
`RELATED_ONLY` cases). A class with two clearly different *jobs* is also split:
`XFTY_DummySObjectProviderApiTest` (one test per fluent-API affordance) vs.
`XFTY_DummySObjectProviderScenarioTest` (end-to-end "does the whole flow work").
Each test class lives in the same folder as the class it exercises.

The other `test-support/` tests (`XFTY_PersonAccountVariantTest`,
`XFTY_RecordTypeRealRtTest`) are not in a suite — CI's `RunLocalTests` runs them
on the scratch org, which enables `PersonAccounts`.
