/**
 * Proves how the two ways to name a Provider variant - an explicit lookup key
 * and an override template - are reconciled: `XFTY_ProviderLookups.reconcile`
 * directly, and `XFTY_DummySObjectProvider` end to end.
 *
 * The non-throwing `reconcile` cases delegate Arrange / Act / Assert to
 * `testReconcile`. Nothing here does DML (MOCK mode), so no `System.runAs`.
 */
@IsTest
private class XFTY_VariantResolutionTest {

    private static final XFTY_FlavouredLookupKey BIG =
            (XFTY_FlavouredLookupKey) XFTY_FlavouredLookupKey.get(Account.SObjectType, 'big')
                    .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 1000));
    private static final XFTY_FlavouredLookupKey SMALL =
            (XFTY_FlavouredLookupKey) XFTY_FlavouredLookupKey.get(Account.SObjectType, 'small')
                    .matching(XFTY_FieldPredicate.lessThan(Account.NumberOfEmployees, 10));

    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.ofTypes(new Map<XFTY_LookupKeyIntf, Type>{
                XFTY_LookupKey.get(Account.SObjectType) => XFTY_DefaultAccountDataProvider.class,
                BIG => XFTY_DefaultAccountDataProvider.class,
                SMALL => XFTY_DefaultAccountDataProvider.class
        });
    }

    // XFTY_ProviderLookups.reconcile -------------------------------------------

    @IsTest
    static void testReconcile_whenGivenNeitherKeyNorTemplate_returnsNull() {
        testReconcile(null, null, null);
    }

    @IsTest
    static void testReconcile_whenGivenOnlyATemplate_derivesTheKeyFromIt() {
        testReconcile(null, new Account(NumberOfEmployees = 5000), 'Account::flavour=big');
    }

    @IsTest
    static void testReconcile_whenTheTemplateAgreesWithTheExplicitKey_keepsTheExplicitKey() {
        testReconcile(BIG, new Account(NumberOfEmployees = 5000), 'Account::flavour=big');
    }

    @IsTest
    static void testReconcile_whenTheTemplateCarriesNoDiscriminator_keepsTheExplicitKey() {
        testReconcile(BIG, new Account(), 'Account::flavour=big');
    }

    @IsTest
    static void testReconcile_whenTheTemplateMatchesADifferentRefinedVariant_throws() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            XFTY_ProviderLookups.reconcile(providerLookup, BIG, new Account(NumberOfEmployees = 2));
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a template matching a different variant must be rejected');
        Assert.isTrue(thrown.getMessage().contains('contradicts'), thrown.getMessage());
    }

    // End to end through XFTY_DummySObjectProvider ---------------------------

    @IsTest
    static void testSupply_whenWithVariantContradictsTheOverrideTemplate_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .withVariant(BIG)
                .setOverrideTemplate(new Account(NumberOfEmployees = 2))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_ProviderLookups.LookupException thrown;
        Test.startTest();
        try {
            provider.supply();
        } catch (XFTY_ProviderLookups.LookupException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'withVariant contradicting the template must throw');
        Assert.isTrue(thrown.getMessage().contains('contradicts'), thrown.getMessage());
    }

    @IsTest
    static void testSupply_whenWithVariantAgreesWithTheOverrideTemplate_stillAppliesTheTemplate() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .withVariant(BIG)
                .setOverrideTemplate(new Account(NumberOfEmployees = 5000))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Account result = (Account) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual(5000, result.NumberOfEmployees);
    }

    // Helpers -----------------------------------------------------------

    static void testReconcile(XFTY_LookupKeyIntf explicitKey, SObject template, String expectedHash) {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();

        // Act
        Test.startTest();
        XFTY_LookupKeyIntf resolved = XFTY_ProviderLookups.reconcile(providerLookup, explicitKey, template);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedHash, resolved?.getHashKey());
    }
}
