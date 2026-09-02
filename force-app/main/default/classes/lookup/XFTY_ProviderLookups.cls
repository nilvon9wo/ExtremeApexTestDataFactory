/**
 * The reusable mechanics behind an `XFTY_DummySObjectProviderLookupIntf`, so a
 * project's own lookup stays a handful of one-line delegations over an explicit
 * `Map<XFTY_LookupKeyIntf, ...>`.
 *
 * Nothing here is stateful and nothing mutates a lookup: you pass a complete map
 * in, you get an answer out.
 *
 * ```apex
 * @IsTest
 * public class MyProjectLookup implements XFTY_DummySObjectProviderLookupIntf {
 *     private static final Map<XFTY_LookupKeyIntf, Type> PROVIDERS = new Map<XFTY_LookupKeyIntf, Type>{
 *         XFTY_LookupKey.get(Account.SObjectType)                          => MyAccountProvider.class,
 *         XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAcct')  => MyPersonAccountProvider.class,
 *         XFTY_LookupKey.get(Contact.SObjectType)                          => MyContactProvider.class
 *     };
 *     private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> cache =
 *             new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();
 *
 *     public XFTY_DummySobjectProviderIntf get(SObjectType t)          { return XFTY_ProviderLookups.get(PROVIDERS, cache, XFTY_LookupKey.get(t)); }
 *     public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf key) { return XFTY_ProviderLookups.get(PROVIDERS, cache, key); }
 *     public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj)             { return XFTY_ProviderLookups.keysFor(PROVIDERS.keySet(), sObj); }
 * }
 * ```
 *
 * `of(...)` / `ofTypes(...)` build that same lookup from a map for quick or
 * in-test use.
 */
@IsTest
public class XFTY_ProviderLookups {

    // Resolving a Provider ---------------------------------------------------

    /** Look up (and lazily instantiate + cache) a Provider for `key`. */
    public static XFTY_DummySobjectProviderIntf get(
            Map<XFTY_LookupKeyIntf, Type> providerTypeByKey,
            Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> instanceCache,
            XFTY_LookupKeyIntf key
    ) {
        requireKey(key);
        if (!instanceCache.containsKey(key)) {
            if (!providerTypeByKey.containsKey(key)) {
                throw notRegistered(key);
            }
            instanceCache.put(key, (XFTY_DummySobjectProviderIntf) providerTypeByKey.get(key).newInstance());
        }
        return instanceCache.get(key);
    }

    /** Look up an already-constructed Provider for `key`. */
    public static XFTY_DummySobjectProviderIntf get(
            Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providerByKey,
            XFTY_LookupKeyIntf key
    ) {
        requireKey(key);
        if (!providerByKey.containsKey(key)) {
            throw notRegistered(key);
        }
        return providerByKey.get(key);
    }

    // Deriving a key from a record ------------------------------------------

    /** The subset of `registeredKeys` whose `isInstanceOf(sObj)` is true. */
    public static Set<XFTY_LookupKeyIntf> keysFor(Set<XFTY_LookupKeyIntf> registeredKeys, SObject sObj) {
        if (sObj == null) {
            throw new LookupException('An SObject is required to derive a lookup key.');
        }
        Set<XFTY_LookupKeyIntf> matches = new Set<XFTY_LookupKeyIntf>();
        for (XFTY_LookupKeyIntf key : registeredKeys) {
            if (key.getSObjectType() == sObj.getSObjectType() && key.isInstanceOf(sObj)) {
                matches.add(key);
            }
        }
        return matches;
    }

    /**
     * The single key to generate a parent from, given a lookup and a record: the
     * most specific match, or the plain type key when nothing refined matched.
     * Two equally-specific matches is an error - the caller must supply an
     * explicit key.
     */
    public static XFTY_LookupKeyIntf resolve(XFTY_DummySObjectProviderLookupIntf providerLookup, SObject sObj) {
        Set<XFTY_LookupKeyIntf> matches = providerLookup.keysFor(sObj);
        if (matches.isEmpty()) {
            return XFTY_LookupKey.get(sObj.getSObjectType());
        }

        XFTY_LookupKeyIntf best = null;
        List<String> topTierHashes = new List<String>();
        for (XFTY_LookupKeyIntf candidate : matches) {
            if (best == null || candidate.getSpecificity() > best.getSpecificity()) {
                best = candidate;
                topTierHashes = new List<String>{ candidate.getHashKey() };
            } else if (candidate.getSpecificity() == best.getSpecificity()
                    && candidate.getHashKey() != best.getHashKey()) {
                topTierHashes.add(candidate.getHashKey());
            }
        }

        if (topTierHashes.size() > 1) {
            throw new LookupException(
                    'Ambiguous Provider variant for ' + sObj.getSObjectType()
                            + ': ' + topTierHashes + '. Supply an explicit lookup key.'
            );
        }
        return best;
    }

