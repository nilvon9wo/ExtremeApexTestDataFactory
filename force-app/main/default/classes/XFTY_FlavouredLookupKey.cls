/**
 * Selects a Provider variant by `SObjectType`, optionally a record type, and one
 * or more arbitrary predicates on the record ("annual revenue over 1M",
 * "industry in a set", "nickname is null"). The "flavour" string labels the
 * combination.
 *
 * `isInstanceOf(sObj)` is true when the type matches, the record type matches
 * (if one was given), and every predicate is satisfied. Predicates let several
 * variants of the same record type coexist and be derived from a template; a
 * flavour with no record type and no predicates can only be used explicitly.
 *
 * Instances are flyweights, interned by `SObjectType` + record type + flavour
 * (predicates are *not* part of the identity). Obtain one with
 * `XFTY_FlavouredLookupKey.get(...)` and add its predicates with `matching(...)`
 * **once**, in a single place - typically a small `*LookupKeys` constants class
 * your Providers and Provider Lookup both reference.
 */
@IsTest
public class XFTY_FlavouredLookupKey implements XFTY_RecordTypeLookupKeyIntf {
    private static final Map<String, XFTY_FlavouredLookupKey> INSTANCE_BY_HASH
            = new Map<String, XFTY_FlavouredLookupKey>();

    private final XFTY_LookupKey base;
    private final String recordTypeDeveloperName;
    private final String flavour;
    private final List<XFTY_SObjectPredicateIntf> predicates = new List<XFTY_SObjectPredicateIntf>();

    private XFTY_FlavouredLookupKey(SObjectType sObjectType, String recordTypeDeveloperName, String flavour) {
        this.base = XFTY_LookupKey.get(sObjectType);
        this.recordTypeDeveloperName = recordTypeDeveloperName;
        this.flavour = flavour;
    }

    public static XFTY_FlavouredLookupKey get(SObjectType sObjectType, String flavour) {
        return get(sObjectType, null, flavour);
    }

    public static XFTY_FlavouredLookupKey get(SObjectType sObjectType, String recordTypeDeveloperName, String flavour) {
        String hash = hashOf(XFTY_LookupKey.get(sObjectType), recordTypeDeveloperName, flavour);
        if (!INSTANCE_BY_HASH.containsKey(hash)) {
            INSTANCE_BY_HASH.put(hash, new XFTY_FlavouredLookupKey(sObjectType, recordTypeDeveloperName, flavour));
        }
        return INSTANCE_BY_HASH.get(hash);
    }

    /** Add a condition the record must satisfy to belong to this flavour. Chainable. */
    public XFTY_FlavouredLookupKey matching(XFTY_SObjectPredicateIntf predicate) {
        this.predicates.add(predicate);
        return this;
    }

    public SObjectType getSObjectType() {
        return this.base.getSObjectType();
    }

    public String getFlavour() {
        return this.flavour;
    }

    public String getRecordTypeDeveloperName() {
        return this.recordTypeDeveloperName;
    }

    public Id getRecordTypeId() {
        return XFTY_RecordTypeMatching.idFor(this.getSObjectType(), this.recordTypeDeveloperName);
    }

    public Boolean isInstanceOf(SObject sObj) {
        if (this.recordTypeDeveloperName == null && this.predicates.isEmpty()) {
            // Nothing on the record identifies this flavour - it can only be used explicitly.
            return false;
        }
        if (!this.base.isInstanceOf(sObj)) {
            return false;
        }
        if (this.recordTypeDeveloperName != null
                && !XFTY_RecordTypeMatching.matches(sObj, this.getSObjectType(), this.recordTypeDeveloperName)) {
            return false;
        }
        for (XFTY_SObjectPredicateIntf predicate : this.predicates) {
            if (!predicate.isSatisfiedBy(sObj)) {
                return false;
            }
        }
        return true;
    }

    public String getHashKey() {
        return hashOf(this.base, this.recordTypeDeveloperName, this.flavour);
    }

    public Integer getSpecificity() {
        // More specific than a plain record-type key, and more so with more predicates.
        return 20 + this.predicates.size();
    }

    public Boolean equals(Object other) {
        return (other instanceof XFTY_LookupKeyIntf)
                && ((XFTY_LookupKeyIntf) other).getHashKey() == this.getHashKey();
    }

    public Integer hashCode() {
        return this.getHashKey().hashCode();
    }

    private static String hashOf(XFTY_LookupKey base, String recordTypeDeveloperName, String flavour) {
        return base.getHashKey()
                + (recordTypeDeveloperName == null ? '' : '::recordType=' + recordTypeDeveloperName)
                + '::flavour=' + flavour;
    }
}
