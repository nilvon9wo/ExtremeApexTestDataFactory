/**
 * Selects a Provider variant by `SObjectType` + an arbitrary developer-chosen
 * "flavor" string (e.g. `'minimal'`, `'fully-populated'`, `'past-due'`).
 *
 * A flavor is a test-time concept, not something stored on the record, so
 * `isInstanceOf` always returns `false` - a flavor key is only ever used
 * explicitly, via `new XFTY_DummyDefaultRelationship(key, template)` or
 * `lookup.get(key)`.
 *
 * Instances are flyweights - obtain them with `XFTY_FlavorLookupKey.get(...)`.
 */
@IsTest
public class XFTY_FlavorLookupKey implements XFTY_LookupKeyIntf {
    private static final Map<String, XFTY_FlavorLookupKey> INSTANCE_BY_HASH
            = new Map<String, XFTY_FlavorLookupKey>();

    private final XFTY_LookupKey base;
    private final String flavor;

    private XFTY_FlavorLookupKey(SObjectType sObjectType, String flavor) {
        this.base = XFTY_LookupKey.get(sObjectType);
        this.flavor = flavor;
    }

    public static XFTY_FlavorLookupKey get(SObjectType sObjectType, String flavor) {
        String hash = hashOf(XFTY_LookupKey.get(sObjectType), flavor);
        if (!INSTANCE_BY_HASH.containsKey(hash)) {
            INSTANCE_BY_HASH.put(hash, new XFTY_FlavorLookupKey(sObjectType, flavor));
        }
        return INSTANCE_BY_HASH.get(hash);
    }

    public SObjectType getSObjectType() {
        return this.base.getSObjectType();
    }

    public String getFlavor() {
        return this.flavor;
    }

    public Boolean isInstanceOf(SObject sObj) {
        return false;
    }

    public String getHashKey() {
        return hashOf(this.base, this.flavor);
    }

    private static String hashOf(XFTY_LookupKey base, String flavor) {
        return base.getHashKey() + '::flavor=' + flavor;
    }
}
