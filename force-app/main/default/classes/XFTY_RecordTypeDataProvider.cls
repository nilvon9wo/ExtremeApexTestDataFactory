/**
 * Repository of `RecordType` records, loaded with a **single** SOQL query the
 * first time anything is asked for and cached for the rest of the transaction.
 *
 * This is a test class because:
 * 1. No production code needs this.
 * 2. Tests should not depend on production code (especially untested production code).
 *
 * `XFTY_RecordTypeLookupKey` resolves record type Ids straight from the SObject
 * describe (zero SOQL); this class is for callers that want the whole
 * `RecordType` record, or a default when no variant key matches.
 */
@IsTest
public with sharing class XFTY_RecordTypeDataProvider {
    // sObjectName (lower case) -> developerName (lower case) -> RecordType
    private static Map<String, Map<String, RecordType>> recordTypesBySObjectName;

    //noinspection ApexUnusedDeclaration
    public static RecordType getFor(SObjectType sObjectType, String developerName) {
        if (developerName == null) {
            return null;
        }
        return allFor(sObjectType).get(developerName.toLowerCase());
    }

    //noinspection ApexUnusedDeclaration
    public static Id idFor(SObjectType sObjectType, String developerName) {
        RecordType recordType = getFor(sObjectType, developerName);
        return (recordType == null) ? null : recordType.Id;
    }

    /** Every record type for the SObject, keyed by lower-cased developer name. */
    public static Map<String, RecordType> allFor(SObjectType sObjectType) {
        ensureLoaded();
        Map<String, RecordType> forSObject = recordTypesBySObjectName.get(nameOf(sObjectType));
        return (forSObject == null) ? new Map<String, RecordType>() : forSObject;
    }

    private static void ensureLoaded() {
        if (recordTypesBySObjectName != null) {
            return;
        }
        recordTypesBySObjectName = new Map<String, Map<String, RecordType>>();
        for (RecordType recordType : [
                SELECT Id, Name, DeveloperName, SobjectType, IsActive
                FROM RecordType
        ]) {
            String sObjectKey = recordType.SobjectType.toLowerCase();
            if (!recordTypesBySObjectName.containsKey(sObjectKey)) {
                recordTypesBySObjectName.put(sObjectKey, new Map<String, RecordType>());
            }
            recordTypesBySObjectName.get(sObjectKey).put(recordType.DeveloperName.toLowerCase(), recordType);
        }
    }

    private static String nameOf(SObjectType sObjectType) {
        return String.valueOf(sObjectType).toLowerCase();
    }
}
