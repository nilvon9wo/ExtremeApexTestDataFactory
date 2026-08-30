# Packaging & Development

XFTY is a Salesforce DX project in **source format**. Everything deployable lives
under `force-app/`.

---

## Local development

Prerequisites: the [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
and a Dev Hub (any Developer Edition org or a production org with Dev Hub enabled).

```bash
# one-time: connect your Dev Hub
sf org login web --set-default-dev-hub --alias devhub

# spin up a scratch org, push the code, run the suite
sf org create scratch --definition-file config/project-scratch-def.json --alias xfty --set-default --duration-days 7
sf project deploy start
sf apex run test --test-level RunLocalTests --code-coverage --result-format human

# when finished
sf org delete scratch --target-org xfty --no-prompt
```

Because the whole framework is `@IsTest`, Salesforce reports 0% coverage for it -
that is expected. The behavioural suite under
`force-app/main/default/classes/tests/` is what guards the framework; it is kept
at 100% line coverage (verify by temporarily stripping `@IsTest` and running
`sf apex run test --code-coverage`).

`force-app/main/default/classes/` is organised into `core/`, `values/`,
`relationships/`, `lookup/`, `providers/`, and `tests/`. The `test-support/`
package directory holds examples that need an org feature the published package
must not require - currently a Person Account Provider, its variant test, and the
"real record type" tests - and is **not** part of the distributable package
(`"default": false` in `sfdx-project.json`, excluded from `sf package version
create`, deployed to scratch/dev orgs). The CI scratch org enables
`PersonAccounts` so those tests run.

---

## Test suites

XFTY defines three `ApexTestSuite`s so you can run only what you need:

| Suite | Location | What's in it | When to run |
|-------|----------|--------------|-------------|
| `XFTY_Unit` | `force-app` | Every class that generates with `MOCK` / `NEVER` / `LATER` only - no framework DML, no dependency on org data. Includes the whole generation engine. | Constantly, while developing. Fastest. |
| `XFTY_Integration` | `force-app` | The classes that do real DML - `NOW` / `RELATED_ONLY` insert modes and the bundled Providers persisting records. Sensitive to org config. | Before a commit; in CI. |
| `XFTY_Load` | `test-support` | `XFTY_LoadTest` - volume and governor-budget ceilings (CPU, heap, DML-per-level). Its assertions assume a quiet org, so it is **not** shipped in the package. Where the shared-ancestor DML measurements will live (see [design/shared-ancestors.md](design/shared-ancestors.md)). | On demand, and when changing the engine. Slowest. |

```bash
sf apex run test --suite-names XFTY_Unit --result-format human            # fast loop
sf apex run test --suite-names XFTY_Unit --suite-names XFTY_Integration   # pre-commit
sf apex run test --suite-names XFTY_Load                                  # engine changes (needs test-support deployed)
```

A test class that mixes DML-free and DML-backed methods is split (e.g.
`XFTY_DummySObjectFactoryTest` keeps the matrix that needs no DML;
`XFTY_DummySObjectFactoryDmlTest` has the `NOW` / `RELATED_ONLY` cases). Suites
group by class, so keep new test classes single-purpose. The other `test-support/`
tests (`XFTY_PersonAccountVariantTest`, `XFTY_RecordTypeRealRtTest`) are not in a
suite - CI's `RunLocalTests` runs them, along with `XFTY_LoadTest`, on the scratch
org.

---

## Continuous integration

`.github/workflows/ci.yml` creates a scratch org, deploys, runs every local test,
and deletes the scratch org, on every push and PR against `master`.

It needs one repository secret, **`DEVHUB_SFDX_AUTH_URL`**:

```bash
# authenticate the Dev Hub locally, then print its auth URL
sf org display --target-org devhub --verbose --json | jq -r '.result.sfdxAuthUrl'
```

Copy the `force://...` value into
`Settings -> Secrets and variables -> Actions -> New repository secret`.
Treat it like a password - it grants full access to that Dev Hub.

---

## Consuming XFTY (no namespace, today)

Deploy the classes straight into a scratch org, sandbox, or production org:

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

Or convert to an **unlocked package** (no namespace) for versioned installs:

```bash
sf package create --name XFTY --package-type Unlocked --path force-app
sf package version create --package XFTY --installation-key-bypass --wait 20 --code-coverage
sf package install --package XFTY@x.y.z-n --target-org <alias> --wait 10
```

`sf package create` writes the package id and alias back into `sfdx-project.json`.

---

## Roadmap to AppExchange (namespaced, later)

The medium-term goal is an AppExchange listing under the namespace **`XFTY`**.
None of that changes the day-to-day workflow above; the plan is:

1. **Register the `XFTY` namespace** in a dedicated Developer Edition org and link
   it to a Dev Hub. The namespace is permanent and cannot be moved or reused, so
   it gets its own throwaway-free DE org rather than an existing playground.
2. **Add `"namespace": "XFTY"`** to `sfdx-project.json` and switch the package
   type to managed. Contributors keep working unmanaged by blanking that field
   locally (or against a namespaced scratch org). The source in this repo never
   hard-codes `XFTY__` - the packaging build applies it. This is exactly how
   projects like Nebula Logger stay both open source and AppExchange-listed.
3. **Drop the `XFTY_` class-name prefix.** With a real namespace, external
   callers would otherwise write `XFTY.XFTY_DummySObjectProvider`. Removing the
   prefix is a mechanical rename but a **breaking change** for every existing
   consumer, so it belongs in its own PR tied to a major version bump - ideally
   the same release that turns on the namespace.
4. **Promote the framework out of `@IsTest`.** A managed package cannot ship
   `@IsTest`-only code, and the extension points (custom Providers and value
   strategies) would then need real coverage. See `docs/future-ideas.md` -
   "Sandbox Data Seeding" for the same underlying obstacle.

Steps 1-3 are coordinated and reversible up until the namespace is linked.
Step 4 is the significant design decision.
