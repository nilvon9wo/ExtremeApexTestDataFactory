# Continuous Integration

`.github/workflows/ci.yml` runs two jobs on every push and PR against `master`
or `4.0-beta`.

**`doc-examples`**, **`doc-links`**, **`apex-style`** — three fast jobs, no org,
no secret, a few seconds each, run in parallel:

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

See [coverage-standards](coverage-standards.md).

**`apex-tests`** — creates a scratch org, deploys `force-app` **and**
`test-support`, runs `XFTY_Unit`, `XFTY_Integration`, `XFTY_Examples`,
`XFTY_OrgOnly`, and `XFTY_PersonAccount`, and deletes the scratch org. The
scratch org enables `PersonAccounts` so the Person Account tests run.

`XFTY_Load` is **not** in CI — it deliberately pushes generation toward the
governor limits, and a shared runner does not have the CPU headroom (a 6 000-row
`insert` alone can exhaust the 10 s limit there). Run it by hand against your own
org when you change the engine.

---

## The one secret

`DEVHUB_SFDX_AUTH_URL` — a **repository secret** (`apex-tests` needs it;
`static-checks` does not):

```bash
# run in a normal terminal, not through a shared session - this reveals a token
sf org auth show-sfdx-auth-url --target-org <your-dev-hub> --no-prompt
```

Copy the `force://...` value into
**Settings → Secrets and variables → Actions → Secrets → New repository secret**,
name it `DEVHUB_SFDX_AUTH_URL`. Treat it like a password — it grants full CLI
access to that Dev Hub. Any Dev Hub works; the workflow does not care which.
