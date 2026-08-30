/**
 * Coverage for `XFTY_DefaultSObjectProviderLookup` - the built-in Providers,
 * registration, and `get(...)` resolution. Key derivation (`keysFor` /
 * `XFTY_LookupKeys.resolve`) is covered in `XFTY_LookupKeyTest`.
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
    static void keysForReturnsNoRefinedKeysForTheDefaultProviders() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        // The default lookup registers only plain type keys, which match.
        Set<String> hashes = new Set<String>();
        for (XFTY_LookupKeyIntf key : lookup.keysFor(new Account())) {
            hashes.add(key.getHashKey());
        }
        Assert.areEqual(new Set<String>{ 'Account' }, hashes);

        Assert.areEqual('Account', XFTY_LookupKeys.resolve(lookup, new Account()).getHashKey());
    }

    @IsTest
    static void throwsAFriendlyExceptionForAnUnregisteredType() {
        XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

        try {
            lookup.get(Case.SObjectType);
            Assert.fail('Expected a LookupException');
        } catch (XFTY_DefaultSObjectProviderLookup.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('No data provider registered'), ex.getMessage());
        }
    }
}
