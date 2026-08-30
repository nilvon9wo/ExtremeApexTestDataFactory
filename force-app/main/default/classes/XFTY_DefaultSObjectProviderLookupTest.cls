/**
 * Coverage for `XFTY_DefaultSObjectProviderLookup` and the resolution /
 * registration behaviour it inherits from `XFTY_AbstractSObjectProviderLookup`.
 */
@IsTest
private class XFTY_DefaultSObjectProviderLookupTest {

    @IsTest
    static void resolvesEachRegisteredSObjectTypeToItsProvider() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        Assert.isInstanceOfType(lookup.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class);
        Assert.isInstanceOfType(lookup.get(Contact.SObjectType), XFTY_DefaultContactDataProvider.class);
        Assert.isInstanceOfType(lookup.get(User.SObjectType), XFTY_DefaultUserDataProvider.class);
    }

    @IsTest
    static void getBySObjectTypeAndGetByPlainKeyAreEquivalent() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        Assert.areEqual(
                lookup.get(Account.SObjectType),
                lookup.get(XFTY_LookupKey.get(Account.SObjectType))
        );
    }

    @IsTest
    static void cachesProviderInstancesBetweenCalls() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        Assert.areEqual(
                lookup.get(Account.SObjectType),
                lookup.get(Account.SObjectType),
                'The same Provider instance should be returned each time'
        );
    }

    @IsTest
    static void keyForFallsBackToThePlainKeyWhenNothingRefinedMatches() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        XFTY_LookupKeyIntf key = lookup.keyFor(new Account());

        Assert.areEqual(XFTY_LookupKey.get(Account.SObjectType).getHashKey(), key.getHashKey());
    }

    @IsTest
    static void throwsAFriendlyExceptionForAnUnregisteredType() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        try {
            lookup.get(Case.SObjectType);
            Assert.fail('Expected a LookupException');
        } catch (XFTY_SObjectProviderLookup.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('No data provider registered'), ex.getMessage());
        }
    }
}
