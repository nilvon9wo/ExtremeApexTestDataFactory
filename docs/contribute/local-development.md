# Local Development

XFTY is a Salesforce DX project in **source format**. Everything deployable lives
under `force-app/`; `test-support/` holds examples that need an org feature the
published package must not require.

Prerequisites: the
[Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) and a Dev
Hub (any Developer Edition org, or a production org with Dev Hub enabled).

---

## Scratch-org loop

```bash
# one-time: connect your Dev Hub
sf org login web --set-default-dev-hub --alias devhub

# spin up a scratch org, push, run the suite
sf org create scratch --definition-file config/project-scratch-def.json --alias xfty --set-default --duration-days 7
sf project deploy start
sf apex run test --test-level RunLocalTests --code-coverage --result-format human

# when finished
sf org delete scratch --target-org xfty --no-prompt
```

Reuse a scratch org across runs — Apex tests clean up after themselves, so a
reused org stays fine, and you can `sf project delete source` stale classes
rather than recreating the org.

---

## Nimbus — the fast inner loop

[Nimbus](https://testnimbus.dev/) is a local Apex runtime. `nimbus test "*"` runs
the whole suite in seconds with no org. Config is in `nimbus.properties`
(committed); `.nimbus/` is gitignored. It is a third-party tool this project
uses for the inner loop only and does not endorse or depend on — see
[about-nimbus](about-nimbus.md).

```bash
nimbus test "*"                                   # everything
nimbus test "XFTY_ContextAwareValueTest"          # one class
nimbus exec path/to/scratch.apex                  # anonymous Apex
```

Known fidelity gaps on this project — confirm on a real org before declaring
done:

- `enum.equals(x)` is unimplemented (the code uses `==` instead).
- PersonAccount record-type describe, SOQL query-caching counts, and
  `UnknownReferenceException` on an invalid Profile/Role Id all differ from the
  platform.
- `new Set<SObjectField>(map.keySet())`, `map.keySet().clone()`, and
  `map.keySet().contains(f)` return `false` from `contains` — build the set with
  `.addAll(map.keySet())` instead (works on both).

The current baseline: `nimbus test "*"` → 243 tests, 232 pass, 11 known-gap
fails.

---

## Measuring coverage

Because the whole framework is `@IsTest`, Salesforce reports 0% line coverage for
it — that is expected. To measure it, temporarily strip the annotation and
re-run:

```bash
# strip @IsTest from the framework classes you touched
perl -0777 -pe 's/^\@IsTest\r?\n//m' -i force-app/main/default/classes/<area>/<Class>.cls
sf project deploy start -o <org>
sf apex run test -o <org> --suite-names XFTY_Unit --suite-names XFTY_Integration --code-coverage --result-format human
# then restore — re-add the annotation with perl/sed, NOT `git checkout` (it also
# reverts unrelated edits to the same file)
```

See [coverage-standards](coverage-standards.md) for the bar this is measured
against.
