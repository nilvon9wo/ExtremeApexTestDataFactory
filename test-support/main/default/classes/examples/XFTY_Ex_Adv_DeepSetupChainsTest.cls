/**
 * Runnable proof for docs/use/advanced/deep-setup-chains.md - the `static`
 * fixture pattern (the primary `@TestSetup` replacement) and the per-test-method
 * helper form for setup that is genuinely test-ordered.
 *
 * The page also describes a `static {}` block that runs
 * `XFTY_DeferredInserter.flush()` after the fixtures are built. That is org-only:
 * Nimbus does not roll back DML performed in a static initialiser between test
 * methods, so it cannot be exercised here (same as the record-type / Person
 * Account self-tests).
 *
 * Every other `@IsTest` method here is one example from that page.
 */
@IsTest
private class XFTY_Ex_Adv_DeepSetupChainsTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // The plain-snapshot form: a MOCK static fixture, rebuilt per test method.
    private static final List<Account> MOCKED_ACCOUNTS = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
            .setInsertMode(XFTY_InsertModeEnum.MOCK)
            .setQuantityPerTemplate(3)
            .supplyList();

    @IsTest
    static void testStaticFixture_isBuiltFreshAndReusableWithinOneTest() {
        // Arrange
        // nothing to arrange - MOCKED_ACCOUNTS is the static fixture, built for this method

        // Act - use the fixture, e.g. as a parent for more records
        List<Contact> contactsOnTheFixture = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplate(new Contact(AccountId = MOCKED_ACCOUNTS[0].Id))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setQuantityPerTemplate(2)
                .supplyList();

        // Assert
        Assert.areEqual(3, MOCKED_ACCOUNTS.size(), 'MOCK built the fixture with no DML');
        Assert.isNotNull(MOCKED_ACCOUNTS[0].Id, 'and realistic Ids');
        Assert.areEqual(0, [SELECT COUNT() FROM Account], 'MOCK really means no database rows');
        Assert.areEqual(MOCKED_ACCOUNTS[0].Id, contactsOnTheFixture[0].AccountId, 'reused straight from the fixture');
    }

    @IsTest
    static void testFlush_afterHelpersBuildTheGraphAcrossSteps_insertsItOnce() {
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
        Assert.isNotNull(accountRecords[0].Id, 'flush() back-filled the Ids onto the bundle instances');
        Assert.isNotNull(contactRecords[0].Id);
        Assert.areEqual(9, seededContacts.getList(Contact.Id).size());
        Assert.areEqual(3 + 9, [SELECT COUNT() FROM Account], 'one insert phase: 3 seeded + one generated per Contact');
    }

    @IsTest
    static void testFlush_aLaterStepReadsAnEarlierRecordsRealIdOffTheBundle() {
        // Arrange - seed and flush the Accounts so they have real Ids
        XFTY_DummySObjectBundle seededAccounts;
        Id firstSeededAccountId;
        XFTY_DummySObjectBundle laterContacts;
        System.runAs(TEST_ADMIN) {
            seededAccounts = seedAccounts();
            XFTY_DeferredInserter.flush();
            firstSeededAccountId = seededAccounts.getList(Account.Id)[0].Id;

            // Act - a later step that needs that Id as a value
            Test.startTest();
            laterContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Contact(AccountId = firstSeededAccountId))
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .setQuantityPerTemplate(4)
                    .supplyBundle();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(firstSeededAccountId);
        Assert.areEqual(firstSeededAccountId, laterContacts.getList(Contact.Id)[0].get(Contact.AccountId));
        for (Contact contactRecord : (List<Contact>) laterContacts.getList(Contact.Id)) {
            Assert.areEqual(firstSeededAccountId, contactRecord.AccountId, 'every later Contact points at the flushed Account');
        }
        Assert.areEqual(3, [SELECT COUNT() FROM Account], 'no extra Accounts - the later step reused the Id');
    }

    // Helpers from the page ---------------------------------------------

    private static XFTY_DummySObjectBundle seedAccounts() {
        return new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .setQuantityPerTemplate(3)
                .supplyBundle();
    }

    private static XFTY_DummySObjectBundle seedContacts() {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .setQuantityPerTemplate(9)
                .supplyBundle();
    }
}
