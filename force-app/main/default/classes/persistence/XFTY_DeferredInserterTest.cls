/**
 * Proves the `DEFERRED` insert mode and its registry, `XFTY_DeferredInserter`:
 * `DEFERRED` generates like `NEVER` and registers every record; `flush()` saves
 * the whole accumulated set in one depth-batched pass, back-filling Ids on the
 * instances already handed out. Real DML, so `System.runAs`.
 */
@IsTest
private class XFTY_DeferredInserterTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testSupplyBundle_inDeferredMode_leavesRecordsWithoutAnIdUntilFlush() {
        // Arrange
        XFTY_DummySObjectBundle bundle;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = deferredContactWithAccount('Deferred');
            Test.stopTest();
        }

        // Assert
        Assert.isNull(contactOf(bundle).Id, 'nothing is inserted before flush()');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void testFlush_savesTheDeferredGraphAndWiresTheLookup() {
        // Arrange
        XFTY_DummySObjectBundle bundle;
        Integer dml;

        // Act
        System.runAs(TEST_ADMIN) {
            bundle = deferredContactWithAccount('Deferred');
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInserter.flush();
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, dml, 'Account then Contact');
        Assert.areEqual(accountOf(bundle).Id, contactOf(bundle).get(Contact.AccountId));
        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void testFlush_savesEveryGraphFromEverySupplyCallInOnePass() {
        // Arrange
        XFTY_DummySObjectBundle withAccount;
        XFTY_DummySObjectBundle lone;
        Integer dml;

        // Act
        System.runAs(TEST_ADMIN) {
            withAccount = deferredContactWithAccount('Multi A');
            lone = deferredAccount('Multi B');
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInserter.flush();
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, dml, 'both Accounts share layer 0, the Contact is layer 1');
        Assert.isNotNull(contactOf(withAccount).Id);
        Assert.isNotNull(accountOf(lone).Id);
    }

    @IsTest
    static void testSupplyBundle_inDeferredModeWithoutFlush_savesNothing() {
        // Arrange
        // nothing to arrange

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            deferredContactWithAccount('No Flush');
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, [SELECT COUNT() FROM Contact], 'DEFERRED without flush() is NEVER');
    }

    @IsTest
    static void testFlush_withAnEmptyRegistry_doesNothing() {
        // Arrange
        Integer dml;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInserter.flush();
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, dml);
        Assert.areEqual(0, XFTY_DeferredInserter.pendingCount());
    }

    @IsTest
    static void testFlush_clearsTheRegistrySoASecondFlushIsANoOp() {
        // Arrange
        Integer secondFlushDml;

        // Act
        System.runAs(TEST_ADMIN) {
            deferredContactWithAccount('Once');
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInserter.flush();
            secondFlushDml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, XFTY_DeferredInserter.pendingCount(), 'the registry is cleared');
        Assert.areEqual(0, secondFlushDml, 'a second flush() is a no-op');
        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void testFlush_whenADeferredRecordPointsAtAnAlreadyInsertedRecord_doesNotReinsertIt() {
        // Arrange
        XFTY_DummySObjectBundle bundle;
        Id existingId;
        System.runAs(TEST_ADMIN) {
            Account existing = new Account(Name = 'Pre-existing');
            insert existing;
            existingId = existing.Id;
            bundle = deferredContactUnder(existingId);
        }

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(existingId, contactOf(bundle).get(Contact.AccountId));
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'the existing Account is not re-inserted');
    }

    @IsTest
    static void testFlush_betweenSupplyCalls_letsALaterGraphUseTheEarlierIds() {
        // Arrange
        XFTY_DummySObjectBundle children;
        Id parentId;
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle parents = deferredAccount('Flush First');
            XFTY_DeferredInserter.flush();
            parentId = accountOf(parents).Id;
            children = deferredContactUnder(parentId);
        }

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(parentId, contactOf(children).get(Contact.AccountId));
        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void testFlush_leavesANowInsertMadeBetweenDeferredCallsAlone() {
        // Arrange
        XFTY_DummySObjectBundle deferred;
        System.runAs(TEST_ADMIN) {
            deferred = deferredAccount('Deferred Half');
            new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Account(Name = 'Now Half'))
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
        }

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(accountOf(deferred).Id);
        Assert.areEqual(2, [SELECT COUNT() FROM Account], 'the NOW Account was not touched by flush()');
    }

    @IsTest
    static void testSupply_inDeferredMode_resolvesASharedAncestorUpFront() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act
        Contact result;
        Integer accountsBeforeFlush;
        Integer contactsBeforeFlush;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supply();
            accountsBeforeFlush = [SELECT COUNT() FROM Account];
            contactsBeforeFlush = [SELECT COUNT() FROM Contact];
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, accountsBeforeFlush, 'the shared ancestor is inserted immediately');
        Assert.areEqual(0, contactsBeforeFlush, 'the Contact waits for flush()');
        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(XFTY_SharedAncestor.getId('hq'), result.AccountId);
    }

    // Helpers -----------------------------------------------

    private static XFTY_DummySObjectBundle deferredContactWithAccount(String lastName) {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplate(new Contact(LastName = lastName))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .supplyBundle();
    }

    private static XFTY_DummySObjectBundle deferredContactUnder(Id accountId) {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplate(new Contact(LastName = 'Points Up', AccountId = accountId))
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .supplyBundle();
    }

    private static XFTY_DummySObjectBundle deferredAccount(String name) {
        return new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setOverrideTemplate(new Account(Name = name))
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .supplyBundle();
    }

    private static SObject contactOf(XFTY_DummySObjectBundle bundle) {
        return bundle.getList(Contact.Id)[0];
    }

    private static SObject accountOf(XFTY_DummySObjectBundle bundle) {
        List<SObject> parents = bundle.getList(Contact.AccountId);
        return (parents != null) ? parents[0] : bundle.getList(Account.Id)[0];
    }
}
