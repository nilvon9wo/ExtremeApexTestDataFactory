/**
 * Proves `XFTY_RecordTypeMatching` on the paths that need no real record type to
 * exist (null / absent / unknown), so this runs in any org. The "real record
 * type" paths are covered by `XFTY_RecordTypeRealRtTest` in `test-support/`.
 */
@IsTest
private class XFTY_RecordTypeMatchingTest {

    private static final Id FABRICATED_RT_ID = XFTY_IdMocker.generateId(new RecordType().getSObjectType());

    // developerNameOf(record) ------------------------------------------

    @IsTest
    static void testDeveloperNameOf_whenTheRecordIsNull_returnsNull() {
        testDeveloperNameOf(null, null);
    }

    @IsTest
    static void testDeveloperNameOf_whenTheSObjectHasNoRecordTypeIdField_returnsNull() {
        testDeveloperNameOf(new User(), null);
    }

    @IsTest
    static void testDeveloperNameOf_whenTheRecordTypeIdIsBlank_returnsNull() {
        testDeveloperNameOf(new Account(), null);
    }

    @IsTest
    static void testDeveloperNameOf_whenTheRecordTypeIdIsNotARealRecordType_returnsNull() {
        testDeveloperNameOf(new Account(RecordTypeId = FABRICATED_RT_ID), null);
    }

    // idFor(type, developerName) --------------------------------------

    @IsTest
    static void testIdFor_whenTheDeveloperNameIsNull_returnsNull() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        Id resolved = XFTY_RecordTypeMatching.idFor(Account.SObjectType, null);
        Test.stopTest();

        // Assert
        Assert.isNull(resolved);
    }

    @IsTest
    static void testIdFor_whenTheDeveloperNameIsUnknown_returnsNull() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        Id resolved = XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'NoSuchRecordType');
        Test.stopTest();

        // Assert
        Assert.isNull(resolved);
    }

    // matches(record, type, developerName) ---------------------------

    @IsTest
    static void testMatches_whenTheDeveloperNameIsNullAndTheRecordHasNoRecordType_returnsTrue() {
        testMatches(new Account(), null, true);
    }

    @IsTest
    static void testMatches_whenTheNamedRecordTypeDoesNotExistAndTheRecordHasNone_returnsFalse() {
        testMatches(new Account(), 'NoSuchRecordType', false);
    }

    @IsTest
    static void testMatches_whenTheNamedRecordTypeDoesNotExistAndTheRecordCarriesAFabricatedId_returnsFalse() {
        testMatches(new Account(RecordTypeId = FABRICATED_RT_ID), 'NoSuchRecordType', false);
    }

    @IsTest
    static void testMatches_whenTheNameResolvesButTheRecordCarriesNoRecordTypeId_returnsFalse() {
        // 'Master' resolves to the placeholder master record-type Id on every SObject
        // in every org, so idFor(...) is non-null and the fallback Id comparison
        // actually runs - then fails. Real-record-type coverage is in
        // test-support/XFTY_RecordTypeRealRtTest.
        testMatches(new Account(), 'Master', false);
    }

    // Runners --------------------------------------------------------

    static void testDeveloperNameOf(SObject record, String expected) {
        // Arrange
        // the caller supplies the record

        // Act
        Test.startTest();
        String developerName = XFTY_RecordTypeMatching.developerNameOf(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expected, developerName);
    }

    static void testMatches(SObject record, String developerName, Boolean expected) {
        // Arrange
        // the caller supplies the record and the developer name

        // Act
        Test.startTest();
        Boolean matches = XFTY_RecordTypeMatching.matches(record, Account.SObjectType, developerName);
        Test.stopTest();

        // Assert
        Assert.areEqual(expected, matches);
    }
}
