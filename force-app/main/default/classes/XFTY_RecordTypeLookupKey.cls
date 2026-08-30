/**
 * Selects a Provider variant by `SObjectType` + record type developer name.
 *
 * The record type Id is never hard-coded - it is resolved from the developer
 * name through the SObject describe (no SOQL). `isInstanceOf` converts a
 * record's `RecordTypeId` back to a developer name the same way, so a key built
 * from a developer name matches a record carrying the corresponding Id.
 *
 * Instances are flyweights - obtain them with `XFTY_RecordTypeLookupKey.get(...)`.
 */
@IsTest
public class XFTY_RecordTypeLookupKey implements XFTY_LookupKeyIntf {
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
        return get(sObj == null ? null : sObj.getSObjectType(), developerNameOf(sObj));
    }

    public SObjectType getSObjectType() {
        return this.base.getSObjectType();
    }

    public String getRecordTypeDeveloperName() {
        return this.recordTypeDeveloperName;
    }

    /** The matching record type Id, resolved from the describe, or null if there is no such record type. */
    public Id getRecordTypeId() {
        Schema.RecordTypeInfo info = this.getSObjectType().getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get(this.recordTypeDeveloperName);
        return (info == null) ? null : info.getRecordTypeId();
    }

    public Boolean isInstanceOf(SObject sObj) {
        return this.base.isInstanceOf(sObj) && this.recordTypeDeveloperName == developerNameOf(sObj);
    }

    public String getHashKey() {
        return hashOf(this.base, this.recordTypeDeveloperName);
    }

    private static String hashOf(XFTY_LookupKey base, String recordTypeDeveloperName) {
        return base.getHashKey() + '::recordType=' + recordTypeDeveloperName;
    }

    private static String developerNameOf(SObject sObj) {
        if (sObj == null) {
            return null;
        }
        Schema.DescribeSObjectResult describe = sObj.getSObjectType().getDescribe();
        if (!describe.fields.getMap().containsKey('recordtypeid')) {
            return null;
        }
        Id recordTypeId = (Id) sObj.get('RecordTypeId');
        if (recordTypeId == null) {
            return null;
        }
        Schema.RecordTypeInfo info = describe.getRecordTypeInfosById().get(recordTypeId);
        return (info == null) ? null : info.getDeveloperName();
    }
}
