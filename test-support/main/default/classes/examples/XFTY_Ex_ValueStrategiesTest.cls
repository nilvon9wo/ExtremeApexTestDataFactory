/**
 * Runnable proof for docs/use/value-strategies.md - every `@IsTest` method is
 * one fenced example from that page.
 */
@IsTest
private class XFTY_Ex_ValueStrategiesTest {

    private static final XFTY_DefaultSObjectProviderLookup PROVIDER_LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void anIncrementingStringStrategyProducesADistinctValuePerRecord() {
        // Arrange
        // nothing to arrange

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                .put(Contact.FirstName, new XFTY_DummyDefaultValueIncrementingString('Test Contact'))
                .setQuantityPerTemplate(3)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Set<String> firstNames = new Set<String>();
        for (Contact contactRecord : results) {
            Assert.isTrue(contactRecord.FirstName.startsWith('Test Contact'), contactRecord.FirstName);
            firstNames.add(contactRecord.FirstName);
        }
        Assert.areEqual(3, firstNames.size(), 'each record got a distinct incrementing value');
    }

    @IsTest
    static void aBareValueIsWrappedInAnExactStrategy() {
        // Arrange
        // nothing to arrange - put(field, bareValue) is the shorthand under test

        // Act
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, PROVIDER_LOOKUP)
                .put(Account.Type, 'Customer')
                .put(Account.NumberOfEmployees, 500)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Customer', result.Type);
        Assert.areEqual(500, result.NumberOfEmployees);
    }

    @IsTest
    static void aUniqueEmailStrategyNeverCollidesWithinOneRun() {
        // Arrange
        // nothing to arrange

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                .put(Contact.Email, new XFTY_DummyDefaultValueUniqueEmail('team.member'))
                .setQuantityPerTemplate(5)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Set<String> emails = new Set<String>();
        for (Contact contactRecord : results) {
            emails.add(contactRecord.Email);
        }
        Assert.areEqual(5, emails.size(), 'five distinct addresses');
    }
}
