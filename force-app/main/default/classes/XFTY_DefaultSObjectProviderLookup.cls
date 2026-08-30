/**
 * The Provider Lookup for XFTY's bundled Providers (Account, Contact, User).
 *
 * Projects typically build their own with {@link XFTY_SObjectProviderLookup},
 * registering the Providers that compile in that package, rather than adding to
 * this one.
 */
@IsTest
public class XFTY_DefaultSObjectProviderLookup implements XFTY_DummySObjectProviderLookupIntf {
    private final XFTY_SObjectProviderLookup registry = new XFTY_SObjectProviderLookup()
            .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class)
            .register(XFTY_LookupKey.get(Contact.SObjectType), XFTY_DefaultContactDataProvider.class)
            .register(XFTY_LookupKey.get(User.SObjectType), XFTY_DefaultUserDataProvider.class);

    public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
        return this.registry.get(sObjectType);
    }

    public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
        return this.registry.get(lookupKey);
    }

    public XFTY_LookupKeyIntf keyFor(SObject sObj) {
        return this.registry.keyFor(sObj);
    }
}
