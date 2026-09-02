/**
 * Runnable proof for docs/use/deferred-insert.md - the DEFERRED insert mode
 * (generate over many calls, flush once) and .depthBatched() (one insert per
 * dependency depth in a single NOW call). Every `@IsTest` method is one example
 * from that page.
 */
@IsTest
private class XFTY_Ex_DeferredInsertTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testFlush_afterDeferredGenerationOverManyCalls_insertsEverythingOnce() {
        // Arrange - two DEFERRED calls, nothing inserted yet
        XFTY_DummySObjectBundle accounts;
        XFTY_DummySObjectBundle contacts;
        System.runAs(TEST_ADMIN) {
            accounts = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .setQuantityPerTemplate(3)
                    .supplyBundle();
            contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyBundle();

            // Act
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert - the same instances now carry real Ids
        Assert.isNotNull(accounts.getList(Account.Id)[0].Id, 'flush() back-filled the Account Ids');
        Assert.isNotNull(contacts.getList(Contact.Id)[0].Id, 'and the Contact Ids');
    }

    @IsTest
    static void testSupply_inDeferredModeWithoutFlush_hasNeverSemantics() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .setQuantityPerTemplate(2);

        // Act - no flush() call
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();

        // Assert
        Assert.areEqual(null, bundle.getList(Account.Id)[0].Id, 'no Id');
        Assert.areEqual(0, [SELECT COUNT() FROM Account], 'no surprise DML');
    }

    @IsTest
    static void testFlush_clearsTheRegistrySoLaterGenerationStartsFresh() {
        // Arrange
        System.runAs(TEST_ADMIN) {
            new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .setQuantityPerTemplate(2)
                    .supplyBundle();
            XFTY_DeferredInserter.flush();

            // Act - a second flush with nothing registered
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, [SELECT COUNT() FROM Account], 'the first flush inserted 2; the second added nothing');
    }

    @IsTest
    static void testFlush_betweenSteps_providesTheIdsALaterStepNeeds() {
        // Arrange - flush the parents, then read a real Id off the bundle for the next step
        Id parentId;
        XFTY_DummySObjectBundle contacts;
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle parents = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyBundle();
            XFTY_DeferredInserter.flush();
            parentId = parents.getList(Account.Id)[0].Id;

            // Act
            Test.startTest();
            contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Contact(AccountId = parentId))
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .setQuantityPerTemplate(2)
                    .supplyBundle();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(parentId);
        for (Contact seededContact : (List<Contact>) contacts.getList(Contact.Id)) {
            Assert.areEqual(parentId, seededContact.AccountId, 'every Contact points at the flushed Account');
        }
    }

    @IsTest
    static void testSupplyBundle_whenDepthBatched_collapsesToOneInsertPerDependencyDepth() {
        // Arrange - a Contact + its required Account in one NOW call
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched()
                .setQuantityPerTemplate(3);

        // Act
        XFTY_DummySObjectBundle bundle;
        Integer dmlStatementsUsed;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            bundle = provider.supplyBundle();
            dmlStatementsUsed = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert - two depths (Accounts, then Contacts) => 2 inserts, not one per Provider per row
        Assert.areEqual(3, bundle.getList(Contact.Id).size());
        Assert.areEqual(2, dmlStatementsUsed, 'one insert per depth');
        Assert.isNotNull(bundle.getList(Contact.Id)[0].Id);
    }
}
