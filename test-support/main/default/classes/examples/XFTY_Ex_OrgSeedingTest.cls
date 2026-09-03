/**
 * Runnable proof for docs/use/org-seeding.md. `XFTY_Seeder.seed(bundle)` and
 * `XFTY_SeedResult` exercised with ordinary `@IsTest` + `System.runAs` - the
 * `@IntegrationTest` wrapper (data surviving the transaction) is proven on a
 * scratch org, not in CI.
 */
@IsTest
private class XFTY_Ex_OrgSeedingTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void testSeed_persistsTheWholeGeneratedGraphAndReportsTheOutcome() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .withChildren(Contact.AccountId, 5)
                .supplyBundle();

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        System.debug(result.savedCount() + ' saved, ' + result.failedCount() + ' failed: ' + result.errors());
        Assert.areEqual(6, result.savedCount(), '1 Account + 5 Contacts');
        Assert.isTrue(result.isFullySeeded());
        Assert.isNotNull(bundle.primaryRecords()[0].Id);
    }

    @IsTest
    static void testCleanup_undoesExactlyWhatTheSeedCreated() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .withChildren(Contact.AccountId, 2)
                .supplyBundle();

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_SeedResult result = XFTY_Seeder.seed(bundle);
            delete result.savedRecordsOfType(Contact.SObjectType);
            delete result.savedRecordsOfType(Account.SObjectType);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, [SELECT COUNT() FROM Contact WHERE Id = :bundle.getChildList(Contact.AccountId)[0].Id]);
    }
}
