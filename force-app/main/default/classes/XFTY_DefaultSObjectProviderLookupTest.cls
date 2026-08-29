/**
 * Coverage for `XFTY_DefaultSObjectProviderLookup`, the built-in registry that
 * maps the standard supported SObject types to their Providers.
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
    static void cachesProviderInstancesBetweenCalls() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        Assert.areEqual(
                lookup.get(Account.SObjectType),
                lookup.get(Account.SObjectType),
                'The same Provider instance should be returned each time'
        );
    }

    @IsTest
    static void throwsAFriendlyExceptionForAnUnregisteredType() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        try {
            lookup.get(Case.SObjectType);
            Assert.fail('Expected a LookupException');
        } catch (XFTY_DefaultSObjectProviderLookup.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('No data provider found for'), ex.getMessage());
        }
    }
}
