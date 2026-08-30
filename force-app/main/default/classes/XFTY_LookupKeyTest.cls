/**
 * Coverage for the lookup-key types, predicate matching, and
 * `XFTY_SObjectProviderLookup` registration / resolution.
 */
@IsTest
private class XFTY_LookupKeyTest {

    // XFTY_LookupKey -----------------------------------------------------------

    @IsTest
    static void plainKeyIdentifiesItsTypeAndHashesByApiName() {
        XFTY_LookupKey key = XFTY_LookupKey.get(Account.SObjectType);

        Assert.areEqual(Account.SObjectType, key.getSObjectType());
        Assert.areEqual('Account', key.getHashKey());
        Assert.areEqual(0, key.getSpecificity());
        Assert.isTrue(key.isInstanceOf(new Account()));
        Assert.isFalse(key.isInstanceOf(new Contact()));
        Assert.isFalse(key.isInstanceOf(null));
    }

    @IsTest
    static void plainKeyIsAFlyweight() {
        Assert.areEqual(
                XFTY_LookupKey.get(Account.SObjectType),
                XFTY_LookupKey.get(new Account()),
                'get(type) and get(record of that type) return the one interned instance'
        );
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

    // XFTY_RecordTypeLookupKey -------------------------------------------

    @IsTest
    static void recordTypeKeyEncodesTheDeveloperNameAndIsMoreSpecific() {
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business');

        Assert.areEqual(Account.SObjectType, key.getSObjectType());
        Assert.areEqual('Business', key.getRecordTypeDeveloperName());
        Assert.areEqual('Account::recordType=Business', key.getHashKey());
        Assert.areEqual(10, key.getSpecificity());
        Assert.isTrue(key.getSpecificity() > XFTY_LookupKey.get(Account.SObjectType).getSpecificity());
    }

    @IsTest
    static void recordTypeKeyResolvesIdsFromTheDescribeNotHardCoding() {
        Assert.isNull(XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'NoSuchRecordType').getRecordTypeId());
    }

    @IsTest
    static void recordTypeKeyMatchesARecordWithTheSameResolvedDeveloperName() {
        // An Account with no RecordTypeId resolves to a null developer name.
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(new Account());
        Assert.isTrue(key.isInstanceOf(new Account()));
        Assert.isFalse(key.isInstanceOf(new Contact()));
    }

    // XFTY_FlavouredLookupKey ------------------------------------------