    /**
     * The single variant key to generate from, given an optional explicit key and
     * an optional override template - the two ways a caller can name a variant.
     *
     * - explicit key only: that key.
     * - template only: {@link #resolve} on the template (plain type key if
     *   nothing refined matches).
     * - both: the explicit key, unless the template independently matches a
     *   *different* refined variant - that is a contradiction and throws, rather
     *   than silently letting the explicit key win over a template that says
     *   otherwise (e.g. `withVariant(PERSON_ACCOUNT)` with a business-record-type
     *   template).
     * - neither: `null` (the caller supplies its own default, usually the plain
     *   type key).
     */
    public static XFTY_LookupKeyIntf reconcile(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            XFTY_LookupKeyIntf explicitKey,
            SObject overrideTemplate
    ) {
        if (explicitKey == null) {
            return (overrideTemplate == null) ? null : resolve(providerLookup, overrideTemplate);
        }
        if (overrideTemplate != null) {
            XFTY_LookupKeyIntf fromTemplate = resolve(providerLookup, overrideTemplate);
            if (fromTemplate.getSpecificity() > 0
                    && fromTemplate.getHashKey() != explicitKey.getHashKey()) {
                throw new LookupException(
                        'Explicit variant ' + explicitKey.getHashKey()
                                + ' contradicts the override template, which matches '
                                + fromTemplate.getHashKey() + '. Supply only one.'
                );
            }
        }
        return explicitKey;
    }

    // Ready-made map-backed lookups ---------------------------------------

    /** A lookup over a complete map of already-constructed Providers. */
    public static XFTY_DummySObjectProviderLookupIntf of(
            Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providerByKey
    ) {
        return new MapBackedLookup(null, providerByKey, null);
    }

    /**
     * As {@link #of(Map)}, plus the shared-ancestor defaults the Providers rely
     * on - each registered with `putIfAbsent` before a `supply*()` call resolves
     * shared ancestors, so a test that references one need not register it (and
     * a test that wants a different record still can, first).
     */
    public static XFTY_DummySObjectProviderLookupIntf of(
            Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providerByKey,
            Map<String, SObject> sharedAncestorDefaults
    ) {
        return new MapBackedLookup(null, providerByKey, sharedAncestorDefaults);
    }

    /** A lookup over a complete map of Provider classes (instantiated lazily). */
    public static XFTY_DummySObjectProviderLookupIntf ofTypes(Map<XFTY_LookupKeyIntf, Type> providerTypeByKey) {
        return new MapBackedLookup(providerTypeByKey, null, null);
    }

    // ---------------------------------------------------------------------

    private static void requireKey(XFTY_LookupKeyIntf key) {
        if (key == null) {
            throw new LookupException('A lookup key is required.');
        }
    }

    private static LookupException notRegistered(XFTY_LookupKeyIntf key) {
        return new LookupException(
                'No data provider registered for ' + key.getSObjectType() + ' (key: ' + key.getHashKey() + ').'
        );
    }

    private class MapBackedLookup implements XFTY_DummySObjectProviderLookupIntf, XFTY_SharedAncestorDefaultsIntf {
        private final Map<XFTY_LookupKeyIntf, Type> providerTypeByKey;
        private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providerByKey;
        private final Map<String, SObject> sharedAncestorDefaults;
        private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> instanceCache
                = new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

        private MapBackedLookup(
                Map<XFTY_LookupKeyIntf, Type> providerTypeByKey,
                Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providerByKey,
                Map<String, SObject> sharedAncestorDefaults
        ) {
            this.providerTypeByKey = providerTypeByKey;
            this.providerByKey = providerByKey;
            this.sharedAncestorDefaults = sharedAncestorDefaults;
        }

        public void registerSharedAncestorDefaults() {
            if (this.sharedAncestorDefaults == null) {
                return;
            }
            for (String name : this.sharedAncestorDefaults.keySet()) {
                XFTY_SharedAncestor.putIfAbsent(name, this.sharedAncestorDefaults.get(name));
            }
        }

        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return this.get((XFTY_LookupKeyIntf) XFTY_LookupKey.get(sObjectType));
        }

        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return (this.providerByKey != null)
                    ? XFTY_ProviderLookups.get(this.providerByKey, lookupKey)
                    : XFTY_ProviderLookups.get(this.providerTypeByKey, this.instanceCache, lookupKey);
        }

        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            Set<XFTY_LookupKeyIntf> keys = (this.providerByKey != null)
                    ? this.providerByKey.keySet()
                    : this.providerTypeByKey.keySet();
            return XFTY_ProviderLookups.keysFor(keys, sObj);
        }
    }

    public class LookupException extends XFTY_DummySObjectFtyProviderException {
    }
}
