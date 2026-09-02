/**
 * Coverage for reconciling the two ways a caller can name a Provider variant -
 * an explicit lookup key and an override template - via
 * `XFTY_ProviderLookups.reconcile` and end to end through
 * `XFTY_DummySObjectProvider`.
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
    static void reconcileReturnsNullWithNeitherKeyNorTemplate() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();

        // Act
        XFTY_LookupKeyIntf resolved = XFTY_ProviderLookups.reconcile(providerLookup, null, null);

        // Assert
        Assert.isNull(resolved, 'the caller supplies its own default');
    }

    @IsTest
    static void reconcileDerivesFromTheTemplateWhenNoKeyIsGiven() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();

        // Act
        XFTY_LookupKeyIntf resolved =
                XFTY_ProviderLookups.reconcile(providerLookup, null, new Account(NumberOfEmployees = 5000));

        // Assert
        Assert.areEqual('Account::flavour=big', resolved.getHashKey());
    }

    @IsTest
    static void reconcileKeepsTheExplicitKeyWhenTheTemplateAgrees() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();

        // Act
        XFTY_LookupKeyIntf resolved =
                XFTY_ProviderLookups.reconcile(providerLookup, BIG, new Account(NumberOfEmployees = 5000));

        // Assert
        Assert.areEqual(BIG.getHashKey(), resolved.getHashKey());
    }

    @IsTest
    static void reconcileKeepsTheExplicitKeyWhenTheTemplateCarriesNoDiscriminator() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf providerLookup = lookup();

        // Act
        XFTY_LookupKeyIntf resolved =
                XFTY_ProviderLookups.reconcile(providerLookup, BIG, new Account());

        // Assert
        Assert.areEqual(BIG.getHashKey(), resolved.getHashKey(), 'a neutral template does not contradict');
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
    static void withVariantAndAnAgreeingOverrideTemplateIsFine() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .withVariant(BIG)
                .setOverrideTemplate(new Account(NumberOfEmployees = 5000))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Account result = (Account) provider.supply();

        // Assert
        Assert.areEqual(5000, result.NumberOfEmployees, 'the override template still applied');
    }
}
