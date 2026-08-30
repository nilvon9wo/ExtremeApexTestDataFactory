/**
 * Coverage for the lookup-key types and `XFTY_SObjectProviderLookup`
 * registration / resolution.
 */
@IsTest
private class XFTY_LookupKeyTest {

    // XFTY_LookupKey -----------------------------------------------------------

    @IsTest
    static void plainKeyIdentifiesItsTypeAndHashesByApiName() {
        XFTY_LookupKey key = XFTY_LookupKey.get(Account.SObjectType);

        Assert.areEqual(Account.SObjectType, key.getSObjectType());
        Assert.areEqual('Account', key.getHashKey());
        Assert.isTrue(key.isInstanceOf(new Account()));
        Assert.isFalse(key.isInstanceOf(new Contact()));
        Assert.isFalse(key.isInstanceOf(null));
    }

    @IsTest
    static void plainKeyCanBeDerivedFromARecord() {
        XFTY_LookupKey key = XFTY_LookupKey.get(new Contact());
        Assert.areEqual(Contact.SObjectType, key.getSObjectType());
    }

    @IsTest
    static void plainKeyRejectsANullType() {
        try {
            XFTY_LookupKey.get((SObjectType) null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('requires an SObjectType'), ex.getMessage());
        }
    }

    @IsTest
    static void keysWithTheSameTypeShareAHashKey() {
        Assert.areEqual(
                XFTY_LookupKey.get(Account.SObjectType).getHashKey(),
                XFTY_LookupKey.get(new Account()).getHashKey()
        );
    }

    // XFTY_FlavorLookupKey -------------------------------------------------

    @IsTest
    static void flavorKeyEncodesTheFlavorAndNeverMatchesARecord() {
        XFTY_FlavorLookupKey key = XFTY_FlavorLookupKey.get(Account.SObjectType, 'past-due');

        Assert.areEqual(Account.SObjectType, key.getSObjectType());
        Assert.areEqual('past-due', key.getFlavor());
        Assert.areEqual('Account::flavor=past-due', key.getHashKey());
        Assert.isFalse(key.isInstanceOf(new Account()), 'A flavor is never read off a record');
    }

    @IsTest
    static void flavorKeysWithDifferentFlavorsAreDistinct() {
        Assert.areNotEqual(
                XFTY_FlavorLookupKey.get(Account.SObjectType, 'a').getHashKey(),
                XFTY_FlavorLookupKey.get(Account.SObjectType, 'b').getHashKey()
        );
    }

    // XFTY_RecordTypeLookupKey -------------------------------------------

    @IsTest
    static void recordTypeKeyEncodesTheDeveloperName() {
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business');

        Assert.areEqual(Account.SObjectType, key.getSObjectType());
        Assert.areEqual('Business', key.getRecordTypeDeveloperName());
        Assert.areEqual('Account::recordType=Business', key.getHashKey());
    }

    @IsTest
    static void recordTypeKeyResolvesIdsFromTheDescribeNotHardCoding() {
        // No custom record types in a fresh scratch org, so an unknown name has no Id.
        Assert.isNull(XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'NoSuchRecordType').getRecordTypeId());
    }

    @IsTest
    static void recordTypeKeyDoesNotMatchADifferentType() {
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business');
        Assert.isFalse(key.isInstanceOf(new Contact()));
    }

    @IsTest
    static void recordTypeKeyMatchesARecordWithTheSameResolvedDeveloperName() {
        // An Account with no RecordTypeId resolves to a null developer name, so a
        // key built for the null developer name matches it.
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(new Account());
        Assert.isTrue(key.isInstanceOf(new Account()));
    }

    // XFTY_SObjectProviderLookup -----------------------------------------

    @IsTest
    static void lookupResolvesRegisteredKeysAndCachesInstances() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup()
                .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class);

        XFTY_DummySobjectProviderIntf first = lookup.get(XFTY_LookupKey.get(Account.SObjectType));
        Assert.isInstanceOfType(first, XFTY_DefaultAccountDataProvider.class);
        Assert.areEqual(first, lookup.get(Account.SObjectType), 'get(SObjectType) resolves the same way and caches');
    }

    @IsTest
    static void lookupThrowsForAnUnregisteredKey() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup();
        try {
            lookup.get(XFTY_FlavorLookupKey.get(Account.SObjectType, 'unregistered'));
            Assert.fail('Expected a LookupException');
        } catch (XFTY_SObjectProviderLookup.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('Account::flavor=unregistered'), ex.getMessage());
        }
    }

    @IsTest
    static void keyForPrefersARefinedKeyThatMatches() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup()
                .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class)
                .register(XFTY_RecordTypeLookupKey.get(new Account()), XFTY_DefaultAccountDataProvider.class);

        XFTY_LookupKeyIntf derived = lookup.keyFor(new Account());
        Assert.areEqual(XFTY_RecordTypeLookupKey.get(new Account()).getHashKey(), derived.getHashKey());
    }

    @IsTest
    static void keyForFallsBackToThePlainKeyWhenNoRefinedKeyMatches() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup()
                .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class)
                .register(XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Master'), XFTY_DefaultAccountDataProvider.class);

        XFTY_LookupKeyIntf derived = lookup.keyFor(new Account());
        Assert.areEqual('Account', derived.getHashKey());
    }
}
