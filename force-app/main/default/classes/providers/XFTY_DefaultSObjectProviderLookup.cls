/**
 * XFTY's own Provider Lookup - the Account / Contact / User Providers it ships -
 * used by the framework's self-tests and offered as a **starter kit**.
 *
 * Do not edit this class for your project. Instead **copy it**, swap the map
 * entries for your own Providers, and pass your class to
 * `new XFTY_DummySObjectProvider(type, new MyProjectLookup())`. Two reasons:
 *
 * 1. Editing a shipped class makes upgrading XFTY painful.
 * 2. In a multi-package org a lookup can only reference Providers that compile in
 *    its own context - which is the whole point of resolving Providers through
 *    an interface rather than one global map.
 *
 * The map is complete and explicit; `XFTY_ProviderLookups` supplies the
 * mechanics so each method stays a one-liner.
 */
@IsTest
public class XFTY_DefaultSObjectProviderLookup implements XFTY_DummySObjectProviderLookupIntf {
    private static final Map<XFTY_LookupKeyIntf, Type> PROVIDER_TYPE_BY_KEY = new Map<XFTY_LookupKeyIntf, Type>{
            XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class,
            XFTY_LookupKey.get(Contact.SObjectType) => XFTY_DefaultContactDataProvider.class,
            XFTY_LookupKey.get(User.SObjectType) => XFTY_DefaultUserDataProvider.class
    };

    private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> instanceCache
            = new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

    public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
        return XFTY_ProviderLookups.get(PROVIDER_TYPE_BY_KEY, this.instanceCache, XFTY_LookupKey.get(sObjectType));
    }

    public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
        return XFTY_ProviderLookups.get(PROVIDER_TYPE_BY_KEY, this.instanceCache, lookupKey);
    }

    public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
        return XFTY_ProviderLookups.keysFor(PROVIDER_TYPE_BY_KEY.keySet(), sObj);
    }
}
