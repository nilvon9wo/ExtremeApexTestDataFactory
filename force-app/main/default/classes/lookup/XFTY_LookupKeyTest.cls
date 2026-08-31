/**
 * Coverage for the lookup-key types, predicate matching, and
 * `XFTY_ProviderLookups` resolution.
 */
@IsTest
private class XFTY_LookupKeyTest {

    private static final XFTY_FlavouredLookupKey BIG_ACCOUNT =
            (XFTY_FlavouredLookupKey) XFTY_FlavouredLookupKey.get(Account.SObjectType, 'big')
                    .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100));

    private static XFTY_DummySObjectProviderLookupIntf lookupWith(XFTY_LookupKeyIntf refinedKey) {
        return XFTY_ProviderLookups.ofTypes(new Map<XFTY_LookupKeyIntf, Type>{
                XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class,
                refinedKey => XFTY_DefaultAccountDataProvider.class
        });
    }

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
        XFTY_FlavouredLookupKey enterprise = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise')
                .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 500));

        Assert.isTrue(enterprise.isInstanceOf(new Account(NumberOfEmployees = 1000)));
        Assert.isFalse(enterprise.isInstanceOf(new Account(NumberOfEmployees = 10)));
        Assert.isFalse(enterprise.isInstanceOf(new Account()));
        Assert.isFalse(enterprise.isInstanceOf(new Contact()));
    }

    @IsTest
    static void flavouredKeyCombinesRecordTypeAndPredicates() {
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, null, 'named')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name));

        Assert.areEqual('Account::flavour=named', key.getHashKey());
        Assert.isTrue(key.isInstanceOf(new Account(Name = 'x')));
        Assert.isFalse(key.isInstanceOf(new Account()));
    }

    @IsTest
    static void flavouredKeyIsMoreSpecificWithMorePredicates() {
        XFTY_FlavouredLookupKey one = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name));
        XFTY_FlavouredLookupKey two = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name))
                .matching(XFTY_FieldPredicate.isNotNull(Account.Industry));

        Assert.isTrue(two.getSpecificity() > one.getSpecificity());
        Assert.isTrue(one.getSpecificity() > 10, 'more specific than a record-type key');
    }

    @IsTest
    static void flavouredKeyWithNoDiscriminatorIsExplicitUseOnly() {
        Assert.isFalse(
                XFTY_FlavouredLookupKey.get(Account.SObjectType, 'no-discriminator').isInstanceOf(new Account()),
                'a flavour with no record type and no predicates never matches a record'
        );
    }

    @IsTest
    static void flavouredKeyExposesItsRecordTypeAndFlavour() {
        // getRecordTypeId() against a real record type is covered by
        // XFTY_RecordTypeRealRtTest (test-support) - it needs a record type to exist.
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'SomeRecordType', 'vip');

        Assert.areEqual('vip', key.getFlavour());
        Assert.areEqual('SomeRecordType', key.getRecordTypeDeveloperName());
        Assert.isNull(key.getRecordTypeId(), 'unknown developer name resolves to null');
    }

    @IsTest
    static void flavouredKeyRejectsARecordOfTheWrongRecordType() {
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'SomeRecordType', 'biz')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name));

        // Right type and predicate, but no / wrong record type.
        Assert.isFalse(key.isInstanceOf(new Account(Name = 'x')));
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

        // negative outcomes for greater/less than
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 900).isSatisfiedBy(big), 'equal, not greater');
        Assert.isFalse(XFTY_FieldPredicate.lessThan(Account.NumberOfEmployees, 900).isSatisfiedBy(big), 'equal, not less');
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 1000).isSatisfiedBy(big));
        Assert.isFalse(XFTY_FieldPredicate.lessThan(Account.NumberOfEmployees, 1).isSatisfiedBy(big));
    }

    @IsTest
    static void greaterThanAndLessThanCompareDatesTimesAndStrings() {
        // Date
        Contact earlyBorn = new Contact(Birthdate = Date.newInstance(1980, 1, 1));
        Contact lateBorn = new Contact(Birthdate = Date.newInstance(2020, 1, 1));
        Assert.isTrue(XFTY_FieldPredicate.greaterThan(Contact.Birthdate, Date.newInstance(2000, 1, 1)).isSatisfiedBy(lateBorn));
        Assert.isTrue(XFTY_FieldPredicate.lessThan(Contact.Birthdate, Date.newInstance(2000, 1, 1)).isSatisfiedBy(earlyBorn));
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Contact.Birthdate, Date.newInstance(1980, 1, 1)).isSatisfiedBy(earlyBorn), 'equal');

        // Datetime
        Datetime noon = Datetime.newInstanceGmt(2024, 1, 1, 12, 0, 0);
        Event afternoon = new Event(ActivityDateTime = noon.addHours(1));
        Assert.isTrue(XFTY_FieldPredicate.greaterThan(Event.ActivityDateTime, noon).isSatisfiedBy(afternoon));
        Assert.isTrue(XFTY_FieldPredicate.lessThan(Event.ActivityDateTime, noon.addHours(2)).isSatisfiedBy(afternoon));
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Event.ActivityDateTime, noon.addHours(1)).isSatisfiedBy(afternoon), 'equal');

        // String (lexicographic)
        Account acme = new Account(Name = 'Acme');
        Assert.isTrue(XFTY_FieldPredicate.greaterThan(Account.Name, 'Aardvark').isSatisfiedBy(acme));
        Assert.isTrue(XFTY_FieldPredicate.lessThan(Account.Name, 'Beta').isSatisfiedBy(acme));
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Account.Name, 'Acme').isSatisfiedBy(acme), 'equal');
    }

    @IsTest
    static void fieldPredicatesHandleNulls() {
        // null record
        Assert.isFalse(XFTY_FieldPredicate.equalTo(Account.Industry, 'x').isSatisfiedBy(null));
        Assert.isTrue(XFTY_FieldPredicate.isNull(Account.Industry).isSatisfiedBy(null));
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 1).isSatisfiedBy(null));

        // null field value / null threshold
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 1).isSatisfiedBy(new Account()));
        Assert.isFalse(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, null).isSatisfiedBy(new Account(NumberOfEmployees = 5)));

        // inSet with a null value set
        Assert.isFalse(XFTY_FieldPredicate.inSet(Account.Industry, null).isSatisfiedBy(new Account(Industry = 'x')));
    }

    // Lookup keys as Map keys -----------------------------------------------

    @IsTest
    static void keysCompareByValueSoTheyWorkAsMapKeys() {
        Map<XFTY_LookupKeyIntf, String> byKey = new Map<XFTY_LookupKeyIntf, String>{
                XFTY_LookupKey.get(Account.SObjectType) => 'plain',
                XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business') => 'rt'
        };

        Assert.areEqual('plain', byKey.get(XFTY_LookupKey.get(Account.SObjectType)));
        Assert.areEqual('rt', byKey.get(XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business')));
        // A freshly-built flavoured key with the same hash still matches.
        Map<XFTY_LookupKeyIntf, String> flavoured = new Map<XFTY_LookupKeyIntf, String>{
                XFTY_FlavouredLookupKey.get(Account.SObjectType, 'x') => 'first'
        };
        Assert.areEqual('first', flavoured.get(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'x')));
    }

    // XFTY_ProviderLookups -------------------------------------------------

    @IsTest
    static void resolvesAKeyToItsProviderAndCachesTheInstance() {
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(
                new Map<XFTY_LookupKeyIntf, Type>{
                        XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class
                }
        );

        XFTY_DummySobjectProviderIntf first = lookup.get(XFTY_LookupKey.get(Account.SObjectType));
        Assert.isInstanceOfType(first, XFTY_DefaultAccountDataProvider.class);
        Assert.areEqual(first, lookup.get(Account.SObjectType), 'get(SObjectType) resolves the same way and caches');
    }

    @IsTest
    static void ofWrapsACompleteMapOfProviderInstances() {
        XFTY_DummySObjectProviderIntf provider = new XFTY_DefaultAccountDataProvider();
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => provider
                }
        );

        Assert.areEqual(provider, lookup.get(Account.SObjectType));
    }

    @IsTest
    static void throwsAFriendlyExceptionForAnUnregisteredKey() {
        // ...on a type-map lookup
        try {
            XFTY_ProviderLookups.ofTypes(new Map<XFTY_LookupKeyIntf, Type>())
                    .get(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'unregistered'));
            Assert.fail('Expected a LookupException (types)');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('Account'), ex.getMessage());
        }
        // ...and on an instance-map lookup
        try {
            XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>())
                    .get(XFTY_LookupKey.get(Contact.SObjectType));
            Assert.fail('Expected a LookupException (instances)');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('Contact'), ex.getMessage());
        }
    }

    @IsTest
    static void providerLookupsRejectNullArguments() {
        Map<XFTY_LookupKeyIntf, Type> types = new Map<XFTY_LookupKeyIntf, Type>();
        Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> instances =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();
        Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> cache =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

        try {
            XFTY_ProviderLookups.get(types, cache, null);
            Assert.fail('null key, type map');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('lookup key is required'), ex.getMessage());
        }
        try {
            XFTY_ProviderLookups.get(instances, null);
            Assert.fail('null key, instance map');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('lookup key is required'), ex.getMessage());
        }
        try {
            XFTY_ProviderLookups.keysFor(new Set<XFTY_LookupKeyIntf>(), null);
            Assert.fail('null SObject, keysFor');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('SObject is required'), ex.getMessage());
        }
    }

    @IsTest
    static void keysForSkipsKeysForOtherSObjectTypes() {
        Set<XFTY_LookupKeyIntf> registered = new Set<XFTY_LookupKeyIntf>{
                XFTY_LookupKey.get(Account.SObjectType),
                XFTY_LookupKey.get(Contact.SObjectType)
        };

        Assert.areEqual(
                new Set<String>{ 'Account' },
                hashesOf(XFTY_ProviderLookups.keysFor(registered, new Account()))
        );
    }

    @IsTest
    static void keysForReturnsEveryMatchingKey() {
        XFTY_DummySObjectProviderLookupIntf lookup = lookupWith(BIG_ACCOUNT);

        Assert.areEqual(
                new Set<String>{ 'Account', 'Account::flavour=big' },
                hashesOf(lookup.keysFor(new Account(NumberOfEmployees = 500)))
        );
        Assert.areEqual(
                new Set<String>{ 'Account' },
                hashesOf(lookup.keysFor(new Account(NumberOfEmployees = 1)))
        );
    }

    @IsTest
    static void resolvePicksTheMostSpecificMatch() {
        XFTY_DummySObjectProviderLookupIntf lookup = lookupWith(BIG_ACCOUNT);

        Assert.areEqual('Account::flavour=big',
                XFTY_ProviderLookups.resolve(lookup, new Account(NumberOfEmployees = 500)).getHashKey());
        Assert.areEqual('Account',
                XFTY_ProviderLookups.resolve(lookup, new Account(NumberOfEmployees = 1)).getHashKey());
    }

    @IsTest
    static void resolveFallsBackToThePlainKeyWhenNothingRefinedMatches() {
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(
                new Map<XFTY_LookupKeyIntf, Type>{
                        XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class
                }
        );
        Assert.areEqual('Account', XFTY_ProviderLookups.resolve(lookup, new Account()).getHashKey());
    }

    @IsTest
    static void resolveThrowsWhenTwoEquallySpecificKeysMatch() {
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(
                new Map<XFTY_LookupKeyIntf, Type>{
                        XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a')
                                .matching(XFTY_FieldPredicate.isNotNull(Account.Name)) => XFTY_DefaultAccountDataProvider.class,
                        XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b')
                                .matching(XFTY_FieldPredicate.isNotNull(Account.Name)) => XFTY_DefaultAccountDataProvider.class
                }
        );

        try {
            XFTY_ProviderLookups.resolve(lookup, new Account(Name = 'x'));
            Assert.fail('Expected an ambiguity exception');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('Ambiguous'), ex.getMessage());
        }
    }

    private static Set<String> hashesOf(Set<XFTY_LookupKeyIntf> keys) {
        Set<String> hashes = new Set<String>();
        for (XFTY_LookupKeyIntf key : keys) {
            hashes.add(key.getHashKey());
        }
        return hashes;
    }
}
