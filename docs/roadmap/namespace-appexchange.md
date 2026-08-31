# Roadmap: Namespace / AppExchange

Status: **📋 proposed**. Medium-term. None of it changes the day-to-day
workflow in [../contribute/packaging.md](../contribute/packaging.md).

The goal is an AppExchange listing under the namespace **`XFTY`**.

---

## The plan

1. **Register the `XFTY` namespace** in a dedicated Developer Edition org and
   link it to a Dev Hub. The namespace is permanent and cannot be moved or
   reused, so it gets its own throwaway-free DE org rather than an existing
   playground.
2. **Add `"namespace": "XFTY"`** to `sfdx-project.json` and switch the package
   type to managed. Contributors keep working unmanaged by blanking that field
   locally (or against a namespaced scratch org). The source in this repo never
   hard-codes `XFTY__` — the packaging build applies it. This is how projects
   like Nebula Logger stay both open source and AppExchange-listed.
3. **Drop the `XFTY_` class-name prefix.** With a real namespace, external
   callers would otherwise write `XFTY.XFTY_DummySObjectProvider`. Removing the
   prefix is a mechanical rename but a **breaking change** for every existing
   consumer, so it belongs in its own PR tied to a major version bump — ideally
   the same release that turns on the namespace.
4. **Promote the framework out of `@IsTest`.** A managed package cannot ship
   `@IsTest`-only code, and the extension points (custom Providers and value
   strategies) would then need real coverage. Same underlying obstacle as
   [sandbox-seeding.md](sandbox-seeding.md).

Steps 1–3 are coordinated and reversible up until the namespace is linked.

---

## Open question

**Step 4** is the significant design decision — how to split a deployable base
from the `@IsTest` layer without making installation painful. See
[sandbox-seeding.md](sandbox-seeding.md) for the split shape and the experiment
that would settle it.
