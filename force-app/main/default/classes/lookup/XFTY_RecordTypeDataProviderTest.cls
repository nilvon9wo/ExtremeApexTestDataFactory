/**
 * Proves `XFTY_RecordTypeDataProvider` on the paths that need no real record
 * type. "Exactly one SOQL for the whole transaction" is asserted in
 * `XFTY_RecordTypeDataProviderOrgTest` (test-support/orgonly) - the local Apex
 * runtime resolves record types without a countable query.
 */
@IsTest
private class XFTY_RecordTypeDataProviderTest {

    @IsTest
    static void testGetFor_whenTheDeveloperNameIsUnknown_returnsNull() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        RecordType resolved = XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'This_Does_Not_Exist');
        Test.stopTest();

        // Assert
        Assert.isNull(resolved);
    }

    @IsTest
    static void testGetFor_whenTheDeveloperNameIsNull_returnsNull() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        RecordType resolved = XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, null);
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
        Id resolved = XFTY_RecordTypeDataProvider.idFor(Account.SObjectType, 'This_Does_Not_Exist');
        Test.stopTest();

        // Assert
        Assert.isNull(resolved);
    }

    @IsTest
    static void testAllFor_whenTheSObjectHasNoRecordTypes_returnsAnEmptyMap() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        Map<String, RecordType> result = XFTY_RecordTypeDataProvider.allFor(Contact.SObjectType);
        Test.stopTest();

        // Assert
        Assert.isNotNull(result);
        Assert.areEqual(0, result.size());
    }
}
