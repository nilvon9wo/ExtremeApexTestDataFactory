# stubs/

This directory holds **user stub** files for managed packages and types
Nimbus doesn't know about natively. If your tests reference types from a
managed package — for example `Nebula.LogEntryEventBuilder` from
nebula-logger or anything in the `fflib_` namespace — Nimbus
needs to know how to treat them.

## When you need a stub

You'll know when you see a warning like:

```
⚠ Found references to managed package 'Nebula' with no stub configured.
```

That's Nimbus telling you it encountered a type it can't resolve.

## Two ways to handle managed packages

### 1. Treat the whole namespace as opaque (most common)

Add the namespace to `nimbus.properties`:

```properties
nimbus.stubs.namespaces=Nebula,fflib
```

Nimbus will silently auto-stub any reference to a type in those
namespaces. Method calls return null/zero/empty, side effects are
no-ops. This is what you want 95% of the time — managed packages
your tests don't actually exercise behaviorally.

### 2. Define explicit stub behavior (advanced)

For managed packages you DO need test-time behavior from, drop a
`<Namespace>.cls` file in this directory. Each declares the
methods you call and what they return. See examples and full reference at:

  https://testnimbus.dev/docs/managed-packages

## Commit this directory

This README and any stub files belong in git so your team shares one
configuration. The empty directory itself doesn't need to be committed
if you don't add stubs — git ignores it. The README ensures it shows up.
