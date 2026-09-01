/**
 * The `DEFERRED` insert mode and its registry, `XFTY_DeferredInserter`.
 *
 * `DEFERRED` generates like `NEVER` and registers every record; `flush()` saves
 * the whole accumulated set - from every `supplyBundle()` call - in one
 * depth-batched pass, back-filling Ids on the instances already handed out.
 *
 * Real DML, so `XFTY_Integration`.
 */
@IsTest
private class XFTY_DeferredInserterTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void recordsHaveNoIdUntilFlush() {
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle bundle = deferredContactWithAccount('Deferred');

            Assert.isNull(contactOf(bundle).Id, 'nothing inserted before flush()');
            Assert.areEqual(0, [SELECT COUNT() FROM Contact]);

            Integer dml = flushCountingDml();

            Assert.areEqual(2, dml, 'Account then Contact');
            Assert.areEqual(accountOf(bundle).Id, contactOf(bundle).get(Contact.AccountId));
            Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        }
    }

    @IsTest
    static void oneFlushSavesEveryGraphFromEverySupplyCall() {
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle withAccount = deferredContactWithAccount('Multi A');
            XFTY_DummySObjectBundle lone = deferredAccount('Multi B');

            Integer dml = flushCountingDml();

            Assert.areEqual(2, dml, 'both Accounts share layer 0, the Contact is layer 1');
            Assert.isNotNull(contactOf(withAccount).Id);
            Assert.isNotNull(accountOf(lone).Id);
        }
    }

    @IsTest
    static void withoutFlushNothingIsSaved() {
        System.runAs(TEST_ADMIN) {
            deferredContactWithAccount('No Flush');
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Contact], 'DEFERRED without flush() is NEVER');
    }

    @IsTest
    static void flushWithAnEmptyRegistryDoesNothing() {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            dml = flushCountingDml();
        }
        Assert.areEqual(0, dml);
        Assert.areEqual(0, XFTY_DeferredInserter.pendingCount());
    }

    @IsTest
    static void flushClearsTheRegistry() {
        System.runAs(TEST_ADMIN) {
            deferredContactWithAccount('Once');
            Assert.isTrue(XFTY_DeferredInserter.pendingCount() > 0);

            XFTY_DeferredInserter.flush();

            Assert.areEqual(0, XFTY_DeferredInserter.pendingCount());
            Assert.areEqual(0, flushCountingDml(), 'a second flush() is a no-op');
            Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        }
    }

    @IsTest
    static void aDeferredRecordCanPointAtAnAlreadyInsertedRecord() {
        System.runAs(TEST_ADMIN) {
            Account existing = new Account(Name = 'Pre-existing');
            insert existing;

            XFTY_DummySObjectBundle bundle = deferredContactUnder(existing.Id);
            XFTY_DeferredInserter.flush();

            Assert.areEqual(existing.Id, contactOf(bundle).get(Contact.AccountId));
            Assert.areEqual(1, [SELECT COUNT() FROM Account], 'the existing Account is not re-inserted');
        }
    }

    @IsTest
    static void flushingBetweenCallsLetsALaterGraphUseTheEarlierIds() {
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle parents = deferredAccount('Flush First');
            XFTY_DeferredInserter.flush();
            Id parentId = accountOf(parents).Id;

            XFTY_DummySObjectBundle children = deferredContactUnder(parentId);
            XFTY_DeferredInserter.flush();

            Assert.areEqual(parentId, contactOf(children).get(Contact.AccountId));
            Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        }
    }

    @IsTest
    static void aNowInsertBetweenDeferredCallsIsLeftAlone() {
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle deferred = deferredAccount('Deferred Half');
            new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setOverrideTemplate(new Account(Name = 'Now Half'))
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();

            XFTY_DeferredInserter.flush();

            Assert.isNotNull(accountOf(deferred).Id);
            Assert.areEqual(2, [SELECT COUNT() FROM Account], 'the NOW Account was not touched by flush()');
        }
    }

    @IsTest
    static void deferredResolvesASharedAncestorUpFront() {
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Contact result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supply();
            // the shared ancestor is inserted immediately; the Contact waits for flush()
            Assert.areEqual(1, [SELECT COUNT() FROM Account]);
            Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
            XFTY_DeferredInserter.flush();
            Test.stopTest();

            Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
            Assert.areEqual(XFTY_SharedAncestor.getId('hq'), result.AccountId);
        }
    }

    // helpers ------------------------------------------------------------------

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
        List<SObject> lone = bundle.getList(Account.Id);
        return (parents != null)
                ? parents[0]
                : lone[0];
    }

    private static Integer flushCountingDml() {
        Integer before = Limits.getDmlStatements();
        XFTY_DeferredInserter.flush();
        return Limits.getDmlStatements() - before;
    }
}
