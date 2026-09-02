/**
 * Coverage for reconciling the two ways a caller can name a Provider variant -
 * an explicit lookup key and an override template - via
 * `XFTY_ProviderLookups.reconcile` and end to end through
 * `XFTY_DummySObjectProvider`.
 *
 * Each `@IsTest` checks one behaviour; the non-throwing `reconcile` cases
 * delegate their Arrange / Act / Assert to `assertReconciledHash`.
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
    static void reconcileReturnsNullWhenGivenNeitherKeyNorTemplate() {
        assertReconciledHash(null, null, null);
    }

    @IsTest
    static void reconcileDerivesFromTheTemplateWhenNoKeyIsGiven() {
        assertReconciledHash(null, new Account(NumberOfEmployees = 5000), 'Account::flavour=big');
    }

    @IsTest
    static void reconcileKeepsTheExplicitKeyWhenTheTemplateAgrees() {
        assertReconciledHash(BIG, new Account(NumberOfEmployees = 5000), 'Account::flavour=big');
    }

    @IsTest
    static void reconcileKeepsTheExplicitKeyWhenTheTemplateCarriesNoDiscriminator() {
        assertReconciledHash(BIG, new Account(), 'Account::flavour=big');
    }

    @IsTest
    static void reconcileThrowsWhenTheTemplateMatchesADifferentRefinedVariant() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();

        // Act
        try {
            XFTY_ProviderLookups.reconcile(providerLookup, BIG, new Account(NumberOfEmployees = 2));
            Assert.fail('Expected a contradiction exception');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            // Assert
            Assert.isTrue(ex.getMessage().contains('contradicts'), ex.getMessage());
        }
    }

    // End to end through XFTY_DummySObjectProvider ---------------------------

    @IsTest
    static void withVariantAndAContradictingOverrideTemplateThrows() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .withVariant(BIG)
                .setOverrideTemplate(new Account(NumberOfEmployees = 2))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        try {
            provider.supply();
            Assert.fail('Expected a contradiction exception');
        } catch (XFTY_ProviderLookups.LookupException ex) {
            // Assert
            Assert.isTrue(ex.getMessage().contains('contradicts'), ex.getMessage());
        }
    }

    @IsTest
    static void withVariantAndAnAgreeingOverrideTemplateStillAppliesTheTemplate() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .withVariant(BIG)
                .setOverrideTemplate(new Account(NumberOfEmployees = 5000))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Account result = (Account) provider.supply();

        // Assert
        Assert.areEqual(5000, result.NumberOfEmployees);
    }

    // Helpers -----------------------------------------------------------

    static void assertReconciledHash(XFTY_LookupKeyIntf explicitKey, SObject template, String expectedHash) {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();
        // Act
        XFTY_LookupKeyIntf resolved = XFTY_ProviderLookups.reconcile(providerLookup, explicitKey, template);
        // Assert
        Assert.areEqual(expectedHash, resolved?.getHashKey());
    }
}
