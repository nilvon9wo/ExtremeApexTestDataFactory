/**
 * Coverage for the `DEFERRED` insert mode and its registry, `XFTY_DeferredInsert`.
 *
 * `DEFERRED` generates like `NEVER` (no Ids, no DML) and registers every record;
 * `XFTY_DeferredInsert.flush()` inserts the whole accumulated set - across every
 * `supplyBundle()` call - in one `insert` per dependency depth, and the Ids
 * appear on the instances already handed out.
 *
 * Real DML, so `XFTY_Integration`.
 */
@IsTest
private class XFTY_DeferredInsertTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void deferredHoldsRecordsWithoutIdsUntilFlush() {
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Deferred'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyBundle();

            SObject generatedContact = bundle.getList(Contact.Id)[0];
            SObject parentAccount = bundle.getList(Contact.AccountId)[0];
            Assert.isNull(generatedContact.Id, 'nothing is inserted before flush()');
            Assert.isNull(parentAccount.Id);
            Assert.areEqual(0, [SELECT COUNT() FROM Contact]);

            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsert.flush();
            Integer flushDml = Limits.getDmlStatements() - before;
            Test.stopTest();

            Assert.areEqual(2, flushDml, 'Account at depth 0, Contact at depth 1');
            Assert.isNotNull(generatedContact.Id, 'the Id is now on the instance handed out earlier');
            Assert.isNotNull(parentAccount.Id);
            Assert.areEqual(parentAccount.Id, generatedContact.get(Contact.AccountId), 'the lookup is wired');
            Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
            Assert.areEqual(
                    generatedContact.Id,
                    [SELECT Id FROM Contact WHERE AccountId = :parentAccount.Id].Id
            );
        }
    }

    @IsTest
    static void flushInsertsEveryGraphFromEverySupplyCallInOnePass() {
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle contactBundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Multi A'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyBundle();
            XFTY_DummySObjectBundle accountBundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Account(Name = 'Multi B'))
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyBundle();

            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsert.flush();
            Integer flushDml = Limits.getDmlStatements() - before;
            Test.stopTest();

            Assert.areEqual(2, flushDml, 'every depth-0 record - both Accounts - batches into one insert');
            Assert.isNotNull(contactBundle.getList(Contact.Id)[0].Id);
            Assert.isNotNull(accountBundle.getList(Account.Id)[0].Id);
            Assert.areEqual(2, [SELECT COUNT() FROM Account]);
            Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        }
    }

    @IsTest
    static void withoutFlushNothingIsInserted() {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyList();
            dml = Limits.getDmlStatements() - before;
        }
        Assert.areEqual(0, dml, 'DEFERRED without flush() behaves like NEVER');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void flushIsANoOpWhenNothingIsRegistered() {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsert.flush();
            dml = Limits.getDmlStatements() - before;
        }
        Assert.areEqual(0, dml);
        Assert.areEqual(0, XFTY_DeferredInsert.pendingCount());
    }

    @IsTest
    static void flushClearsTheRegistrySoASecondFlushDoesNothing() {
        System.runAs(TEST_ADMIN) {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Once'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyList();
            Assert.isTrue(XFTY_DeferredInsert.pendingCount() > 0);

            Test.startTest();
            XFTY_DeferredInsert.flush();
            Assert.areEqual(0, XFTY_DeferredInsert.pendingCount(), 'flush() clears the pending set');
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsert.flush();
            Assert.areEqual(0, Limits.getDmlStatements() - before, 'a second flush() is a no-op');
            Test.stopTest();

            Assert.areEqual(1, [SELECT COUNT() FROM Contact], 'inserted exactly once');
        }
    }

    @IsTest
    static void aDeferredRecordCanPointAtAnAlreadyInsertedRecord() {
        System.runAs(TEST_ADMIN) {
            Account existing = new Account(Name = 'Pre-existing');
            insert existing;

            XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Points Up', AccountId = existing.Id))
                    .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supplyBundle();

            Test.startTest();
            XFTY_DeferredInsert.flush();
            Test.stopTest();

            SObject generatedContact = bundle.getList(Contact.Id)[0];
            Assert.isNotNull(generatedContact.Id);
            Assert.areEqual(existing.Id, generatedContact.get(Contact.AccountId), 'the existing Id is untouched');
            Assert.areEqual(1, [SELECT COUNT() FROM Account], 'the pre-existing Account is not re-inserted');
        }
    }

    @IsTest
    static void deferredWithASharedAncestorThrows() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));
        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                        .supply();
                Assert.fail('Expected an exception');
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                Assert.isTrue(ex.getMessage().contains('not supported together'), ex.getMessage());
            }
        }
    }
}
