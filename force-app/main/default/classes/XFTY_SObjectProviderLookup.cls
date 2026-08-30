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
 * lifetime of the lookup; `register(key, providerInstance)` skips that for
 * Providers that need constructor arguments.
 *
 * `@IsTest` classes cannot be abstract, so this is composed, not subclassed -
 * wrap one in a named class (see {@link XFTY_DefaultSObjectProviderLookup}).
 */
@IsTest
public class XFTY_SObjectProviderLookup implements XFTY_DummySObjectProviderLookupIntf {
    private final Map<String, Type> providerTypeByKeyHash = new Map<String, Type>();
    private final Map<String, XFTY_DummySobjectProviderIntf> instanceByKeyHash
            = new Map<String, XFTY_DummySobjectProviderIntf>();
    private final Map<String, XFTY_LookupKeyIntf> keyByHash = new Map<String, XFTY_LookupKeyIntf>();

    // Built once from keyByHash the first time keysFor(...) runs.
    private Map<SObjectType, List<XFTY_LookupKeyIntf>> keysBySObjectType;

    public XFTY_SObjectProviderLookup register(XFTY_LookupKeyIntf lookupKey, Type providerType) {
        registerKey(lookupKey);
        if (providerType == null) {
            throw new LookupException('A provider type is required for ' + lookupKey.getHashKey());
        }
        this.providerTypeByKeyHash.put(lookupKey.getHashKey(), providerType);
        return this;
    }

    public XFTY_SObjectProviderLookup register(XFTY_LookupKeyIntf lookupKey, XFTY_DummySobjectProviderIntf provider) {
        registerKey(lookupKey);
        if (provider == null) {
            throw new LookupException('A provider is required for ' + lookupKey.getHashKey());
        }
        this.instanceByKeyHash.put(lookupKey.getHashKey(), provider);
        return this;
    }

    public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
        return this.get((XFTY_LookupKeyIntf) XFTY_LookupKey.get(sObjectType));
    }

    public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
        if (lookupKey == null) {
            throw new LookupException('A lookup key is required.');
        }
        String hash = lookupKey.getHashKey();
        if (!this.instanceByKeyHash.containsKey(hash)) {
            if (!this.providerTypeByKeyHash.containsKey(hash)) {
                throw new LookupException(
                        'No data provider registered for ' + lookupKey.getSObjectType() + ' (key: ' + hash + ').'
                );
            }
            this.instanceByKeyHash.put(
                    hash,
                    (XFTY_DummySobjectProviderIntf) this.providerTypeByKeyHash.get(hash).newInstance()
            );
        }
        return this.instanceByKeyHash.get(hash);
    }

    public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
        if (sObj == null) {
            throw new LookupException('An SObject is required to derive a lookup key.');
        }
        Set<XFTY_LookupKeyIntf> matches = new Set<XFTY_LookupKeyIntf>();
        for (XFTY_LookupKeyIntf candidate : keysForSObjectType(sObj.getSObjectType())) {
            if (candidate.isInstanceOf(sObj)) {
                matches.add(candidate);
            }
        }
        return matches;
    }

    // --------------------------------------------------------------------------

    private void registerKey(XFTY_LookupKeyIntf lookupKey) {
        if (lookupKey == null) {
            throw new LookupException('A lookup key is required.');
        }
        String hash = lookupKey.getHashKey();
        if (this.keyByHash.containsKey(hash)) {
            throw new LookupException('Lookup key already registered: ' + hash);
        }
        this.keyByHash.put(hash, lookupKey);
        this.keysBySObjectType = null; // invalidate the per-type index
    }

    private List<XFTY_LookupKeyIntf> keysForSObjectType(SObjectType sObjectType) {
        if (this.keysBySObjectType == null) {
            this.keysBySObjectType = new Map<SObjectType, List<XFTY_LookupKeyIntf>>();
            for (XFTY_LookupKeyIntf key : this.keyByHash.values()) {
                if (!this.keysBySObjectType.containsKey(key.getSObjectType())) {
                    this.keysBySObjectType.put(key.getSObjectType(), new List<XFTY_LookupKeyIntf>());
                }
                this.keysBySObjectType.get(key.getSObjectType()).add(key);
            }
        }
        List<XFTY_LookupKeyIntf> forType = this.keysBySObjectType.get(sObjectType);
        return (forType == null) ? new List<XFTY_LookupKeyIntf>() : forType;
    }

    public class LookupException extends XFTY_DummySObjectFtyProviderException {
    }
}
