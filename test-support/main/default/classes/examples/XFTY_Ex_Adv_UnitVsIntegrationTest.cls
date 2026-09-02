/**
 * Runnable proof for docs/use/advanced/unit-vs-integration.md - the same
 * Provider definitions and the same call, differing only by insert mode.
 *
 * `providerFor(mode)` is the shared shape; each test method passes one mode.
 */
@IsTest
private class XFTY_Ex_Adv_UnitVsIntegrationTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testSupplyBundle_inTheUnitForm_buildsTheGraphWithoutTouchingTheDatabase() {
        // Arrange
        // nothing to arrange - the same providerFor(...) shape, MOCK mode

        // Act
        XFTY_DummySObjectBundle bundle = providerFor(XFTY_InsertModeEnum.MOCK).supplyBundle();

        // Assert
        assertGraphShape(bundle);
        Assert.areEqual(0, [SELECT COUNT() FROM Contact], 'MOCK persists nothing');
        Assert.areEqual(0, [SELECT COUNT() FROM Account], 'MOCK persists nothing');
    }

    @IsTest
    static void testSupplyBundle_inTheIntegrationForm_buildsTheIdenticalGraphInTheDatabase() {
        // Arrange
        XFTY_DummySObjectBundle bundle;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = providerFor(XFTY_InsertModeEnum.NOW).supplyBundle();
            Test.stopTest();
        }

        // Assert - same shape as the MOCK run, now actually inserted
        assertGraphShape(bundle);
        Assert.areEqual(2, [SELECT COUNT() FROM Contact], 'the same graph, persisted');
    }

    // Fixture -------------------------------------------------------------

    private static XFTY_DummySObjectProvider providerFor(XFTY_InsertModeEnum mode) {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(2)
                .setInsertMode(mode);
    }

    private static void assertGraphShape(XFTY_DummySObjectBundle bundle) {
        List<Contact> contacts = (List<Contact>) bundle.getList(Contact.Id);
        List<Account> accounts = (List<Account>) bundle.getList(Contact.AccountId);
        Assert.areEqual(2, contacts.size());
        Assert.areEqual(2, accounts.size());
        Assert.areEqual(accounts[0].Id, contacts[0].AccountId, 'each Contact wired to its Account');
    }
}
