/**
 * Selects a Provider variant by `SObjectType` + record type developer name.
 *
 * The record type Id is never hard-coded - it is resolved from the developer
 * name through the SObject describe (no SOQL). `isInstanceOf` matches a record
 * whose `RecordTypeId` resolves to the same developer name, or equals this key's
 * resolved record type Id directly.
 *
 * Instances are flyweights - obtain them with `XFTY_RecordTypeLookupKey.get(...)`.
 */
@IsTest
public class XFTY_RecordTypeLookupKey implements XFTY_RecordTypeLookupKeyIntf {
    private static final Map<String, XFTY_RecordTypeLookupKey> INSTANCE_BY_HASH
            = new Map<String, XFTY_RecordTypeLookupKey>();

    private final XFTY_LookupKey base;
    private final String recordTypeDeveloperName;

    private XFTY_RecordTypeLookupKey(SObjectType sObjectType, String recordTypeDeveloperName) {
        this.base = XFTY_LookupKey.get(sObjectType);
        this.recordTypeDeveloperName = recordTypeDeveloperName;
    }

    public static XFTY_RecordTypeLookupKey get(SObjectType sObjectType, String recordTypeDeveloperName) {
        String hash = hashOf(XFTY_LookupKey.get(sObjectType), recordTypeDeveloperName);
        if (!INSTANCE_BY_HASH.containsKey(hash)) {
            INSTANCE_BY_HASH.put(hash, new XFTY_RecordTypeLookupKey(sObjectType, recordTypeDeveloperName));
        }
        return INSTANCE_BY_HASH.get(hash);
    }

    /** Derive the key from a record's `RecordTypeId` (or the null developer name if it has none). */
    public static XFTY_RecordTypeLookupKey get(SObject sObj) {
        return get(sObj == null ? null : sObj.getSObjectType(), XFTY_RecordTypeMatching.developerNameOf(sObj));
    }

    public SObjectType getSObjectType() {
        return this.base.getSObjectType();
    }

    public String getRecordTypeDeveloperName() {
        return this.recordTypeDeveloperName;
    }

    public Id getRecordTypeId() {
        return XFTY_RecordTypeMatching.idFor(this.getSObjectType(), this.recordTypeDeveloperName);
    }

    public Boolean isInstanceOf(SObject sObj) {
        return this.base.isInstanceOf(sObj)
                && XFTY_RecordTypeMatching.matches(sObj, this.getSObjectType(), this.recordTypeDeveloperName);
    }

    public String getHashKey() {
        return hashOf(this.base, this.recordTypeDeveloperName);
    }

    public Integer getSpecificity() {
        return 10;
    }

    public Boolean equals(Object other) {
        return (other instanceof XFTY_LookupKeyIntf)
                && ((XFTY_LookupKeyIntf) other).getHashKey() == this.getHashKey();
    }

    public Integer hashCode() {
        return this.getHashKey().hashCode();
    }

    private static String hashOf(XFTY_LookupKey base, String recordTypeDeveloperName) {
        return base.getHashKey() + '::recordType=' + recordTypeDeveloperName;
    }
}
