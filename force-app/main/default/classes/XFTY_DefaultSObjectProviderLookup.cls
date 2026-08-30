/**
 * The default Provider Lookup: XFTY's own Providers (Account, Contact, User)
 * registered in the constructor, plus `register(...)` so a project can add its
 * own without writing a lookup class.
 *
 * ```apex
 * XFTY_DummySObjectProviderLookupIntf lookup = new XFTY_DefaultSObjectProviderLookup()
 *         .register(XFTY_LookupKey.get(Opportunity.SObjectType), MyOpportunityProvider.class)
 *         .register(
 *                 new XFTY_FlavouredLookupKey(Account.SObjectType, 'enterprise')
 *                         .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 1000)),
 *                 MyEnterpriseAccountProvider.class);
 * ```
 *
 * Registering a key that already exists replaces it, so the built-in Providers
 * can be overridden. `@IsTest` classes cannot be abstract or virtual, so this is
 * *the* implementation to read or copy - there is no base class.
 *
 * Everything is per-instance: two lookups do not share registrations or cached
 * Provider instances.
 */
@IsTest
public class XFTY_DefaultSObjectProviderLookup implements XFTY_DummySObjectProviderLookupIntf {
    private final Map<String, Type> providerTypeByKeyHash = new Map<String, Type>();
    private final Map<String, XFTY_DummySobjectProviderIntf> providerInstanceByKeyHash
            = new Map<String, XFTY_DummySobjectProviderIntf>();
    private final Map<String, XFTY_LookupKeyIntf> keyByHash = new Map<String, XFTY_LookupKeyIntf>();

    // Lazily built from keyByHash; rebuilt whenever a key is (re-)registered.
    private Map<SObjectType, List<XFTY_LookupKeyIntf>> keysBySObjectType;

    public XFTY_DefaultSObjectProviderLookup() {
        this.register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class);
        this.register(XFTY_LookupKey.get(Contact.SObjectType), XFTY_DefaultContactDataProvider.class);
        this.register(XFTY_LookupKey.get(User.SObjectType), XFTY_DefaultUserDataProvider.class);
    }

    // Registration ------------------------------------------------------------

    /** Register a Provider class; instantiated lazily via a public no-arg constructor. */
    public XFTY_DefaultSObjectProviderLookup register(XFTY_LookupKeyIntf lookupKey, Type providerType) {
        indexKey(lookupKey);
        if (providerType == null) {
            throw new LookupException('A provider type is required for ' + lookupKey.getHashKey() + '.');
        }
        this.providerTypeByKeyHash.put(lookupKey.getHashKey(), providerType);
        this.providerInstanceByKeyHash.remove(lookupKey.getHashKey());
        return this;
    }

    /** Register an already-constructed Provider (for Providers that need constructor arguments, and tests). */
    public XFTY_DefaultSObjectProviderLookup register(XFTY_LookupKeyIntf lookupKey, XFTY_DummySobjectProviderIntf provider) {
        indexKey(lookupKey);
        if (provider == null) {
            throw new LookupException('A provider is required for ' + lookupKey.getHashKey() + '.');
        }
        this.providerInstanceByKeyHash.put(lookupKey.getHashKey(), provider);
        this.providerTypeByKeyHash.remove(lookupKey.getHashKey());
        return this;
    }

    // Resolution ------------------------------------------------------------

    public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
        return this.get((XFTY_LookupKeyIntf) XFTY_LookupKey.get(sObjectType));
    }

    public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
        if (lookupKey == null) {
            throw new LookupException('A lookup key is required.');
        }
        String hash = lookupKey.getHashKey();

        if (!this.providerInstanceByKeyHash.containsKey(hash)) {
            if (!this.providerTypeByKeyHash.containsKey(hash)) {
                throw new LookupException(
                        'No data provider registered for ' + lookupKey.getSObjectType() + ' (key: ' + hash + ').'
                );
            }
            this.providerInstanceByKeyHash.put(
                    hash,
                    (XFTY_DummySobjectProviderIntf) this.providerTypeByKeyHash.get(hash).newInstance()
            );
        }
        return this.providerInstanceByKeyHash.get(hash);
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

    // Internals ------------------------------------------------------------

    private void indexKey(XFTY_LookupKeyIntf lookupKey) {
        if (lookupKey == null) {
            throw new LookupException('A lookup key is required.');
        }
        this.keyByHash.put(lookupKey.getHashKey(), lookupKey);
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
