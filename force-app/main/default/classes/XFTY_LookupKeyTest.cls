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
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(new Map<XFTY_LookupKeyIntf, Type>());
        try {
            lookup.get(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'unregistered'));
            Assert.fail('Expected a LookupException');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            Assert.isTrue(ex.getMessage().contains('Account'), ex.getMessage());
        }
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
