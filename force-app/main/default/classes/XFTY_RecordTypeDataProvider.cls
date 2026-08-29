/**
 * This is a test class because:
 * 1. No production code needs this.
 * 2. Tests should not be dependant on production code (especially not untested production code).
 */
@IsTest
public with sharing class XFTY_RecordTypeDataProvider {
    private static final Map<String, RecordType> RECORD_TYPE_BY_KEYS = new Map<String, RecordType>();

    //noinspection ApexUnusedDeclaration
    public static RecordType getFor(SObjectType sObjectType, String developerName) {
        String sObjectName = getName(sObjectType);
        String key = createKey(sObjectName, developerName);
        RecordType recordType = RECORD_TYPE_BY_KEYS.get(key);
        if (recordType == null) {
            putRecordTypesFor(sObjectName);
            recordType = RECORD_TYPE_BY_KEYS.get(key);
        }
        return recordType;
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
    }

    private static String createKey(String sObjectName, String developerName) {
        return sObjectName + ':::' + developerName;
    }

    private static String getName(SObjectType sObjectType) {
        return sObjectType.getDescribe()
                .getName();
    }
}