    @IsTest
    static void flavouredKeyMatchesOnArbitraryPredicates() {
        XFTY_FlavouredLookupKey enterprise = new XFTY_FlavouredLookupKey(Account.SObjectType, 'enterprise')
                .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 500));

        Assert.isTrue(enterprise.isInstanceOf(new Account(NumberOfEmployees = 1000)));
        Assert.isFalse(enterprise.isInstanceOf(new Account(NumberOfEmployees = 10)));
        Assert.isFalse(enterprise.isInstanceOf(new Account()));
        Assert.isFalse(enterprise.isInstanceOf(new Contact()));
    }

    @IsTest
    static void flavouredKeyCombinesRecordTypeAndPredicates() {
        XFTY_FlavouredLookupKey key = new XFTY_FlavouredLookupKey(Account.SObjectType, null, 'named')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name));

        Assert.areEqual('Account::flavour=named', key.getHashKey());
        Assert.isTrue(key.isInstanceOf(new Account(Name = 'x')));
        Assert.isFalse(key.isInstanceOf(new Account()));
    }

    @IsTest
    static void flavouredKeyIsMoreSpecificWithMorePredicates() {
        XFTY_FlavouredLookupKey one = new XFTY_FlavouredLookupKey(Account.SObjectType, 'a')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name));
        XFTY_FlavouredLookupKey two = new XFTY_FlavouredLookupKey(Account.SObjectType, 'b')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name))
                .matching(XFTY_FieldPredicate.isNotNull(Account.Industry));

        Assert.isTrue(two.getSpecificity() > one.getSpecificity());
        Assert.isTrue(one.getSpecificity() > 10, 'more specific than a record-type key');
    }

    // XFTY_FieldPredicate --------------------------------------------

    @IsTest
    static void fieldPredicatesCoverTheCommonConditions() {
        Account big = new Account(NumberOfEmployees = 900, Industry = 'Technology');
        Account small = new Account(NumberOfEmployees = 5);

        Assert.isTrue(XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology').isSatisfiedBy(big));
        Assert.isTrue(XFTY_FieldPredicate.notEqualTo(Account.Industry, 'Retail').isSatisfiedBy(big));
        Assert.isTrue(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100).isSatisfiedBy(big));
        Assert.isTrue(XFTY_FieldPredicate.lessThan(Account.NumberOfEmployees, 100).isSatisfiedBy(small));
        Assert.isTrue(XFTY_FieldPredicate.isNull(Account.Industry).isSatisfiedBy(small));
        Assert.isTrue(XFTY_FieldPredicate.isNotNull(Account.Industry).isSatisfiedBy(big));
        Assert.isTrue(
                XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Finance', 'Technology' }).isSatisfiedBy(big)
        );
        Assert.isFalse(
                XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Finance' }).isSatisfiedBy(big)
        );
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
            lookup.get(new XFTY_FlavouredLookupKey(Account.SObjectType, 'unregistered'));
            Assert.fail('Expected a LookupException');
        } catch (XFTY_SObjectProviderLookup.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('Account'), ex.getMessage());
        }
    }

    @IsTest
    static void lookupRejectsDoubleRegistrationOfTheSameKey() {
        try {
            new XFTY_SObjectProviderLookup()
                    .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class)
                    .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultContactDataProvider.class);
            Assert.fail('Expected a LookupException');
        } catch (XFTY_SObjectProviderLookup.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('already registered'), ex.getMessage());
        }
    }

    @IsTest
    static void keysForReturnsEveryMatchingRegisteredKey() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup()
                .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class)
                .register(
                        new XFTY_FlavouredLookupKey(Account.SObjectType, 'big')
                                .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100)),
                        XFTY_DefaultAccountDataProvider.class
                );

        Set<String> hashes = new Set<String>();
        for (XFTY_LookupKeyIntf key : lookup.keysFor(new Account(NumberOfEmployees = 500))) {
            hashes.add(key.getHashKey());
        }
        Assert.areEqual(new Set<String>{ 'Account', 'Account::flavour=big' }, hashes);

        // The small Account only matches the plain key.
        hashes = new Set<String>();
        for (XFTY_LookupKeyIntf key : lookup.keysFor(new Account(NumberOfEmployees = 1))) {
            hashes.add(key.getHashKey());
        }
        Assert.areEqual(new Set<String>{ 'Account' }, hashes);
    }

    // XFTY_LookupKeys.resolve --------------------------------------

    @IsTest
    static void resolvePicksTheMostSpecificMatch() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup()
                .register(XFTY_LookupKey.get(Account.SObjectType), XFTY_DefaultAccountDataProvider.class)
                .register(
                        new XFTY_FlavouredLookupKey(Account.SObjectType, 'big')
                                .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100)),
                        XFTY_DefaultAccountDataProvider.class
                );

        Assert.areEqual('Account::flavour=big',
                XFTY_LookupKeys.resolve(lookup, new Account(NumberOfEmployees = 500)).getHashKey());
        Assert.areEqual('Account',
                XFTY_LookupKeys.resolve(lookup, new Account(NumberOfEmployees = 1)).getHashKey());
    }

    @IsTest
    static void resolveFallsBackToThePlainKeyWhenNothingIsRegistered() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup();
        Assert.areEqual('Account', XFTY_LookupKeys.resolve(lookup, new Account()).getHashKey());
    }

    @IsTest
    static void resolveThrowsWhenTwoEquallySpecificKeysMatch() {
        XFTY_SObjectProviderLookup lookup = new XFTY_SObjectProviderLookup()
                .register(
                        new XFTY_FlavouredLookupKey(Account.SObjectType, 'a')
                                .matching(XFTY_FieldPredicate.isNotNull(Account.Name)),
                        XFTY_DefaultAccountDataProvider.class
                )
                .register(
                        new XFTY_FlavouredLookupKey(Account.SObjectType, 'b')
                                .matching(XFTY_FieldPredicate.isNotNull(Account.Name)),
                        XFTY_DefaultAccountDataProvider.class
                );

        try {
            XFTY_LookupKeys.resolve(lookup, new Account(Name = 'x'));
            Assert.fail('Expected an ambiguity exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('Ambiguous'), ex.getMessage());
        }
    }
}
