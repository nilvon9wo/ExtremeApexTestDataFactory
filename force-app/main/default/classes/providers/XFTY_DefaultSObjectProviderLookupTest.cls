/**
 * Proves `XFTY_DefaultSObjectProviderLookup` - the built-in Providers and
 * `get(...)` resolution. Key derivation is covered in `XFTY_LookupKeyTest`. Pure
 * in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_DefaultSObjectProviderLookupTest {

    @IsTest
    static void testGet_forEachRegisteredSObjectType_returnsItsProvider() {
        // Arrange
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        // Act
        Test.startTest();
        XFTY_DummySobjectProviderIntf accountProvider = lookup.get(Account.SObjectType);
        Test.stopTest();

        // Assert
        Assert.isInstanceOfType(accountProvider, XFTY_DefaultAccountDataProvider.class);
        Assert.isInstanceOfType(lookup.get(Contact.SObjectType), XFTY_DefaultContactDataProvider.class);
        Assert.isInstanceOfType(lookup.get(User.SObjectType), XFTY_DefaultUserDataProvider.class);
    }

    @IsTest
    static void testGet_bySObjectTypeAndByPlainKey_returnTheSameProvider() {
        // Arrange
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        // Act
        Test.startTest();
        XFTY_DummySobjectProviderIntf byKey = lookup.get(XFTY_LookupKey.get(Account.SObjectType));
        Test.stopTest();

        // Assert
        Assert.areEqual(lookup.get(Account.SObjectType), byKey);
    }

    @IsTest
    static void testGet_calledTwiceForTheSameType_returnsTheOneCachedInstance() {
        // Arrange
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        // Act
        Test.startTest();
        XFTY_DummySobjectProviderIntf first = lookup.get(Account.SObjectType);
        Test.stopTest();

        // Assert
        Assert.areEqual(first, lookup.get(Account.SObjectType), 'the same Provider instance is returned each time');
    }

    @IsTest
    static void testKeysFor_forADefaultProviderRecord_returnsOnlyThePlainTypeKey() {
        // Arrange
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        // Act
        Test.startTest();
        Set<XFTY_LookupKeyIntf> keys = lookup.keysFor(new Account());
        Test.stopTest();

        // Assert
        Set<String> hashes = new Set<String>();
        for (XFTY_LookupKeyIntf key : keys) {
            hashes.add(key.getHashKey());
        }
        Assert.areEqual(new Set<String>{ 'Account' }, hashes);
    }

    @IsTest
    static void testGet_forAnUnregisteredType_throwsAFriendlyException() {
        // Arrange
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            lookup.get(Case.SObjectType);
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('No data provider registered'), thrown.getMessage());
    }
}
