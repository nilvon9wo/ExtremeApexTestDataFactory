/**
 * Optional companion to `XFTY_DummySObjectProviderLookupIntf`. A project whose
 * Providers reference [shared ancestors](../../../docs/use/shared-ancestors.md)
 * implements this on its lookup too, so those shared ancestors have a default
 * configuration and the Providers work without every test registering them by
 * hand.
 *
 * `XFTY_SharedAncestorResolver` calls `registerSharedAncestorDefaults()` once
 * before each `supply*()` call resolves shared ancestors. A test that wants a
 * different shared record registers it first (`XFTY_SharedAncestor.put(...)` /
 * `putAsTemplate(...)`); the defaults should use `putIfAbsent`, which leaves an
 * already-registered name alone.
 *
 * A lookup that never references a shared ancestor does not implement this.
 */
//@IsTest
public interface XFTY_SharedAncestorDefaultsIntf {
    /**
     * Register this lookup's shared-ancestor defaults, e.g.
     * `XFTY_SharedAncestor.putIfAbsent('acme-hq', new Account(Name = 'ACME HQ'));`
     */
    void registerSharedAncestorDefaults();
}
