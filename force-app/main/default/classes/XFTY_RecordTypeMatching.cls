/**
 * Shared record-type resolution used by {@link XFTY_RecordTypeLookupKey} and
 * {@link XFTY_FlavouredLookupKey}. Everything comes from the SObject describe -
 * no SOQL, nothing hard-coded.
 */
@IsTest
public class XFTY_RecordTypeMatching {

    /** The developer name of a record's `RecordTypeId`, or null if it has none. */
    public static String developerNameOf(SObject sObj) {
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

    /** The record type Id for a developer name on an SObject, or null. */
    public static Id idFor(SObjectType sObjectType, String developerName) {
        if (developerName == null) {
            return null;
        }
        Schema.RecordTypeInfo info = sObjectType.getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get(developerName);
        return (info == null) ? null : info.getRecordTypeId();
    }

    /**
     * Whether `sObj` carries the given record type. A null `developerName` means
     * "no record type" and matches a record with no `RecordTypeId`.
     */
    public static Boolean matches(SObject sObj, SObjectType sObjectType, String developerName) {
        if (developerName == developerNameOf(sObj)) {
            return true;
        }
        Id keyRecordTypeId = idFor(sObjectType, developerName);
        return keyRecordTypeId != null
                && sObj != null
                && keyRecordTypeId == (Id) sObj.get('RecordTypeId');
    }
}
