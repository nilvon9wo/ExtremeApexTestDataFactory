/**
 * Runnable proof for docs/use/advanced/deep-setup-chains.md - building shared
 * setup across helper methods with `DEFERRED`, each helper returning its bundle
 * so the test reads generated values without a `SELECT`.
 *
 * Every `@IsTest` method here is one example from that page.
 */
@IsTest
private class XFTY_Ex_Adv_DeepSetupChainsTest {

    private static final XFTY_DefaultSObjectProviderLookup PROVIDER_LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // The primary @TestSetup replacement: a static fixture, rebuilt per test method.
    private static final List<Account> SHARED_ACCOUNTS = new XFTY_DummySObjectProvider(Account.SObjectType, PROVIDER_LOOKUP)
            .setInsertMode(XFTY_InsertModeEnum.MOCK)
            .setQuantityPerTemplate(3)
            .supplyList();

    @IsTest
    static void aStaticFixtureIsBuiltFreshAndReusableAcrossASingleTest() {
        // Arrange
        // nothing to arrange - SHARED_ACCOUNTS is the static fixture, built for this method

        // Act - a test uses the fixture directly, e.g. as a parent for more records
        List<Contact> contactsOnTheFixture = new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                .setOverrideTemplate(new Contact(AccountId = SHARED_ACCOUNTS[0].Id))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setQuantityPerTemplate(2)
                .supplyList();

        // Assert
        Assert.areEqual(3, SHARED_ACCOUNTS.size(), 'MOCK built the fixture with no DML');
        Assert.isNotNull(SHARED_ACCOUNTS[0].Id, 'and realistic Ids');
        Assert.areEqual(SHARED_ACCOUNTS[0].Id, contactsOnTheFixture[0].AccountId, 'reused straight from the fixture');
    }

    @IsTest
    static void helpersBuildTheGraphAcrossStepsAndFlushInsertsItOnce() {
        // Arrange - two helper steps, no DML in either
        XFTY_DummySObjectBundle seededAccounts;
        XFTY_DummySObjectBundle seededContacts;
        System.runAs(TEST_ADMIN) {
            seededAccounts = seedAccounts();
            seededContacts = seedContacts();

            // Act
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert - values read straight off the bundles, no SOQL
        List<Account> accountRecords = seededAccounts.getList(Account.Id);
        List<Contact> contactRecords = seededContacts.getList(Contact.Id);
        Assert.areEqual(3, accountRecords.size());
        Assert.areEqual(9, contactRecords.size());
        Assert.isNotNull(accountRecords[0].Id, 'flush() back-filled the Ids onto the bundle instances');
        Assert.isNotNull(contactRecords[0].Id);
        Assert.areEqual(3 + 9, [SELECT COUNT() FROM Account], 'one insert phase: 3 seeded + one generated per Contact');
    }

    @IsTest
    static void aLaterStepReadsAnEarlierRecordsRealIdOffTheBundle() {
        // Arrange - seed and flush the Accounts so they have real Ids
        XFTY_DummySObjectBundle seededAccounts;
        Id firstSeededAccountId;
        XFTY_DummySObjectBundle seededContacts;
        System.runAs(TEST_ADMIN) {
            seededAccounts = seedAccounts();
            XFTY_DeferredInserter.flush();
            firstSeededAccountId = seededAccounts.getList(Account.Id)[0].Id;

            // Act - a later step that needs that Id as a value
            Test.startTest();
            seededContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                    .setOverrideTemplate(new Contact(AccountId = firstSeededAccountId))
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .setQuantityPerTemplate(4)
                    .supplyBundle();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(firstSeededAccountId);
        for (Contact contactRecord : seededContacts.getList(Contact.Id)) {
            Assert.areEqual(firstSeededAccountId, contactRecord.AccountId, 'every later Contact points at the flushed Account');
        }
        Assert.areEqual(3, [SELECT COUNT() FROM Account], 'no extra Accounts - the later step reused the Id');
    }

    // Helpers from the page ---------------------------------------------

    private static XFTY_DummySObjectBundle seedAccounts() {
        return new XFTY_DummySObjectProvider(Account.SObjectType, PROVIDER_LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .setQuantityPerTemplate(3)
                .supplyBundle();
    }

    private static XFTY_DummySObjectBundle seedContacts() {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .setQuantityPerTemplate(9)
                .supplyBundle();
    }
}
