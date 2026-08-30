/**
 * A configurable Provider Lookup. Register variants, then hand it to
 * `XFTY_DummySObjectProvider`:
 *
 * ```apex
 * XFTY_DummySObjectProviderLookupIntf lookup = new XFTY_SObjectProviderLookup()
 *         .register(XFTY_LookupKey.get(Account.SObjectType), MyAccountProvider.class)
 *         .register(XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAccount'), MyPersonAccountProvider.class);
 * ```
 *
 * Provider instances are created lazily via `Type.newInstance()` (so each
 * registered Provider needs a public no-arg constructor) and cached for the
 * lifetime of the lookup.
 *
 * Projects usually either use this class directly or wrap one - see
 * {@link XFTY_DefaultSObjectProviderLookup}. `@IsTest` classes cannot be
 * abstract, so this is composed, not subclassed.
 */
@IsTest
public class XFTY_SObjectProviderLookup implements XFTY_DummySObjectProviderLookupIntf {
    private final Map<String, Type> providerTypeByKeyHash = new Map<String, Type>();
    private final Map<String, XFTY_LookupKeyIntf> keyByHash = new Map<String, XFTY_LookupKeyIntf>();
    private final Map<String, XFTY_DummySobjectProviderIntf> instanceByKeyHash
            = new Map<String, XFTY_DummySobjectProviderIntf>();

    /** Register a Provider class; instantiated lazily via a public no-arg constructor. */
    public XFTY_SObjectProviderLookup register(XFTY_LookupKeyIntf lookupKey, Type providerType) {
        String hash = lookupKey.getHashKey();
        this.providerTypeByKeyHash.put(hash, providerType);
        this.keyByHash.put(hash, lookupKey);
        return this;
    }

    /** Register an already-constructed Provider (useful for Providers that need constructor arguments, and in tests). */
    public XFTY_SObjectProviderLookup register(XFTY_LookupKeyIntf lookupKey, XFTY_DummySobjectProviderIntf provider) {
        String hash = lookupKey.getHashKey();
        this.instanceByKeyHash.put(hash, provider);
        this.keyByHash.put(hash, lookupKey);
        return this;
    }

    public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
        return this.get((XFTY_LookupKeyIntf) XFTY_LookupKey.get(sObjectType));
    }

    public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
        String hash = lookupKey.getHashKey();
        if (!this.instanceByKeyHash.containsKey(hash)) {
            if (!this.providerTypeByKeyHash.containsKey(hash)) {
                throw new LookupException('No data provider registered for lookup key: ' + hash);
            }
            this.instanceByKeyHash.put(
                    hash,
                    (XFTY_DummySobjectProviderIntf) this.providerTypeByKeyHash.get(hash).newInstance()
            );
        }
        return this.instanceByKeyHash.get(hash);
    }

    public XFTY_LookupKeyIntf keyFor(SObject sObj) {
        SObjectType sObjectType = sObj.getSObjectType();
        XFTY_LookupKeyIntf defaultKey = XFTY_LookupKey.get(sObjectType);
        String defaultHash = defaultKey.getHashKey();

        for (XFTY_LookupKeyIntf candidate : this.keyByHash.values()) {
            Boolean isRefined = candidate.getHashKey() != defaultHash;
            if (isRefined && candidate.getSObjectType() == sObjectType && candidate.isInstanceOf(sObj)) {
                return candidate;
            }
        }
        return defaultKey;
    }

    public class LookupException extends XFTY_DummySObjectFtyProviderException {
    }
}
