/**
 * The "real record type" paths of `XFTY_RecordTypeMatching`,
 * `XFTY_RecordTypeLookupKey`, and `XFTY_FlavouredLookupKey` - the ones that need
 * an actual record type to exist.
 *
 * Lives in `test-support/orgonly/` because it uses `XFTY_HierarchyNode__c` and
 * its `Root` record type - real record-type metadata the local runtime does not
 * carry. Runs on a scratch org. The feature-independent paths are covered by
 * `XFTY_RecordTypeMatchingTest` / `XFTY_LookupKeyTest` in `force-app`.
 * Describe-only, no DML/SOQL - no `System.runAs`.
 */
@IsTest
private class XFTY_RecordTypeRealRtTest {

    private static final SObjectType RT_OBJECT = XFTY_HierarchyNode__c.SObjectType;
    private static final String REAL_RT = 'Root';

    private static Id realRtId() {
        return RT_OBJECT.getDescribe().getRecordTypeInfosByDeveloperName().get(REAL_RT).getRecordTypeId();
    }

    // XFTY_RecordTypeMatching ------------------------------------

    @IsTest
    static void testDeveloperNameOf_forARecordCarryingARealRecordType_resolvesItsDeveloperName() {
        // Arrange
        XFTY_HierarchyNode__c record = new XFTY_HierarchyNode__c(RecordTypeId = realRtId());

        // Act
        Test.startTest();
        String developerName = XFTY_RecordTypeMatching.developerNameOf(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(REAL_RT, developerName);
    }

    @IsTest
    static void testIdFor_forARealRecordType_resolvesItFromTheDescribe() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        Id resolved = XFTY_RecordTypeMatching.idFor(RT_OBJECT, REAL_RT);
        Test.stopTest();

        // Assert
        Assert.areEqual(realRtId(), resolved);
    }

    @IsTest
    static void testMatches_forARecordCarryingThatRecordType_returnsTrue() {
        // Arrange
        XFTY_HierarchyNode__c record = new XFTY_HierarchyNode__c(RecordTypeId = realRtId());

        // Act
        Test.startTest();
        Boolean matches = XFTY_RecordTypeMatching.matches(record, RT_OBJECT, REAL_RT);
        Test.stopTest();

        // Assert
        Assert.isTrue(matches);
    }

    @IsTest
    static void testMatches_whenTheDeveloperNamesDiffer_fallsBackToTheIdComparisonAndReturnsFalse() {
        // Arrange - the record carries an unrecognised record type Id, so developerNameOf(...)
        // returns null and the name check fails, forcing the Id-comparison fallback
        Id staleRtId = XFTY_IdMocker.generateId(new RecordType().getSObjectType());
        XFTY_HierarchyNode__c record = new XFTY_HierarchyNode__c(RecordTypeId = staleRtId);

        // Act
        Test.startTest();
        Boolean matches = XFTY_RecordTypeMatching.matches(record, RT_OBJECT, REAL_RT);
        Test.stopTest();

        // Assert
        Assert.isFalse(matches);
    }

    // XFTY_RecordTypeLookupKey / XFTY_FlavouredLookupKey -------

    @IsTest
    static void testGetRecordTypeId_forARecordTypeKey_resolvesTheRealId() {
        // Arrange
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(RT_OBJECT, REAL_RT);

        // Act
        Test.startTest();
        Id recordTypeId = key.getRecordTypeId();
        Test.stopTest();

        // Assert
        Assert.areEqual(realRtId(), recordTypeId);
    }

    @IsTest
    static void testGetRecordTypeId_forAFlavouredKeyWithARealRecordType_resolvesTheRealId() {
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(RT_OBJECT, REAL_RT, 'vip')
                .matching(XFTY_FieldPredicate.isNotNull(XFTY_HierarchyNode__c.Name));

        // Act
        Test.startTest();
        Id recordTypeId = key.getRecordTypeId();
        Test.stopTest();

        // Assert
        Assert.areEqual('vip', key.getFlavour());
        Assert.areEqual(REAL_RT, key.getRecordTypeDeveloperName());
        Assert.areEqual(realRtId(), recordTypeId);
    }

    @IsTest
    static void testIsInstanceOf_forAFlavouredKey_whenTheRecordCarriesThatRecordTypeAndSatisfiesThePredicate_returnsTrue() {
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(RT_OBJECT, REAL_RT, 'vip')
                .matching(XFTY_FieldPredicate.isNotNull(XFTY_HierarchyNode__c.Name));

        // Act
        Test.startTest();
        Boolean matches = key.isInstanceOf(new XFTY_HierarchyNode__c(RecordTypeId = realRtId(), Name = 'Doe'));
        Test.stopTest();

        // Assert
        Assert.isTrue(matches);
    }

    @IsTest
    static void testIsInstanceOf_forAFlavouredKey_whenTheRecordHasTheWrongRecordType_returnsFalse() {
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(RT_OBJECT, REAL_RT, 'vip')
                .matching(XFTY_FieldPredicate.isNotNull(XFTY_HierarchyNode__c.Name));

        // Act
        Test.startTest();
        Boolean matches = key.isInstanceOf(new XFTY_HierarchyNode__c(Name = 'Doe'));
        Test.stopTest();

        // Assert
        Assert.isFalse(matches, 'wrong record type');
    }
}
