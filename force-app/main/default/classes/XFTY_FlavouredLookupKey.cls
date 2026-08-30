/**
 * Selects a Provider variant by `SObjectType`, optionally a record type, and one
 * or more arbitrary predicates on the record ("annual revenue over 1M",
 * "industry in a set", "nickname is null"). The "flavour" string is a label for
 * the combination.
 *
 * `isInstanceOf(sObj)` is true when the type matches, the record type matches
 * (if one was given), and every predicate is satisfied. Predicates let several
 * variants of the same record type coexist.
 *
 * Unlike {@link XFTY_LookupKey} / {@link XFTY_RecordTypeLookupKey} these are not
 * flyweighted - they carry behaviour (predicates). The Provider Lookup still
 * dedupes by `getHashKey()`, so build and register one per flavour.
 */
@IsTest
public class XFTY_FlavouredLookupKey implements XFTY_RecordTypeLookupKeyIntf {
    private final XFTY_LookupKey base;
    private final String recordTypeDeveloperName;
    private final String flavour;
    private final List<XFTY_SObjectPredicateIntf> predicates = new List<XFTY_SObjectPredicateIntf>();

    public XFTY_FlavouredLookupKey(SObjectType sObjectType, String flavour) {
        this(sObjectType, null, flavour);
    }

    public XFTY_FlavouredLookupKey(SObjectType sObjectType, String recordTypeDeveloperName, String flavour) {
        this.base = XFTY_LookupKey.get(sObjectType);
        this.recordTypeDeveloperName = recordTypeDeveloperName;
        this.flavour = flavour;
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
        return this.base.getHashKey()
                + (this.recordTypeDeveloperName == null ? '' : '::recordType=' + this.recordTypeDeveloperName)
                + '::flavour=' + this.flavour;
    }

    public Integer getSpecificity() {
        // More specific than a plain record-type key, and more so with more predicates.
        return 20 + this.predicates.size();
    }
}
