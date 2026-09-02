/**
 * Proves the lookup-key types (`XFTY_LookupKey`, `XFTY_RecordTypeLookupKey`,
 * `XFTY_FlavouredLookupKey`) and `XFTY_ProviderLookups` resolution. The predicate
 * building blocks have their own coverage in `classes/predicates/`.
 */
@IsTest
private class XFTY_LookupKeyTest {

    // Flavoured keys are interned flyweights whose .matching(...) predicates
    // mutate the shared instance - build each exactly once, here.
    private static final XFTY_FlavouredLookupKey BIG_ACCOUNT =
            (XFTY_FlavouredLookupKey) XFTY_FlavouredLookupKey.get(Account.SObjectType, 'big')
                    .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100));
    private static final XFTY_FlavouredLookupKey ENTERPRISE_FLAVOUR =
            (XFTY_FlavouredLookupKey) XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise')
                    .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 500));
    private static final XFTY_FlavouredLookupKey NAMED_FLAVOUR =
            (XFTY_FlavouredLookupKey) XFTY_FlavouredLookupKey.get(Account.SObjectType, null, 'named-runner')
                    .matching(XFTY_FieldPredicate.isNotNull(Account.Name));

    // XFTY_LookupKey ---------------------------------------------------------

    @IsTest
    static void testGetHashKey_forAPlainKey_isTheSObjectApiName() {
        // Arrange
        XFTY_LookupKey key = XFTY_LookupKey.get(Account.SObjectType);

        // Act
        String hashKey = key.getHashKey();

        // Assert
        Assert.areEqual('Account', hashKey);
    }

    @IsTest
    static void testGetSObjectType_forAPlainKey_isTheTypeItWasBuiltFor() {
        // Arrange
        XFTY_LookupKey key = XFTY_LookupKey.get(Account.SObjectType);

        // Act
        SObjectType type = key.getSObjectType();

        // Assert
        Assert.areEqual(Account.SObjectType, type);
    }

    @IsTest
    static void testGetSpecificity_forAPlainKey_isZero() {
        // Arrange
        XFTY_LookupKey key = XFTY_LookupKey.get(Account.SObjectType);

        // Act
        Integer specificity = key.getSpecificity();

        // Assert
        Assert.areEqual(0, specificity);
    }

    @IsTest
    static void testIsInstanceOf_whenTheRecordIsOfThatType_returnsTrue() {
        testPlainKeyIsInstanceOf(new Account(), true);
    }

    @IsTest
    static void testIsInstanceOf_whenTheRecordIsADifferentType_returnsFalse() {
        testPlainKeyIsInstanceOf(new Contact(), false);
    }

    @IsTest
    static void testIsInstanceOf_whenTheRecordIsNull_returnsFalse() {
        testPlainKeyIsInstanceOf(null, false);
    }

    @IsTest
    static void testGet_forATypeAndForARecordOfThatType_returnsTheOneInternedInstance() {
        // Arrange
        // nothing to arrange - the flyweight is under test

        // Act
        XFTY_LookupKey fromType = XFTY_LookupKey.get(Account.SObjectType);

        // Assert
        Assert.areEqual(fromType, XFTY_LookupKey.get(new Account()), 'get(type) and get(record) intern the same key');
    }

    @IsTest
    static void testGet_whenTheTypeIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_LookupKey.get((SObjectType) null);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a null type must be rejected');
        Assert.isTrue(thrown.getMessage().contains('requires an SObjectType'), thrown.getMessage());
    }

    // XFTY_RecordTypeLookupKey ---------------------------------------------

    @IsTest
    static void testGetHashKey_forARecordTypeKey_encodesTheDeveloperName() {
        // Arrange
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business');

        // Act
        String hashKey = key.getHashKey();

        // Assert
        Assert.areEqual('Account::recordType=Business', hashKey);
    }

    @IsTest
    static void testGetSpecificity_forARecordTypeKey_isTenAndBeatsThePlainKey() {
        // Arrange
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business');

        // Act
        Integer specificity = key.getSpecificity();

        // Assert
        Assert.areEqual(10, specificity);
        Assert.isTrue(specificity > XFTY_LookupKey.get(Account.SObjectType).getSpecificity());
    }

    @IsTest
    static void testGetRecordTypeDeveloperName_forARecordTypeKey_isTheNameItWasBuiltWith() {
        // Arrange
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business');

        // Act
        String developerName = key.getRecordTypeDeveloperName();

        // Assert
        Assert.areEqual('Business', developerName);
    }

    @IsTest
    static void testGetRecordTypeId_forAnUnknownDeveloperName_isNull() {
        // Arrange
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'NoSuchRecordType');

        // Act
        Id recordTypeId = key.getRecordTypeId();

        // Assert
        Assert.isNull(recordTypeId, 'the Id is resolved from the describe, never hard-coded');
    }

    @IsTest
    static void testIsInstanceOf_whenTheRecordResolvesToTheSameDeveloperName_returnsTrue() {
        // Arrange - an Account with no RecordTypeId resolves to a null developer name
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(new Account());

        // Act
        Boolean matches = key.isInstanceOf(new Account());

        // Assert
        Assert.isTrue(matches);
    }

    @IsTest
    static void testIsInstanceOf_forARecordTypeKey_whenTheRecordIsADifferentType_returnsFalse() {
        // Arrange
        XFTY_RecordTypeLookupKey key = XFTY_RecordTypeLookupKey.get(new Account());

        // Act
        Boolean matches = key.isInstanceOf(new Contact());

        // Assert
        Assert.isFalse(matches);
    }

    // XFTY_FlavouredLookupKey --------------------------------------------

    @IsTest
    static void testIsInstanceOf_whenEveryPredicateHolds_returnsTrue() {
        testEnterpriseFlavourIsInstanceOf(new Account(NumberOfEmployees = 1000), true);
    }

    @IsTest
    static void testIsInstanceOf_whenAPredicateFails_returnsFalse() {
        testEnterpriseFlavourIsInstanceOf(new Account(NumberOfEmployees = 10), false);
    }

    @IsTest
    static void testIsInstanceOf_whenThePredicatedFieldIsBlank_returnsFalse() {
        testEnterpriseFlavourIsInstanceOf(new Account(), false);
    }

    @IsTest
    static void testIsInstanceOf_forAFlavouredKey_whenTheRecordIsADifferentType_returnsFalse() {
        testEnterpriseFlavourIsInstanceOf(new Contact(), false);
    }

    @IsTest
    static void testIsInstanceOf_whenAPredicateHoldsAndNoRecordTypeIsRequired_returnsTrue() {
        testNamedFlavourIsInstanceOf(new Account(Name = 'x'), true);
    }

    @IsTest
    static void testIsInstanceOf_whenThePredicateFailsAndNoRecordTypeIsRequired_returnsFalse() {
        testNamedFlavourIsInstanceOf(new Account(), false);
    }

    @IsTest
    static void testGetHashKey_forAFlavouredKeyWithoutARecordType_isTypeAndFlavour() {
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, null, 'named');

        // Act
        String hashKey = key.getHashKey();

        // Assert
        Assert.areEqual('Account::flavour=named', hashKey);
    }

    @IsTest
    static void testGetSpecificity_forAFlavouredKey_growsWithEachPredicateAndBeatsARecordTypeKey() {
        // Arrange
        XFTY_FlavouredLookupKey onePredicate = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name));
        XFTY_FlavouredLookupKey twoPredicates = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name))
                .matching(XFTY_FieldPredicate.isNotNull(Account.Industry));

        // Act
        Integer oneSpecificity = onePredicate.getSpecificity();

        // Assert
        Assert.isTrue(twoPredicates.getSpecificity() > oneSpecificity, 'more predicates = more specific');
        Assert.isTrue(oneSpecificity > 10, 'more specific than a record-type key');
    }

    @IsTest
    static void testIsInstanceOf_whenTheFlavourHasNoRecordTypeAndNoPredicates_returnsFalse() {
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'no-discriminator');

        // Act
        Boolean matches = key.isInstanceOf(new Account());

        // Assert
        Assert.isFalse(matches, 'a flavour with nothing on the record to match can only be used explicitly');
    }

    @IsTest
    static void testGetFlavour_forAFlavouredKey_isTheFlavourItWasBuiltWith() {
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'SomeRecordType', 'vip');

        // Act
        String flavour = key.getFlavour();

        // Assert
        Assert.areEqual('vip', flavour);
        Assert.areEqual('SomeRecordType', key.getRecordTypeDeveloperName());
    }

    @IsTest
    static void testGetRecordTypeId_forAFlavouredKeyWithAnUnknownDeveloperName_isNull() {
        // getRecordTypeId() against a real record type is covered by
        // XFTY_RecordTypeRealRtTest (test-support) - it needs a record type to exist.
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'SomeRecordType', 'vip');

        // Act
        Id recordTypeId = key.getRecordTypeId();

        // Assert
        Assert.isNull(recordTypeId);
    }

    @IsTest
    static void testIsInstanceOf_whenThePredicateHoldsButTheRecordTypeIsWrong_returnsFalse() {
        // Arrange
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'SomeRecordType', 'biz')
                .matching(XFTY_FieldPredicate.isNotNull(Account.Name));

        // Act
        Boolean matches = key.isInstanceOf(new Account(Name = 'x'));

        // Assert
        Assert.isFalse(matches, 'right type and predicate, but no matching record type');
    }

    // Lookup keys as Map keys -------------------------------------------

    @IsTest
    static void testGet_onAMapKeyedByLookupKey_findsTheEntryByValueEquality() {
        // Arrange
        Map<XFTY_LookupKeyIntf, String> byKey = new Map<XFTY_LookupKeyIntf, String>{
                XFTY_LookupKey.get(Account.SObjectType) => 'plain',
                XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business') => 'rt',
                XFTY_FlavouredLookupKey.get(Account.SObjectType, 'x') => 'flavoured'
        };

        // Act
        String plain = byKey.get(XFTY_LookupKey.get(Account.SObjectType));

        // Assert
        Assert.areEqual('plain', plain);
        Assert.areEqual('rt', byKey.get(XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'Business')));
        Assert.areEqual('flavoured', byKey.get(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'x')),
                'a freshly-built flavoured key with the same hash still matches');
    }

    // XFTY_ProviderLookups -------------------------------------------------

    @IsTest
    static void testGet_forARegisteredKey_returnsTheProviderAndCachesTheInstance() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(
                new Map<XFTY_LookupKeyIntf, Type>{
                        XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class
                }
        );

        // Act
        XFTY_DummySobjectProviderIntf first = lookup.get(XFTY_LookupKey.get(Account.SObjectType));

        // Assert
        Assert.isInstanceOfType(first, XFTY_DefaultAccountDataProvider.class);
        Assert.areEqual(first, lookup.get(Account.SObjectType), 'get(SObjectType) resolves the same way and caches');
    }

    @IsTest
    static void testGet_onAnInstanceMapLookup_returnsTheRegisteredProvider() {
        // Arrange
        XFTY_DummySObjectProviderIntf provider = new XFTY_DefaultAccountDataProvider();
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => provider
                }
        );

        // Act
        XFTY_DummySobjectProviderIntf resolved = lookup.get(Account.SObjectType);

        // Assert
        Assert.areEqual(provider, resolved);
    }

    @IsTest
    static void testGet_forAnUnregisteredKeyOnATypeMapLookup_throws() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(new Map<XFTY_LookupKeyIntf, Type>());

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            lookup.get(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'unregistered'));
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Account'), thrown.getMessage());
    }

    @IsTest
    static void testGet_forAnUnregisteredKeyOnAnInstanceMapLookup_throws() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup =
                XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>());

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            lookup.get(XFTY_LookupKey.get(Contact.SObjectType));
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Contact'), thrown.getMessage());
    }

    @IsTest
    static void testGet_whenTheKeyIsNull_throws() {
        // Arrange
        Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> instances =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            XFTY_ProviderLookups.get(instances, null);
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('lookup key is required'), thrown.getMessage());
    }

    @IsTest
    static void testGet_onACachingTypeMapLookupWhenTheKeyIsNull_throws() {
        // Arrange
        Map<XFTY_LookupKeyIntf, Type> types = new Map<XFTY_LookupKeyIntf, Type>();
        Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> cache =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            XFTY_ProviderLookups.get(types, cache, null);
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('lookup key is required'), thrown.getMessage());
    }

    @IsTest
    static void testKeysFor_whenGivenANullSObject_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            XFTY_ProviderLookups.keysFor(new Set<XFTY_LookupKeyIntf>(), null);
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('SObject is required'), thrown.getMessage());
    }

    @IsTest
    static void testKeysFor_skipsKeysRegisteredForOtherSObjectTypes() {
        // Arrange
        Set<XFTY_LookupKeyIntf> registered = new Set<XFTY_LookupKeyIntf>{
                XFTY_LookupKey.get(Account.SObjectType),
                XFTY_LookupKey.get(Contact.SObjectType)
        };

        // Act
        Set<XFTY_LookupKeyIntf> matches = XFTY_ProviderLookups.keysFor(registered, new Account());

        // Assert
        Assert.areEqual(new Set<String>{ 'Account' }, hashesOf(matches));
    }

    @IsTest
    static void testKeysFor_whenARecordMatchesARefinedKey_returnsBothItAndThePlainKey() {
        testKeysForHashes(new Account(NumberOfEmployees = 500), new Set<String>{ 'Account', 'Account::flavour=big' });
    }

    @IsTest
    static void testKeysFor_whenARecordMatchesOnlyThePlainKey_returnsJustThePlainKey() {
        testKeysForHashes(new Account(NumberOfEmployees = 1), new Set<String>{ 'Account' });
    }

    @IsTest
    static void testResolve_whenARefinedKeyMatches_picksTheMostSpecific() {
        testResolveHash(new Account(NumberOfEmployees = 500), 'Account::flavour=big');
    }

    @IsTest
    static void testResolve_whenNothingRefinedMatches_picksThePlainKey() {
        testResolveHash(new Account(NumberOfEmployees = 1), 'Account');
    }

    @IsTest
    static void testResolve_whenTwoEquallySpecificKeysMatch_throws() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(
                new Map<XFTY_LookupKeyIntf, Type>{
                        XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a')
                                .matching(XFTY_FieldPredicate.isNotNull(Account.Name)) => XFTY_DefaultAccountDataProvider.class,
                        XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b')
                                .matching(XFTY_FieldPredicate.isNotNull(Account.Name)) => XFTY_DefaultAccountDataProvider.class
                }
        );

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            XFTY_ProviderLookups.resolve(lookup, new Account(Name = 'x'));
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Ambiguous'), thrown.getMessage());
    }

    // Runners + helpers ------------------------------------------------

    static void testPlainKeyIsInstanceOf(SObject record, Boolean expected) {
        // Arrange
        XFTY_LookupKey key = XFTY_LookupKey.get(Account.SObjectType);

        // Act
        Test.startTest();
        Boolean matches = key.isInstanceOf(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expected, matches);
    }

    static void testEnterpriseFlavourIsInstanceOf(SObject record, Boolean expected) {
        // Arrange - ENTERPRISE_FLAVOUR

        // Act
        Test.startTest();
        Boolean matches = ENTERPRISE_FLAVOUR.isInstanceOf(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expected, matches);
    }

    static void testNamedFlavourIsInstanceOf(SObject record, Boolean expected) {
        // Arrange - NAMED_FLAVOUR (a flavour with no record type, one predicate)

        // Act
        Test.startTest();
        Boolean matches = NAMED_FLAVOUR.isInstanceOf(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expected, matches);
    }

    static void testKeysForHashes(SObject record, Set<String> expectedHashes) {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(new Map<XFTY_LookupKeyIntf, Type>{
                XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class,
                BIG_ACCOUNT => XFTY_DefaultAccountDataProvider.class
        });

        // Act
        Test.startTest();
        Set<XFTY_LookupKeyIntf> matches = lookup.keysFor(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedHashes, hashesOf(matches));
    }

    static void testResolveHash(SObject record, String expectedHash) {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.ofTypes(new Map<XFTY_LookupKeyIntf, Type>{
                XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class,
                BIG_ACCOUNT => XFTY_DefaultAccountDataProvider.class
        });

        // Act
        Test.startTest();
        XFTY_LookupKeyIntf resolved = XFTY_ProviderLookups.resolve(lookup, record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedHash, resolved.getHashKey());
    }

    private static Set<String> hashesOf(Set<XFTY_LookupKeyIntf> keys) {
        Set<String> hashes = new Set<String>();
        for (XFTY_LookupKeyIntf key : keys) {
            hashes.add(key.getHashKey());
        }
        return hashes;
    }
}
