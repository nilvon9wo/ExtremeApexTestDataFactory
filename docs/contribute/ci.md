# Continuous Integration

## `ci.yml` — every push and PR (`master`, `4.0-beta`)

Four jobs, run in parallel.

**`doc-examples`**, **`doc-links`**, **`apex-style`** — no org, no secret, a few
seconds each:

- **`verify-doc-examples.py`** — every significant call in every ```apex``` block
  on a page with a `Runnable:` line must appear, verbatim, in the test class(es)
  that line names. A fence marked `<!-- sketch -->` (illustrative
  project-specific code) is exempt.
- **`verify-doc-links.py`** — every relative link and `#anchor` in `docs/**`
  resolves.
- **`check-apex-style.py`** — whole-tree: no identifier over 40 characters, no
  `@IsTest` on an interface (both reject on a real org). Changed `.cls` files
  only (so legacy tests are not retro-failed): `Assert.*` not `System.assert*`,
  `// Arrange` / `// Act` / `// Assert` markers on every `@IsTest`, no local
  shadowing an SObject type, no method over three parameters.

**`validate`** — a **check-only** deploy against a persistent org: `sf project
deploy start --dry-run` compiles the whole source and runs `XFTY_Unit`,
`XFTY_Integration`, `XFTY_Examples`, and `XFTY_OrgOnly` in a validation
transaction, then rolls everything back. The org is never modified — no scratch
org, no Dev Hub, no drift, no quota. (`sf project deploy start` takes an explicit
`--tests` list, not `--suite-names`; `scripts/list-suite-classes.sh` expands the
suites.)

`XFTY_PersonAccount` and `XFTY_Load` are not here — see below.

See [coverage-standards](coverage-standards.md).

## `full-suite.yml` — scheduled (03:17 and 15:17 UTC) and on demand

A **fresh scratch org**, full deploy, then:

- `XFTY_Unit` / `XFTY_Integration` / `XFTY_Examples` / `XFTY_OrgOnly` /
  `XFTY_PersonAccount` — must pass. The scratch org has `PersonAccounts`, which
  the `validate` org does not.
- `XFTY_Load` — informational (`continue-on-error`). It deliberately pushes
  generation toward the governor limits, so a slow scratch org can trip the CPU
  limit; a red here is a hint to look, not a build break.

`schedule` runs against the default branch, so the workflow pins the checkout to
`4.0-beta` for now — change that to `master` when 4.0 ships. Trigger a run by
hand from the **Actions** tab (**Run workflow**), optionally against any ref.

Two scheduled runs a day = two scratch orgs a day, leaving four of the free Dev
Hub's six for manual work. Adjust the `cron` lines if that is too tight.

---

## Secrets

Both are **repository secrets** (Settings → Secrets and variables → Actions →
Secrets → New repository secret). Get the value in a **normal terminal** — it
reveals a refresh token:

| Secret | Value | Used by |
|--------|-------|---------|
| `CI_ORG_AUTH_URL` | `sf org auth show-sfdx-auth-url --target-org <persistent-org> --no-prompt` — an org with the current XFTY source deployed | `ci.yml` `validate` |
| `DEVHUB_SFDX_AUTH_URL` | `sf org auth show-sfdx-auth-url --target-org <dev-hub> --no-prompt` | `full-suite.yml` |

If the `validate` org drifts (a source change removes a type an existing org
class depends on, so the org stops compiling), the dry-run fails until the org is
resynced — deploy the current source to it once, with
`--pre-destructive-changes` if classes were renamed or removed.
