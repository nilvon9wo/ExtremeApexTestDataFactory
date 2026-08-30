/**
 * This is a test class because:
 * 1. No production code needs this.
 * 2. Tests should not be dependant on production code (especially not untested production code).
 */
@IsTest
public with sharing class XFTY_RecordTypeDataProvider {
    private static final Map<String, RecordType> RECORD_TYPE_BY_KEYS = new Map<String, RecordType>();
    private static final Set<String> LOADED_SOBJECT_NAMES = new Set<String>();

    //noinspection ApexUnusedDeclaration
    public static RecordType getFor(SObjectType sObjectType, String developerName) {
        String sObjectName = getName(sObjectType);
        if (!LOADED_SOBJECT_NAMES.contains(sObjectName)) {
            putRecordTypesFor(sObjectName);
        }
        return RECORD_TYPE_BY_KEYS.get(createKey(sObjectName, developerName));
    }

    private static void putRecordTypesFor(String sObjectName) {
        List<RecordType> recordTypes = [
                SELECT Id, DeveloperName, SobjectType
                FROM RecordType
                WHERE SobjectType = :sObjectName
        ];
        for (RecordType recordType : recordTypes) {
            String key = createKey(recordType.SobjectType, recordType.DeveloperName);
            RECORD_TYPE_BY_KEYS.put(key, recordType);
        }
        LOADED_SOBJECT_NAMES.add(sObjectName);
    }

    private static String createKey(String sObjectName, String developerName) {
        return sObjectName + ':::' + developerName;
    }

    private static String getName(SObjectType sObjectType) {
        return sObjectType.getDescribe()
                .getName();
    }
}