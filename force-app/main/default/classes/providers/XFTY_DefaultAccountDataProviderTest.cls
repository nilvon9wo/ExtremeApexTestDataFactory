/**
 * Proves `XFTY_DefaultAccountDataProvider` - its identity, its Master Template
 * defaults, and an inserted Account carrying them. The NOW test does real DML,
 * so `System.runAs`.
 */
@IsTest
private class XFTY_DefaultAccountDataProviderTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testGetPrimaryTargetField_isAccountId() {
        // Arrange
        XFTY_DefaultAccountDataProvider provider = new XFTY_DefaultAccountDataProvider();

        // Act
        Test.startTest();
        SObjectField primaryField = provider.getPrimaryTargetField();
        Test.stopTest();

        // Assert
        Assert.areEqual(Account.Id, primaryField);
        Assert.isNotNull(provider.getMasterTemplate());
    }

    @IsTest
    static void testCreateBundle_producesAnAccountWithTheDocumentedDefaults() {
        // Arrange
        XFTY_DefaultAccountDataProvider provider = new XFTY_DefaultAccountDataProvider();
        XFTY_GenerationContext context =
                new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.createBundle(context, new List<SObject>{ new Account() });
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) bundle.getList(Account.Id)[0];
        Assert.isNotNull(generatedAccount.Id);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, generatedAccount.Industry);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_SHIPPING_COUNTRY, generatedAccount.ShippingCountry);
    }

    @IsTest
    static void testSupply_inNowMode_generatesAnInsertableAccountWithDefaults() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        Account generatedAccount;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            generatedAccount = (Account) provider.supply();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(generatedAccount.Id);
        Assert.isTrue(generatedAccount.Name.startsWith(XFTY_DefaultAccountDataProvider.DEFAULT_NAME_PREFIX));
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, generatedAccount.Industry);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
    }
}
